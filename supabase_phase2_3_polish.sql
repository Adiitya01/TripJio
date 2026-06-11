-- ============================================================
-- TripJio — Phase 2 + Phase 3 + Missed Edge Cases
-- Run this in Supabase SQL Editor (LAST — after Phase 1)
-- ============================================================

-- ─── 1. Race-safe cancellation (4.3) ────────────────────────────────────────
-- If load owner tries to cancel exactly when driver is accepting,
-- we lock both rows; whichever transaction commits first wins.

CREATE OR REPLACE FUNCTION public.cancel_request_safe(
  p_request_id uuid,
  p_caller_id text
)
RETURNS text   -- returns the request's final status
LANGUAGE plpgsql
AS $$
DECLARE
  v_request public.requests%ROWTYPE;
BEGIN
  -- Row lock prevents the accept-RPC from racing past us
  SELECT * INTO v_request FROM public.requests
    WHERE id = p_request_id FOR UPDATE;

  IF v_request.id IS NULL THEN
    RAISE EXCEPTION 'Request not found';
  END IF;

  -- Only the load owner can cancel their own request
  IF v_request.load_owner_id != p_caller_id THEN
    RAISE EXCEPTION 'Not authorized to cancel this request';
  END IF;

  -- Already-accepted → too late, refuse cancel (driver is on the way)
  IF v_request.status = 'accepted' THEN
    RAISE EXCEPTION 'Driver already accepted — cancel the trip instead';
  END IF;

  -- Only pending requests can be cancelled
  IF v_request.status != 'pending' THEN
    RETURN v_request.status;
  END IF;

  UPDATE public.requests SET status = 'cancelled' WHERE id = p_request_id;
  RETURN 'cancelled';
END;
$$;
GRANT EXECUTE ON FUNCTION public.cancel_request_safe TO anon, authenticated;


-- ─── 2. Block driver from going offline mid-trip ────────────────────────────

CREATE OR REPLACE FUNCTION public.set_driver_online_safe(
  p_user_id text,
  p_online boolean
)
RETURNS text   -- 'ok' or 'blocked_active_trip'
LANGUAGE plpgsql
AS $$
DECLARE
  v_has_trip boolean;
BEGIN
  -- If trying to go offline, check for active trip
  IF NOT p_online THEN
    SELECT EXISTS(
      SELECT 1 FROM public.trips
      WHERE driver_id = p_user_id
        AND status IN ('accepted', 'in_progress')
    ) INTO v_has_trip;

    IF v_has_trip THEN
      RETURN 'blocked_active_trip';
    END IF;
  END IF;

  UPDATE public.drivers
    SET is_online = p_online, updated_at = now()
    WHERE user_id = p_user_id;
  RETURN 'ok';
END;
$$;
GRANT EXECUTE ON FUNCTION public.set_driver_online_safe TO anon, authenticated;


-- ─── 3. Get driver's full state (for app cold-start restore) ────────────────
-- Returns: is_online, is_busy, has_active_trip, active_trip_id, latitude, longitude

CREATE OR REPLACE FUNCTION public.get_driver_state(p_user_id text)
RETURNS TABLE (
  is_online boolean,
  is_busy boolean,
  has_active_trip boolean,
  active_trip_id uuid,
  latitude double precision,
  longitude double precision
)
LANGUAGE plpgsql STABLE
AS $$
DECLARE
  v_trip_id uuid;
BEGIN
  SELECT id INTO v_trip_id FROM public.trips
    WHERE driver_id = p_user_id AND status IN ('accepted', 'in_progress')
    ORDER BY created_at DESC LIMIT 1;

  RETURN QUERY
  SELECT d.is_online, d.is_busy,
         (v_trip_id IS NOT NULL),
         v_trip_id,
         d.latitude, d.longitude
  FROM public.drivers d
  WHERE d.user_id = p_user_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_driver_state TO anon, authenticated;


-- ─── 4. Prevent duplicate vehicle plate numbers ─────────────────────────────

CREATE UNIQUE INDEX IF NOT EXISTS idx_vehicles_unique_number
  ON public.vehicles (vehicle_number);


-- ─── 5. Prevent duplicate driver license numbers ────────────────────────────

CREATE UNIQUE INDEX IF NOT EXISTS idx_drivers_unique_license
  ON public.drivers (license_number);


-- ─── 6. Notify driver when load owner cancels (10.2) ────────────────────────
-- Already covered: RequestRepository.listenToRequestStatus fires on UPDATE
-- of requests table. Cancellation → status='cancelled' → driver app sees it.
-- No DB change needed — Dart side handles it.


-- ─── 7. Backwards-compat: keep the older RPCs working alongside new ones ─────
-- Older `complete_trip(p_trip_id)` callers still work because the new signature
-- with optional p_caller_id is backward-compatible.
