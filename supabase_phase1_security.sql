-- ============================================================
-- TripJio — Phase 1: Security & Auth Hardening
-- Run this in Supabase SQL Editor
-- ============================================================

-- ─── 1. Active sessions table (multi-device detection) ──────────────────────

CREATE TABLE IF NOT EXISTS public.active_sessions (
  user_id      text PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  device_id    text NOT NULL,
  fcm_token    text,
  last_seen_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_active_sessions_last_seen
  ON public.active_sessions (last_seen_at DESC);

ALTER TABLE public.active_sessions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all on active_sessions" ON public.active_sessions
  FOR ALL USING (true) WITH CHECK (true);


-- ─── 2. Rate limit table (8.6) ──────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.rate_limits (
  user_id text NOT NULL,
  action  text NOT NULL,
  window_start timestamptz NOT NULL DEFAULT now(),
  count int NOT NULL DEFAULT 1,
  PRIMARY KEY (user_id, action)
);

ALTER TABLE public.rate_limits ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all on rate_limits" ON public.rate_limits
  FOR ALL USING (true) WITH CHECK (true);


-- Generic rate limit checker: returns true if allowed, false if blocked.
-- Default: 10 actions per 60s window.
CREATE OR REPLACE FUNCTION public.check_rate_limit(
  p_user_id text,
  p_action text,
  p_max int DEFAULT 10,
  p_window_seconds int DEFAULT 60
)
RETURNS boolean
LANGUAGE plpgsql
AS $$
DECLARE
  v_row public.rate_limits%ROWTYPE;
BEGIN
  SELECT * INTO v_row FROM public.rate_limits
    WHERE user_id = p_user_id AND action = p_action FOR UPDATE;

  IF NOT FOUND THEN
    INSERT INTO public.rate_limits (user_id, action) VALUES (p_user_id, p_action);
    RETURN true;
  END IF;

  -- Window expired → reset
  IF v_row.window_start < now() - (p_window_seconds || ' seconds')::interval THEN
    UPDATE public.rate_limits
      SET window_start = now(), count = 1
      WHERE user_id = p_user_id AND action = p_action;
    RETURN true;
  END IF;

  -- Under limit → increment
  IF v_row.count < p_max THEN
    UPDATE public.rate_limits SET count = count + 1
      WHERE user_id = p_user_id AND action = p_action;
    RETURN true;
  END IF;

  RETURN false;
END;
$$;
GRANT EXECUTE ON FUNCTION public.check_rate_limit TO anon, authenticated;


-- ─── 3. Replace create_request with auth + rate-limit + validation ──────────

CREATE OR REPLACE FUNCTION public.create_request_safe(
  p_load_owner_id text,
  p_driver_id text,
  p_pickup_address text,
  p_drop_address text,
  p_pickup_lat double precision,
  p_pickup_lng double precision,
  p_drop_lat double precision,
  p_drop_lng double precision,
  p_goods_description text DEFAULT NULL,
  p_weight_kg double precision DEFAULT NULL
)
RETURNS public.requests
LANGUAGE plpgsql
AS $$
DECLARE
  v_request public.requests;
BEGIN
  -- 1. Validation (8.2, 8.3, 8.4)
  IF length(p_pickup_address) = 0 OR length(p_pickup_address) > 500 THEN
    RAISE EXCEPTION 'Invalid pickup address length';
  END IF;
  IF length(p_drop_address) = 0 OR length(p_drop_address) > 500 THEN
    RAISE EXCEPTION 'Invalid drop address length';
  END IF;
  IF p_weight_kg IS NOT NULL AND (p_weight_kg <= 0 OR p_weight_kg > 50000) THEN
    RAISE EXCEPTION 'Weight must be between 0 and 50000 kg';
  END IF;
  IF p_goods_description IS NOT NULL AND length(p_goods_description) > 1000 THEN
    RAISE EXCEPTION 'Goods description too long (max 1000 chars)';
  END IF;
  IF abs(p_pickup_lat) > 90 OR abs(p_pickup_lng) > 180 THEN
    RAISE EXCEPTION 'Invalid pickup coordinates';
  END IF;
  IF abs(p_drop_lat) > 90 OR abs(p_drop_lng) > 180 THEN
    RAISE EXCEPTION 'Invalid drop coordinates';
  END IF;

  -- 2. Rate limit: max 10 requests per 60s per user (8.6)
  IF NOT public.check_rate_limit(p_load_owner_id, 'create_request', 10, 60) THEN
    RAISE EXCEPTION 'Too many requests — please wait a moment';
  END IF;

  -- 3. Caller must be the load owner referenced
  IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = p_load_owner_id) THEN
    RAISE EXCEPTION 'Load owner not found';
  END IF;

  -- 4. Driver must exist + be online + not busy
  IF NOT EXISTS (
    SELECT 1 FROM public.drivers
    WHERE user_id = p_driver_id AND is_online = true AND is_busy = false
      AND updated_at > now() - interval '3 minutes'
  ) THEN
    RAISE EXCEPTION 'Driver is not available';
  END IF;

  -- 5. Insert
  INSERT INTO public.requests (
    load_owner_id, driver_id,
    pickup_address, drop_address,
    pickup_lat, pickup_lng, drop_lat, drop_lng,
    goods_description, weight_kg,
    status, created_at, expires_at
  ) VALUES (
    p_load_owner_id, p_driver_id,
    p_pickup_address, p_drop_address,
    p_pickup_lat, p_pickup_lng, p_drop_lat, p_drop_lng,
    p_goods_description, p_weight_kg,
    'pending', now(), now() + interval '2 minutes'
  ) RETURNING * INTO v_request;

  RETURN v_request;
