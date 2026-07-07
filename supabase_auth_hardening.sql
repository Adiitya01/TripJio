-- ============================================================
-- TripJio — Auth Hardening (Firebase → Supabase identity)
-- RUN THIS LAST, after ALL other supabase_*.sql files.
-- Safe to run repeatedly (idempotent).
-- ============================================================
-- Fixes three systemic security holes:
--   1. Permissive RLS (USING(true)) + anon-key-only access → anyone with
--      the shipped anon key had full read/write on all tables (PII + live
--      driver GPS). Now anon has NO table access; authenticated access is
--      scoped to the caller's own rows.
--   2. RPCs trusted a client-supplied caller id (p_uid / p_user_id /
--      p_caller_id / p_load_owner_id) → impersonation. Every RPC now derives
--      and verifies identity from the verified Firebase token.
--   3. complete_trip / cancel_trip skipped their auth check when p_caller_id
--      was NULL, and unchecked single-arg overloads existed. Now they fail
--      closed and the unchecked overloads are dropped.
--
-- PREREQUISITE (cannot be done from SQL — do it in the dashboard):
--   Supabase Dashboard → Authentication → Sign In / Providers →
--   Third-Party Auth → add Firebase with this project's Firebase project ID.
--   This makes Supabase accept the Firebase ID token the app now sends
--   (see accessToken callback in lib/main.dart) and assign it the
--   `authenticated` role, exposing the Firebase UID as auth.jwt()->>'sub'.
--   Until this is configured, all authenticated requests will be rejected.
-- ============================================================


-- ─── 0. Identity helper ─────────────────────────────────────────────────────
-- Firebase UIDs are NOT UUIDs, so auth.uid() (which casts sub::uuid) is
-- unusable here. Read the raw text subject claim instead.

CREATE OR REPLACE FUNCTION public.current_uid()
RETURNS text
LANGUAGE sql
STABLE
AS $$
  SELECT nullif(current_setting('request.jwt.claims', true)::jsonb->>'sub', '');
$$;
GRANT EXECUTE ON FUNCTION public.current_uid() TO anon, authenticated;


-- ─── 1. Replace permissive RLS policies with owner-scoped ones ──────────────

-- Drop the old wide-open policies.
DROP POLICY IF EXISTS "Users can insert own profile" ON public.users;
DROP POLICY IF EXISTS "Users can read own profile"   ON public.users;
DROP POLICY IF EXISTS "Users can update own profile" ON public.users;
DROP POLICY IF EXISTS "Allow all on drivers"         ON public.drivers;
DROP POLICY IF EXISTS "Allow all on vehicles"        ON public.vehicles;
DROP POLICY IF EXISTS "Allow all on trips"           ON public.trips;
DROP POLICY IF EXISTS "Allow all on requests"        ON public.requests;
DROP POLICY IF EXISTS "Allow all on active_sessions" ON public.active_sessions;
DROP POLICY IF EXISTS "Allow all on rate_limits"     ON public.rate_limits;

-- Ensure RLS is on everywhere (no-op if already enabled).
ALTER TABLE public.users           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.drivers         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehicles        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trips           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.requests        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.active_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rate_limits     ENABLE ROW LEVEL SECURITY;

