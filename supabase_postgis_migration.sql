-- ============================================================
-- TripJio — PostGIS Migration
-- Run this AFTER all previous SQL files
-- ============================================================
-- Why: Replaces the bounding-box-then-Haversine approach with
-- true spherical geometry. ~10x faster, no edge cases at poles
-- or 180° meridian. Uses GIST spatial index.
-- ============================================================

-- ─── 1. Enable PostGIS extension ────────────────────────────────────────────

CREATE EXTENSION IF NOT EXISTS postgis;


-- ─── 2. Add location column to drivers table ────────────────────────────────
-- Uses 'geography' (not 'geometry') so distance math is in meters on the
-- actual Earth sphere — no flat-projection errors.

ALTER TABLE public.drivers
  ADD COLUMN IF NOT EXISTS location geography(POINT, 4326);

-- Backfill from existing latitude/longitude
UPDATE public.drivers
  SET location = ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography
  WHERE latitude IS NOT NULL
    AND longitude IS NOT NULL
    AND location IS NULL;

-- GIST spatial index — the magic that makes proximity queries O(log n)
CREATE INDEX IF NOT EXISTS idx_drivers_location_gist
  ON public.drivers USING GIST (location);


-- ─── 3. Auto-update trigger ─────────────────────────────────────────────────
-- Whenever latitude/longitude changes, recompute the location point.
-- Keeps the geography column always in sync with lat/lng.

CREATE OR REPLACE FUNCTION public.sync_driver_location()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.latitude IS NOT NULL AND NEW.longitude IS NOT NULL THEN
    NEW.location = ST_SetSRID(
      ST_MakePoint(NEW.longitude, NEW.latitude), 4326
    )::geography;
  ELSE
    NEW.location = NULL;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_driver_location ON public.drivers;
CREATE TRIGGER trg_sync_driver_location
  BEFORE INSERT OR UPDATE OF latitude, longitude ON public.drivers
  FOR EACH ROW EXECUTE FUNCTION public.sync_driver_location();


-- ─── 4. Drop old fetch_nearby_drivers RPCs (avoid signature conflicts) ──────

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


-- ─── 5. New PostGIS-powered fetch_nearby_drivers ────────────────────────────

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
  user_point geography := ST_SetSRID(
    ST_MakePoint(user_lng, user_lat), 4326
  )::geography;
BEGIN
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
    -- Real spherical distance in meters
    ST_Distance(d.location, user_point) AS distance_meters
  FROM public.drivers d
  INNER JOIN public.users u ON u.id = d.user_id
  LEFT  JOIN public.vehicles v ON v.user_id = d.user_id
  WHERE d.is_online = true
    AND d.is_busy = false
    AND d.location IS NOT NULL
    AND d.updated_at > now() - (freshness_minutes || ' minutes')::interval
    -- ⭐ The PostGIS magic — uses GIST index, sub-millisecond
    AND ST_DWithin(d.location, user_point, radius_km * 1000)
    AND (vehicle_type_filter IS NULL OR v.vehicle_type = vehicle_type_filter)
  ORDER BY d.location <-> user_point   -- KNN distance operator, index-accelerated
  LIMIT max_results;
END;
$$;
GRANT EXECUTE ON FUNCTION public.fetch_nearby_drivers TO anon, authenticated;


-- ─── 6. Verify it works (optional debug query) ──────────────────────────────
-- After running this file, you can test with:
-- SELECT * FROM fetch_nearby_drivers(18.5204, 73.8567, 10, NULL, 5, 3);


-- ─── Notes ──────────────────────────────────────────────────────────────────
-- 1. The geography type stores points as (longitude, latitude) — note the order!
-- 2. SRID 4326 = WGS 84, the standard GPS coordinate system.
-- 3. ST_DWithin uses meters when applied to geography type.
-- 4. The <-> operator is KNN-aware — uses the GIST index for ORDER BY.
-- 5. ST_Distance also returns meters for geography type.