END;
$$;
GRANT EXECUTE ON FUNCTION public.create_request_safe TO anon, authenticated;


-- ─── 4. Auth-checked trip RPCs (6.2) ────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.complete_trip(
  p_trip_id uuid,
  p_caller_id text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_driver_id text;
  v_load_owner_id text;
BEGIN
  SELECT driver_id, load_owner_id INTO v_driver_id, v_load_owner_id
    FROM public.trips WHERE id = p_trip_id;

  IF v_driver_id IS NULL THEN
    RAISE EXCEPTION 'Trip not found';
  END IF;

  -- Only the driver or load owner of this trip can complete it
  IF p_caller_id IS NOT NULL
     AND p_caller_id != v_driver_id
     AND p_caller_id != v_load_owner_id THEN
    RAISE EXCEPTION 'Not authorized to complete this trip';
  END IF;

  UPDATE public.trips
    SET status = 'completed', completed_at = now()
    WHERE id = p_trip_id AND status IN ('accepted', 'in_progress');

  UPDATE public.drivers
    SET is_busy = false, total_trips = total_trips + 1
    WHERE user_id = v_driver_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.complete_trip TO anon, authenticated;


CREATE OR REPLACE FUNCTION public.cancel_trip(
  p_trip_id uuid,
  p_caller_id text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_driver_id text;
  v_load_owner_id text;
BEGIN
  SELECT driver_id, load_owner_id INTO v_driver_id, v_load_owner_id
    FROM public.trips WHERE id = p_trip_id;

  IF v_driver_id IS NULL THEN
    RAISE EXCEPTION 'Trip not found';
  END IF;

  IF p_caller_id IS NOT NULL
     AND p_caller_id != v_driver_id
     AND p_caller_id != v_load_owner_id THEN
    RAISE EXCEPTION 'Not authorized to cancel this trip';
  END IF;

  UPDATE public.trips SET status = 'cancelled' WHERE id = p_trip_id;
  UPDATE public.drivers SET is_busy = false WHERE user_id = v_driver_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.cancel_trip TO anon, authenticated;


-- ─── 5. Multi-device session management (1.8) ───────────────────────────────

CREATE OR REPLACE FUNCTION public.register_session(
  p_user_id text,
  p_device_id text,
  p_fcm_token text DEFAULT NULL
)
RETURNS text   -- returns 'new' if new device, 'replaced' if took over from another device
LANGUAGE plpgsql
AS $$
DECLARE
  v_old_device text;
BEGIN
  SELECT device_id INTO v_old_device FROM public.active_sessions
    WHERE user_id = p_user_id;

  INSERT INTO public.active_sessions (user_id, device_id, fcm_token, last_seen_at)
  VALUES (p_user_id, p_device_id, p_fcm_token, now())
  ON CONFLICT (user_id) DO UPDATE
    SET device_id    = EXCLUDED.device_id,
        fcm_token    = EXCLUDED.fcm_token,
        last_seen_at = now();

  IF v_old_device IS NULL THEN
    RETURN 'new';
  ELSIF v_old_device = p_device_id THEN
    RETURN 'same';
  ELSE
    RETURN 'replaced';
  END IF;
END;
$$;
GRANT EXECUTE ON FUNCTION public.register_session TO anon, authenticated;


CREATE OR REPLACE FUNCTION public.is_session_valid(
  p_user_id text,
  p_device_id text
)
RETURNS boolean
LANGUAGE sql STABLE
AS $$
  SELECT EXISTS(
    SELECT 1 FROM public.active_sessions
    WHERE user_id = p_user_id AND device_id = p_device_id
  );
$$;
GRANT EXECUTE ON FUNCTION public.is_session_valid TO anon, authenticated;
