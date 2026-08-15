-- ============================================================
-- TripJio — Auto-Offline Stale Drivers (Uber-style)
-- ============================================================
-- Multi-tier driver state management:
--   Online        — ping within last 3 min          (visible)
--   Stale         — no ping 3-30 min                  (hidden in search, session alive)
--   Auto-Offline  — no ping 30+ min                   (is_online=false, must toggle ON)
-- ============================================================


-- ─── 1. Auto-offline drivers idle longer than X minutes ─────────────────────

CREATE OR REPLACE FUNCTION public.auto_offline_stale_drivers(
  p_threshold_minutes int DEFAULT 30
)
RETURNS int   -- returns number of drivers set offline
LANGUAGE plpgsql
AS $$
DECLARE
  v_count int;
BEGIN
  WITH stale AS (
    UPDATE public.drivers
    SET is_online = false
    WHERE is_online = true
      AND is_busy   = false      -- ⚠️ never offline a driver mid-trip
      AND updated_at < now() - (p_threshold_minutes || ' minutes')::interval
    RETURNING user_id
  )
  SELECT count(*) INTO v_count FROM stale;
  RETURN v_count;
END;
$$;
GRANT EXECUTE ON FUNCTION public.auto_offline_stale_drivers TO anon, authenticated;


-- ─── 2. Lazy cleanup on every fetch (no cron needed) ────────────────────────
-- Modifies fetch_nearby_drivers to run cleanup as the first step.

DO $$
DECLARE func_oid oid;
BEGIN
  FOR func_oid IN
    SELECT p.oid FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public' AND p.proname = 'fetch_nearby_drivers'
  LOOP
    EXECUTE 'DROP FUNCTION ' || func_oid::regprocedure || ' CASCADE';
  END LOOP;
END $$;

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
  longitude double precision,
  distance_meters double precision
)
LANGUAGE plpgsql STABLE
AS $$
DECLARE
  user_point geography := ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326)::geography;
BEGIN
  -- 🧹 Lazy cleanup: auto-offline any driver idle > 30 minutes.
  -- Negligible cost (~0.5ms) and keeps the data clean without cron.
  PERFORM public.auto_offline_stale_drivers(30);

  RETURN QUERY
  SELECT
    d.user_id,
    u.name,
    COALESCE(v.vehicle_type, 'Mini Truck'),
    COALESCE(v.vehicle_number, 'N/A'),
    d.rating,
    d.total_trips,
    d.latitude,
    d.longitude,
    ST_Distance(d.location, user_point) AS distance_meters
  FROM public.drivers d
  INNER JOIN public.users u ON u.id = d.user_id
  LEFT  JOIN public.vehicles v ON v.user_id = d.user_id
  WHERE d.is_online = true
    AND d.is_busy   = false
    AND d.location  IS NOT NULL
    AND d.updated_at > now() - (freshness_minutes || ' minutes')::interval
    AND ST_DWithin(d.location, user_point, radius_km * 1000)
    AND (vehicle_type_filter IS NULL OR v.vehicle_type = vehicle_type_filter)
  ORDER BY d.location <-> user_point
  LIMIT max_results;
END;
$$;
GRANT EXECUTE ON FUNCTION public.fetch_nearby_drivers TO anon, authenticated;


-- ─── 3. (Optional) pg_cron schedule for true background cleanup ─────────────
-- Uncomment if you've enabled pg_cron extension in Supabase Dashboard.
-- Pros: Cleanup runs even when no one is searching.
-- Cons: Requires extension enablement.

-- CREATE EXTENSION IF NOT EXISTS pg_cron;
--
-- -- Run auto-offline every 5 minutes
-- SELECT cron.schedule(
--   'auto-offline-stale-drivers',
--   '*/5 * * * *',
--   $$ SELECT public.auto_offline_stale_drivers(30); $$
-- );


-- ─── 4. One-time cleanup of EXISTING stale data ─────────────────────────────
-- Run this once to clean up your current test data.

SELECT public.auto_offline_stale_drivers(30) AS drivers_offlined;
