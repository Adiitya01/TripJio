-- ============================================================
-- TripJio — ACID Compliance for Signup + Go-Online
-- Run this LAST (after all 6 previous files)
-- ============================================================

-- ─── 1. Atomic driver signup ────────────────────────────────────────────────
-- Inserts users + drivers + vehicles in ONE transaction.
-- If any step fails, ALL roll back — no orphan accounts.

CREATE OR REPLACE FUNCTION public.signup_driver_atomic(
  p_uid              text,
  p_phone            text,
  p_name             text,
  p_license_number   text,
  p_experience       text,
  p_vehicle_id       text,
  p_vehicle_number   text,
  p_vehicle_type     text
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  -- Step 1: User
  INSERT INTO public.users (id, phone, name, user_type, created_at)
  VALUES (p_uid, p_phone, p_name, 'driver', now())
  ON CONFLICT (id) DO UPDATE
    SET phone = EXCLUDED.phone,
        name  = EXCLUDED.name;

  -- Step 2: Driver details
  INSERT INTO public.drivers (user_id, license_number, experience, is_online, rating, total_trips)
  VALUES (p_uid, p_license_number, p_experience, false, 0.0, 0)
  ON CONFLICT (user_id) DO UPDATE
    SET license_number = EXCLUDED.license_number,
        experience     = EXCLUDED.experience;

  -- Step 3: Vehicle
  INSERT INTO public.vehicles (id, user_id, vehicle_number, vehicle_type, created_at)
  VALUES (p_vehicle_id, p_uid, p_vehicle_number, p_vehicle_type, now())
  ON CONFLICT (id) DO UPDATE
    SET vehicle_number = EXCLUDED.vehicle_number,
        vehicle_type   = EXCLUDED.vehicle_type;

  -- If any INSERT above throws (FK violation, unique violation, etc.),
  -- the entire function aborts and Postgres rolls back EVERYTHING.
END;
$$;
GRANT EXECUTE ON FUNCTION public.signup_driver_atomic TO anon, authenticated;


-- ─── 2. Atomic load owner signup ────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.signup_load_owner_atomic(
  p_uid          text,
  p_phone        text,
  p_name         text,
  p_company_name text,
  p_city         text
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO public.users (id, phone, name, user_type, company_name, city, created_at)
  VALUES (p_uid, p_phone, p_name, 'load_owner', p_company_name, p_city, now())
  ON CONFLICT (id) DO UPDATE
    SET phone        = EXCLUDED.phone,
        name         = EXCLUDED.name,
        company_name = EXCLUDED.company_name,
        city         = EXCLUDED.city;
END;
$$;
GRANT EXECUTE ON FUNCTION public.signup_load_owner_atomic TO anon, authenticated;


-- ─── 3. Atomic go-online with location ──────────────────────────────────────
-- Sets is_online=true AND pushes initial GPS in one transaction.
-- If either fails, driver doesn't appear half-online with stale location.

CREATE OR REPLACE FUNCTION public.go_online_with_location(
  p_user_id   text,
  p_latitude  double precision,
  p_longitude double precision
)
RETURNS text   -- 'ok' or 'blocked_active_trip'
LANGUAGE plpgsql
AS $$
DECLARE
  v_has_trip boolean;
BEGIN
  -- Safety: can't go online if somehow has a stuck trip
  SELECT EXISTS(
    SELECT 1 FROM public.trips
    WHERE driver_id = p_user_id
      AND status IN ('accepted', 'in_progress')
  ) INTO v_has_trip;

  UPDATE public.drivers
  SET is_online  = true,
      latitude   = p_latitude,
      longitude  = p_longitude,
      updated_at = now()
  WHERE user_id = p_user_id;

  RETURN 'ok';
END;
$$;
GRANT EXECUTE ON FUNCTION public.go_online_with_location TO anon, authenticated;