-- users: any authenticated user may READ any profile (marketplace needs to
-- show the counterparty's name/phone and let owners browse drivers), but may
-- only WRITE their own row.
CREATE POLICY users_select ON public.users
  FOR SELECT TO authenticated USING (true);
CREATE POLICY users_insert ON public.users
  FOR INSERT TO authenticated WITH CHECK (id = public.current_uid());
CREATE POLICY users_update ON public.users
  FOR UPDATE TO authenticated
  USING (id = public.current_uid()) WITH CHECK (id = public.current_uid());
CREATE POLICY users_delete ON public.users
  FOR DELETE TO authenticated USING (id = public.current_uid());

-- drivers: readable by authenticated (owners discover online drivers);
-- writable only by the driver themselves.
CREATE POLICY drivers_select ON public.drivers
  FOR SELECT TO authenticated USING (true);
CREATE POLICY drivers_insert ON public.drivers
  FOR INSERT TO authenticated WITH CHECK (user_id = public.current_uid());
CREATE POLICY drivers_update ON public.drivers
  FOR UPDATE TO authenticated
  USING (user_id = public.current_uid()) WITH CHECK (user_id = public.current_uid());
CREATE POLICY drivers_delete ON public.drivers
  FOR DELETE TO authenticated USING (user_id = public.current_uid());

-- vehicles: readable by authenticated; writable only by the owner.
CREATE POLICY vehicles_select ON public.vehicles
  FOR SELECT TO authenticated USING (true);
CREATE POLICY vehicles_insert ON public.vehicles
  FOR INSERT TO authenticated WITH CHECK (user_id = public.current_uid());
CREATE POLICY vehicles_update ON public.vehicles
  FOR UPDATE TO authenticated
  USING (user_id = public.current_uid()) WITH CHECK (user_id = public.current_uid());
CREATE POLICY vehicles_delete ON public.vehicles
  FOR DELETE TO authenticated USING (user_id = public.current_uid());

-- trips: only the two participants can see or touch a trip.
CREATE POLICY trips_select ON public.trips
  FOR SELECT TO authenticated
  USING (load_owner_id = public.current_uid() OR driver_id = public.current_uid());
CREATE POLICY trips_insert ON public.trips
  FOR INSERT TO authenticated
  WITH CHECK (load_owner_id = public.current_uid() OR driver_id = public.current_uid());
CREATE POLICY trips_update ON public.trips
  FOR UPDATE TO authenticated
  USING (load_owner_id = public.current_uid() OR driver_id = public.current_uid())
  WITH CHECK (load_owner_id = public.current_uid() OR driver_id = public.current_uid());

-- requests: participants may READ (driver sees incoming, owner sees status).
-- All writes go through SECURITY DEFINER RPCs below — no direct write policy.
CREATE POLICY requests_select ON public.requests
  FOR SELECT TO authenticated
  USING (load_owner_id = public.current_uid() OR driver_id = public.current_uid());

-- active_sessions: a user may only see/manage their own session row.
CREATE POLICY active_sessions_rw ON public.active_sessions
  FOR ALL TO authenticated
  USING (user_id = public.current_uid()) WITH CHECK (user_id = public.current_uid());

-- rate_limits: no policy at all → all direct access denied. Only the
-- SECURITY DEFINER check_rate_limit() touches it.


-- ─── 2. Table privileges: remove anon entirely, scope authenticated ─────────
-- Supabase grants table DML to anon+authenticated by default; RLS then
-- filters. Revoking from anon means an unauthenticated anon-key holder can no
-- longer reach any table at all.

REVOKE ALL ON public.users, public.drivers, public.vehicles,
              public.trips, public.requests, public.active_sessions,
              public.rate_limits
  FROM anon;

REVOKE ALL ON public.rate_limits FROM authenticated;

GRANT SELECT, INSERT, UPDATE, DELETE
  ON public.users, public.drivers, public.vehicles
  TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.trips TO authenticated;
GRANT SELECT ON public.requests TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.active_sessions TO authenticated;


-- ─── 3. Drop the unchecked single-arg trip RPC overloads (Vuln 3) ───────────
DROP FUNCTION IF EXISTS public.complete_trip(uuid);
DROP FUNCTION IF EXISTS public.cancel_trip(uuid);


-- ─── 4. Harden every RPC: SECURITY DEFINER + token-derived identity ─────────
-- All become SECURITY DEFINER (so they can perform the legitimate
-- cross-identity writes, e.g. releasing a driver) with a locked search_path,
-- and every one verifies the acting user against public.current_uid().
-- Client-supplied id parameters are KEPT (so the app needs no signature
-- changes) but are now only trusted when they match the verified token.

-- 4.1 Signups — you may only create/update YOUR OWN account row.
CREATE OR REPLACE FUNCTION public.signup_driver_atomic(
  p_uid text, p_phone text, p_name text, p_license_number text,
  p_experience text, p_vehicle_id text, p_vehicle_number text, p_vehicle_type text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF public.current_uid() IS NULL OR public.current_uid() <> p_uid THEN
    RAISE EXCEPTION 'Not authorized' USING errcode = '42501';
  END IF;

  INSERT INTO public.users (id, phone, name, user_type, created_at)
  VALUES (p_uid, p_phone, p_name, 'driver', now())
  ON CONFLICT (id) DO UPDATE
    SET phone = EXCLUDED.phone, name = EXCLUDED.name;

  INSERT INTO public.drivers (user_id, license_number, experience, is_online, rating, total_trips)
  VALUES (p_uid, p_license_number, p_experience, false, 0.0, 0)
  ON CONFLICT (user_id) DO UPDATE
    SET license_number = EXCLUDED.license_number, experience = EXCLUDED.experience;

  INSERT INTO public.vehicles (id, user_id, vehicle_number, vehicle_type, created_at)
  VALUES (p_vehicle_id, p_uid, p_vehicle_number, p_vehicle_type, now())
  ON CONFLICT (id) DO UPDATE
    SET vehicle_number = EXCLUDED.vehicle_number, vehicle_type = EXCLUDED.vehicle_type;
END;
$$;

CREATE OR REPLACE FUNCTION public.signup_load_owner_atomic(
  p_uid text, p_phone text, p_name text, p_company_name text, p_city text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF public.current_uid() IS NULL OR public.current_uid() <> p_uid THEN
    RAISE EXCEPTION 'Not authorized' USING errcode = '42501';
  END IF;

  INSERT INTO public.users (id, phone, name, user_type, company_name, city, created_at)
  VALUES (p_uid, p_phone, p_name, 'load_owner', p_company_name, p_city, now())
  ON CONFLICT (id) DO UPDATE
    SET phone = EXCLUDED.phone, name = EXCLUDED.name,
        company_name = EXCLUDED.company_name, city = EXCLUDED.city;
END;
$$;

-- 4.2 Driver presence — you may only move/toggle YOUR OWN driver row.
CREATE OR REPLACE FUNCTION public.go_online_with_location(
  p_user_id text, p_latitude double precision, p_longitude double precision
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF public.current_uid() IS NULL OR public.current_uid() <> p_user_id THEN
    RAISE EXCEPTION 'Not authorized' USING errcode = '42501';
  END IF;

  UPDATE public.drivers
    SET is_online = true, latitude = p_latitude, longitude = p_longitude, updated_at = now()
    WHERE user_id = p_user_id;
  RETURN 'ok';
END;
$$;

CREATE OR REPLACE FUNCTION public.set_driver_online_safe(
  p_user_id text, p_online boolean
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_has_trip boolean;
BEGIN
  IF public.current_uid() IS NULL OR public.current_uid() <> p_user_id THEN
    RAISE EXCEPTION 'Not authorized' USING errcode = '42501';
  END IF;

  IF NOT p_online THEN
    SELECT EXISTS(
      SELECT 1 FROM public.trips
      WHERE driver_id = p_user_id AND status IN ('accepted', 'in_progress')
    ) INTO v_has_trip;
    IF v_has_trip THEN
      RETURN 'blocked_active_trip';
    END IF;
  END IF;

  UPDATE public.drivers SET is_online = p_online, updated_at = now()
    WHERE user_id = p_user_id;
  RETURN 'ok';
END;
$$;

CREATE OR REPLACE FUNCTION public.driver_heartbeat(driver_id text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF public.current_uid() IS NULL OR public.current_uid() <> driver_id THEN
    RAISE EXCEPTION 'Not authorized' USING errcode = '42501';
  END IF;
  UPDATE public.drivers SET updated_at = now() WHERE user_id = driver_id;
END;
$$;

-- 4.3 Request creation — you may only create requests AS yourself.
CREATE OR REPLACE FUNCTION public.create_request_safe(
  p_load_owner_id text, p_driver_id text, p_pickup_address text, p_drop_address text,
  p_pickup_lat double precision, p_pickup_lng double precision,
  p_drop_lat double precision, p_drop_lng double precision,
  p_goods_description text DEFAULT NULL, p_weight_kg double precision DEFAULT NULL
)
RETURNS public.requests
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_request public.requests;
BEGIN
  IF public.current_uid() IS NULL OR public.current_uid() <> p_load_owner_id THEN
    RAISE EXCEPTION 'Not authorized' USING errcode = '42501';
  END IF;

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

  IF NOT public.check_rate_limit(p_load_owner_id, 'create_request', 10, 60) THEN
    RAISE EXCEPTION 'Too many requests — please wait a moment';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = p_load_owner_id) THEN
    RAISE EXCEPTION 'Load owner not found';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.drivers
    WHERE user_id = p_driver_id AND is_online = true AND is_busy = false
      AND updated_at > now() - interval '3 minutes'
  ) THEN
    RAISE EXCEPTION 'Driver is not available';
  END IF;

  INSERT INTO public.requests (
    load_owner_id, driver_id, pickup_address, drop_address,
    pickup_lat, pickup_lng, drop_lat, drop_lng,
    goods_description, weight_kg, status, created_at, expires_at
  ) VALUES (
    p_load_owner_id, p_driver_id, p_pickup_address, p_drop_address,
    p_pickup_lat, p_pickup_lng, p_drop_lat, p_drop_lng,
    p_goods_description, p_weight_kg, 'pending', now(), now() + interval '2 minutes'
  ) RETURNING * INTO v_request;

  RETURN v_request;
END;
$$;

CREATE OR REPLACE FUNCTION public.check_rate_limit(
  p_user_id text, p_action text, p_max int DEFAULT 10, p_window_seconds int DEFAULT 60
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public, pg_temp
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

  IF v_row.window_start < now() - (p_window_seconds || ' seconds')::interval THEN
    UPDATE public.rate_limits SET window_start = now(), count = 1
      WHERE user_id = p_user_id AND action = p_action;
    RETURN true;
  END IF;

  IF v_row.count < p_max THEN
    UPDATE public.rate_limits SET count = count + 1
      WHERE user_id = p_user_id AND action = p_action;
    RETURN true;
  END IF;

  RETURN false;
END;
$$;

-- 4.4 Accept request — only the DRIVER named on the request may accept it.
CREATE OR REPLACE FUNCTION public.accept_request_and_create_trip(p_request_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_request public.requests%ROWTYPE;
  v_trip_id uuid;
BEGIN
  SELECT * INTO v_request FROM public.requests WHERE id = p_request_id FOR UPDATE;

  IF v_request.id IS NULL THEN
    RAISE EXCEPTION 'Request not found';
  END IF;
  IF public.current_uid() IS NULL OR public.current_uid() <> v_request.driver_id THEN
    RAISE EXCEPTION 'Not authorized' USING errcode = '42501';
  END IF;
  IF v_request.status != 'pending' THEN
    RAISE EXCEPTION 'Request is no longer pending (status=%)', v_request.status;
  END IF;
  IF v_request.expires_at < now() THEN
    UPDATE public.requests SET status = 'expired' WHERE id = p_request_id;
    RAISE EXCEPTION 'Request has expired';
  END IF;

  UPDATE public.requests SET status = 'accepted' WHERE id = p_request_id;
  UPDATE public.drivers SET is_busy = true WHERE user_id = v_request.driver_id;

  INSERT INTO public.trips (
    load_owner_id, driver_id, pickup_address, drop_address,
    pickup_lat, pickup_lng, drop_lat, drop_lng,
    status, goods_description, weight_kg, created_at
  ) VALUES (
    v_request.load_owner_id, v_request.driver_id,
    v_request.pickup_address, v_request.drop_address,
    v_request.pickup_lat, v_request.pickup_lng, v_request.drop_lat, v_request.drop_lng,
    'accepted', v_request.goods_description, v_request.weight_kg, now()
  ) RETURNING id INTO v_trip_id;

  RETURN v_trip_id;
END;
$$;

-- 4.5 Cancel request — only the OWNER of the request may cancel it.
CREATE OR REPLACE FUNCTION public.cancel_request_safe(
  p_request_id uuid, p_caller_id text
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_request public.requests%ROWTYPE;
BEGIN
  SELECT * INTO v_request FROM public.requests WHERE id = p_request_id FOR UPDATE;

  IF v_request.id IS NULL THEN
    RAISE EXCEPTION 'Request not found';
  END IF;
  -- Identity comes from the verified token, NOT the p_caller_id argument.
  IF public.current_uid() IS NULL OR v_request.load_owner_id <> public.current_uid() THEN
    RAISE EXCEPTION 'Not authorized to cancel this request' USING errcode = '42501';
  END IF;
  IF v_request.status = 'accepted' THEN
    RAISE EXCEPTION 'Driver already accepted — cancel the trip instead';
  END IF;
  IF v_request.status != 'pending' THEN
    RETURN v_request.status;
  END IF;

  UPDATE public.requests SET status = 'cancelled' WHERE id = p_request_id;
  RETURN 'cancelled';
END;
$$;

-- 4.6 Complete / cancel trip — only a participant, fail closed on no identity.
CREATE OR REPLACE FUNCTION public.complete_trip(
  p_trip_id uuid, p_caller_id text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_driver_id text;
  v_load_owner_id text;
  v_uid text := public.current_uid();
BEGIN
  SELECT driver_id, load_owner_id INTO v_driver_id, v_load_owner_id
    FROM public.trips WHERE id = p_trip_id;
  IF v_driver_id IS NULL THEN
    RAISE EXCEPTION 'Trip not found';
  END IF;
  IF v_uid IS NULL OR (v_uid <> v_driver_id AND v_uid <> v_load_owner_id) THEN
    RAISE EXCEPTION 'Not authorized to complete this trip' USING errcode = '42501';
  END IF;

  UPDATE public.trips SET status = 'completed', completed_at = now()
    WHERE id = p_trip_id AND status IN ('accepted', 'in_progress');
  UPDATE public.drivers SET is_busy = false, total_trips = total_trips + 1
    WHERE user_id = v_driver_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.cancel_trip(
  p_trip_id uuid, p_caller_id text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_driver_id text;
  v_load_owner_id text;
  v_uid text := public.current_uid();
BEGIN
  SELECT driver_id, load_owner_id INTO v_driver_id, v_load_owner_id
    FROM public.trips WHERE id = p_trip_id;
  IF v_driver_id IS NULL THEN
    RAISE EXCEPTION 'Trip not found';
  END IF;
  IF v_uid IS NULL OR (v_uid <> v_driver_id AND v_uid <> v_load_owner_id) THEN
    RAISE EXCEPTION 'Not authorized to cancel this trip' USING errcode = '42501';
  END IF;

  UPDATE public.trips SET status = 'cancelled' WHERE id = p_trip_id;
  UPDATE public.drivers SET is_busy = false WHERE user_id = v_driver_id;
END;
$$;

-- 4.7 Flagged completion (drop-pin override) — driver-only, fail closed.
CREATE OR REPLACE FUNCTION public.complete_trip_flagged(
  p_trip_id uuid, p_caller_id text,
  p_lat double precision, p_lng double precision, p_distance_m double precision
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_driver_id text;
  v_status text;
  v_uid text := public.current_uid();
BEGIN
  SELECT driver_id, status INTO v_driver_id, v_status
    FROM public.trips WHERE id = p_trip_id;
  IF v_driver_id IS NULL THEN
    RAISE EXCEPTION 'Trip not found';
  END IF;
  IF v_uid IS NULL OR v_uid <> v_driver_id THEN
    RAISE EXCEPTION 'Not authorized to complete this trip' USING errcode = '42501';
  END IF;
  IF v_status NOT IN ('accepted', 'in_progress') THEN
    RAISE EXCEPTION 'Trip is not active';
  END IF;
  IF abs(p_lat) > 90 OR abs(p_lng) > 180 THEN
    RAISE EXCEPTION 'Invalid coordinates';
  END IF;
  IF p_distance_m IS NULL OR p_distance_m < 0 OR p_distance_m > 100000 THEN
    RAISE EXCEPTION 'Invalid distance';
  END IF;

  UPDATE public.trips
    SET completion_flagged = true, completion_lat = p_lat,
        completion_lng = p_lng, completion_distance_m = p_distance_m
    WHERE id = p_trip_id;

  PERFORM public.complete_trip(p_trip_id, p_caller_id);
END;
$$;

-- 4.8 Session registration — you may only register YOUR OWN session.
CREATE OR REPLACE FUNCTION public.register_session(
  p_user_id text, p_device_id text, p_fcm_token text DEFAULT NULL
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_old_device text;
BEGIN
  IF public.current_uid() IS NULL OR public.current_uid() <> p_user_id THEN
    RAISE EXCEPTION 'Not authorized' USING errcode = '42501';
  END IF;

  SELECT device_id INTO v_old_device FROM public.active_sessions WHERE user_id = p_user_id;

  INSERT INTO public.active_sessions (user_id, device_id, fcm_token, last_seen_at)
  VALUES (p_user_id, p_device_id, p_fcm_token, now())
  ON CONFLICT (user_id) DO UPDATE
    SET device_id = EXCLUDED.device_id, fcm_token = EXCLUDED.fcm_token, last_seen_at = now();

  IF v_old_device IS NULL THEN RETURN 'new';
  ELSIF v_old_device = p_device_id THEN RETURN 'same';
  ELSE RETURN 'replaced';
  END IF;
END;
$$;

-- 4.9 State reads — you may only read YOUR OWN state.
CREATE OR REPLACE FUNCTION public.get_active_trip(p_user_id text)
RETURNS SETOF public.trips
LANGUAGE plpgsql
STABLE
SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF public.current_uid() IS NULL OR public.current_uid() <> p_user_id THEN
    RAISE EXCEPTION 'Not authorized' USING errcode = '42501';
  END IF;
  RETURN QUERY
    SELECT * FROM public.trips
    WHERE (driver_id = p_user_id OR load_owner_id = p_user_id)
      AND status IN ('accepted', 'in_progress')
    ORDER BY created_at DESC LIMIT 1;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_driver_state(p_user_id text)
RETURNS TABLE (
  is_online boolean, is_busy boolean, has_active_trip boolean,
  active_trip_id uuid, latitude double precision, longitude double precision
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_trip_id uuid;
BEGIN
  IF public.current_uid() IS NULL OR public.current_uid() <> p_user_id THEN
    RAISE EXCEPTION 'Not authorized' USING errcode = '42501';
  END IF;

  SELECT id INTO v_trip_id FROM public.trips
    WHERE driver_id = p_user_id AND status IN ('accepted', 'in_progress')
    ORDER BY created_at DESC LIMIT 1;

  RETURN QUERY
    SELECT d.is_online, d.is_busy, (v_trip_id IS NOT NULL), v_trip_id,
           d.latitude, d.longitude
    FROM public.drivers d WHERE d.user_id = p_user_id;
END;
$$;

-- 4.10 Nearby drivers — authenticated only (performs a maintenance write).
CREATE OR REPLACE FUNCTION public.fetch_nearby_drivers(
  user_lat float, user_lng float, radius_km float,
  vehicle_type_filter text DEFAULT NULL, max_results int DEFAULT 50,
  freshness_minutes int DEFAULT 3
)
RETURNS TABLE (
  user_id text, name text, vehicle_type text, vehicle_number text,
  rating numeric, total_trips int, latitude double precision,
  longitude double precision, distance_meters double precision
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  user_point geography := ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326)::geography;
BEGIN
  IF public.current_uid() IS NULL THEN
    RAISE EXCEPTION 'Not authorized' USING errcode = '42501';
  END IF;

  PERFORM public.auto_offline_stale_drivers(30);

  RETURN QUERY
    SELECT d.user_id, u.name,
           COALESCE(v.vehicle_type, 'Mini Truck'),
           COALESCE(v.vehicle_number, 'N/A'),
           d.rating, d.total_trips, d.latitude, d.longitude,
           ST_Distance(d.location, user_point) AS distance_meters
    FROM public.drivers d
    INNER JOIN public.users u ON u.id = d.user_id
    LEFT  JOIN public.vehicles v ON v.user_id = d.user_id
    WHERE d.is_online = true AND d.is_busy = false AND d.location IS NOT NULL
      AND d.updated_at > now() - (freshness_minutes || ' minutes')::interval
      AND ST_DWithin(d.location, user_point, radius_km * 1000)
      AND (vehicle_type_filter IS NULL OR v.vehicle_type = vehicle_type_filter)
    ORDER BY d.location <-> user_point
    LIMIT max_results;
END;
$$;

-- 4.11 increment_driver_trips is now DEAD (complete_trip owns the increment).
-- Keep the name defined but locked to admin only, so the removed client call
-- can never be reintroduced as an abuse vector.
CREATE OR REPLACE FUNCTION public.increment_driver_trips(driver_id text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  RAISE EXCEPTION 'increment_driver_trips is disabled; total_trips is maintained by complete_trip';
END;
$$;


-- ─── 5. Function execute grants ─────────────────────────────────────────────
-- Revoke the implicit PUBLIC grant + anon on user-facing RPCs, then grant to
-- authenticated only. Identity guards above are the primary defense; this is
-- defense in depth so an anon-key holder cannot even invoke them.

DO $$
DECLARE
  fn text;
  fns text[] := ARRAY[
    'public.signup_driver_atomic(text,text,text,text,text,text,text,text)',
    'public.signup_load_owner_atomic(text,text,text,text,text)',
    'public.go_online_with_location(text,double precision,double precision)',
    'public.set_driver_online_safe(text,boolean)',
    'public.driver_heartbeat(text)',
    'public.create_request_safe(text,text,text,text,double precision,double precision,double precision,double precision,text,double precision)',
    'public.accept_request_and_create_trip(uuid)',
    'public.cancel_request_safe(uuid,text)',
    'public.complete_trip(uuid,text)',
    'public.cancel_trip(uuid,text)',
    'public.complete_trip_flagged(uuid,text,double precision,double precision,double precision)',
    'public.register_session(text,text,text)',
    'public.get_active_trip(text)',
    'public.get_driver_state(text)',
    'public.fetch_nearby_drivers(float,float,float,text,int,int)',
    'public.check_rate_limit(text,text,int,int)',
    'public.increment_driver_trips(text)',
    'public.auto_offline_stale_drivers(int)',
    'public.expire_stale_requests()',
    'public.cancel_zombie_trips()'
  ];
BEGIN
  FOREACH fn IN ARRAY fns LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon;', fn);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated;', fn);
  END LOOP;
END $$;

-- current_uid stays available to both roles (returns NULL for anon).
GRANT EXECUTE ON FUNCTION public.current_uid() TO anon, authenticated;
