-- ============================================================
-- TripJio — Complete Edge Case Fix
-- Run this in Supabase SQL Editor
-- ============================================================

-- ─── 1. Add is_busy flag to drivers (for trip-in-progress lock) ──────────────

ALTER TABLE public.drivers
  ADD COLUMN IF NOT EXISTS is_busy boolean NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_drivers_busy ON public.drivers (is_busy);


-- ─── 2. Replace fetch_nearby_drivers — exclude busy + stale drivers ──────────

CREATE OR REPLACE FUNCTION public.fetch_nearby_drivers(
  user_lat float,
  user_lng float,
  radius_km float,
  vehicle_type_filter text DEFAULT NULL,
  max_results int DEFAULT 50,
  freshness_minutes int DEFAULT 3
)
RETURNS TABLE (
  user_id text,
  name text,
  vehicle_type text,
  vehicle_number text,
  rating numeric,
  total_trips int,
  latitude double precision,
  longitude double precision
)
LANGUAGE sql STABLE
AS $$
  SELECT
    d.user_id,
    u.name,
    COALESCE(v.vehicle_type, 'Mini Truck'),
    COALESCE(v.vehicle_number, 'N/A'),
    d.rating,
    d.total_trips,
    d.latitude,
    d.longitude
  FROM public.drivers d
  INNER JOIN public.users u ON u.id = d.user_id
  LEFT JOIN public.vehicles v ON v.user_id = d.user_id
  WHERE d.is_online = true
    AND d.is_busy = false                      -- ⭐ skip busy drivers
    AND d.latitude  IS NOT NULL
    AND d.longitude IS NOT NULL
    AND d.updated_at > (now() - (freshness_minutes || ' minutes')::interval)
    AND d.latitude  BETWEEN user_lat - (radius_km / 111.0) AND user_lat + (radius_km / 111.0)
    AND d.longitude BETWEEN user_lng - (radius_km / 111.0) AND user_lng + (radius_km / 111.0)
    AND (vehicle_type_filter IS NULL OR v.vehicle_type = vehicle_type_filter)
  ORDER BY
    ((d.latitude  - user_lat) * (d.latitude  - user_lat) +
     (d.longitude - user_lng) * (d.longitude - user_lng)) ASC
  LIMIT max_results;
$$;
GRANT EXECUTE ON FUNCTION public.fetch_nearby_drivers TO anon, authenticated;


-- ─── 3. Heartbeat function (lightweight ping every 60s) ──────────────────────
-- Driver app calls this every minute even when parked.
-- This keeps updated_at fresh so they stay visible on the map.

CREATE OR REPLACE FUNCTION public.driver_heartbeat(driver_id text)
RETURNS void
LANGUAGE sql
AS $$
  UPDATE public.drivers
  SET updated_at = now()
  WHERE user_id = driver_id;
$$;
GRANT EXECUTE ON FUNCTION public.driver_heartbeat TO anon, authenticated;


-- ─── 4. Atomic accept-request → create-trip transaction ──────────────────────
-- Solves: driver accepts → app crashes → request says "accepted" but no trip.
-- The function is atomic — both succeed or both fail.

CREATE OR REPLACE FUNCTION public.accept_request_and_create_trip(
  p_request_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
  v_request public.requests%ROWTYPE;
  v_trip_id uuid;
BEGIN
  -- Lock the request row
  SELECT * INTO v_request FROM public.requests
    WHERE id = p_request_id FOR UPDATE;

  -- Reject if not pending or expired
  IF v_request.status != 'pending' THEN
    RAISE EXCEPTION 'Request is no longer pending (status=%)', v_request.status;
  END IF;
  IF v_request.expires_at < now() THEN
    UPDATE public.requests SET status = 'expired' WHERE id = p_request_id;
    RAISE EXCEPTION 'Request has expired';
  END IF;

  -- Mark request accepted
  UPDATE public.requests SET status = 'accepted' WHERE id = p_request_id;

  -- Mark driver busy
  UPDATE public.drivers SET is_busy = true WHERE user_id = v_request.driver_id;

  -- Create trip
  INSERT INTO public.trips (
    load_owner_id, driver_id,
    pickup_address, drop_address,
    pickup_lat, pickup_lng, drop_lat, drop_lng,
    status, goods_description, weight_kg, created_at
  ) VALUES (
    v_request.load_owner_id, v_request.driver_id,
    v_request.pickup_address, v_request.drop_address,
    v_request.pickup_lat, v_request.pickup_lng,
    v_request.drop_lat, v_request.drop_lng,
    'accepted', v_request.goods_description, v_request.weight_kg, now()
  ) RETURNING id INTO v_trip_id;

  RETURN v_trip_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.accept_request_and_create_trip TO anon, authenticated;


-- ─── 5. Release driver when trip ends ────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.complete_trip(p_trip_id uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_driver_id text;
BEGIN
  SELECT driver_id INTO v_driver_id FROM public.trips WHERE id = p_trip_id;

  UPDATE public.trips
    SET status = 'completed', completed_at = now()
    WHERE id = p_trip_id AND status IN ('accepted', 'in_progress');

  UPDATE public.drivers
    SET is_busy = false, total_trips = total_trips + 1
    WHERE user_id = v_driver_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.complete_trip TO anon, authenticated;


CREATE OR REPLACE FUNCTION public.cancel_trip(p_trip_id uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_driver_id text;
BEGIN
  SELECT driver_id INTO v_driver_id FROM public.trips WHERE id = p_trip_id;

  UPDATE public.trips
    SET status = 'cancelled'
    WHERE id = p_trip_id;

  UPDATE public.drivers SET is_busy = false WHERE user_id = v_driver_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.cancel_trip TO anon, authenticated;


-- ─── 6. Auto-expire stale pending requests (run periodically) ────────────────

CREATE OR REPLACE FUNCTION public.expire_stale_requests()
RETURNS void
LANGUAGE sql
AS $$
  UPDATE public.requests
  SET status = 'expired'
  WHERE status = 'pending' AND expires_at < now();
$$;
GRANT EXECUTE ON FUNCTION public.expire_stale_requests TO anon, authenticated;


-- ─── 7. Auto-cancel zombie trips stuck for >24h ──────────────────────────────

CREATE OR REPLACE FUNCTION public.cancel_zombie_trips()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  -- Release drivers from zombie trips
  UPDATE public.drivers SET is_busy = false
  WHERE user_id IN (
    SELECT driver_id FROM public.trips
    WHERE status IN ('accepted', 'in_progress')
      AND created_at < now() - interval '24 hours'
  );

  UPDATE public.trips
    SET status = 'cancelled'
    WHERE status IN ('accepted', 'in_progress')
      AND created_at < now() - interval '24 hours';
END;
$$;
GRANT EXECUTE ON FUNCTION public.cancel_zombie_trips TO anon, authenticated;


-- ─── 8. Get driver's active trip (for app restart resume) ────────────────────

CREATE OR REPLACE FUNCTION public.get_active_trip(p_user_id text)
RETURNS SETOF public.trips
LANGUAGE sql STABLE
AS $$
  SELECT * FROM public.trips
  WHERE (driver_id = p_user_id OR load_owner_id = p_user_id)
    AND status IN ('accepted', 'in_progress')
  ORDER BY created_at DESC
  LIMIT 1;
$$;
GRANT EXECUTE ON FUNCTION public.get_active_trip TO anon, authenticated;
