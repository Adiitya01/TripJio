-- ============================================================
-- TripJio — Performance Indexes + Nearby Drivers RPC
-- Run this in Supabase SQL Editor
-- ============================================================

-- ─── LEVEL 1: Indexes (100x faster queries) ─────────────────────────────────

-- Partial composite index for the online + geo bounding-box query
-- "WHERE is_online = true" makes it 10x smaller than a full index
CREATE INDEX IF NOT EXISTS idx_drivers_online_location
  ON public.drivers (is_online, latitude, longitude)
  WHERE is_online = true;

-- Lookup by id (already PK but explicit helps planner for IN queries)
CREATE INDEX IF NOT EXISTS idx_users_id ON public.users (id);

-- Lookup vehicles by user_id (common join)
CREATE INDEX IF NOT EXISTS idx_vehicles_user_id ON public.vehicles (user_id);

-- Requests filtered by driver_id + status (for incoming requests realtime)
CREATE INDEX IF NOT EXISTS idx_requests_driver_status
  ON public.requests (driver_id, status);

-- Requests filtered by load_owner_id + status (for active request lookup)
CREATE INDEX IF NOT EXISTS idx_requests_load_owner_status
  ON public.requests (load_owner_id, status);

-- Trips by driver_id sorted by created_at (trip history query)
CREATE INDEX IF NOT EXISTS idx_trips_driver_created
  ON public.trips (driver_id, created_at DESC);

-- Trips by load_owner_id sorted by created_at
CREATE INDEX IF NOT EXISTS idx_trips_load_owner_created
  ON public.trips (load_owner_id, created_at DESC);


-- ─── LEVEL 2: Single RPC function (1 query instead of 3) ────────────────────

CREATE OR REPLACE FUNCTION public.fetch_nearby_drivers(
  user_lat float,
  user_lng float,
  radius_km float,
  vehicle_type_filter text DEFAULT NULL,
  max_results int DEFAULT 50
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
LANGUAGE sql
STABLE
AS $$
  SELECT
    d.user_id,
    u.name,
    COALESCE(v.vehicle_type, 'Mini Truck') AS vehicle_type,
    COALESCE(v.vehicle_number, 'N/A')      AS vehicle_number,
    d.rating,
    d.total_trips,
    d.latitude,
    d.longitude
  FROM public.drivers d
  INNER JOIN public.users u ON u.id = d.user_id
  LEFT JOIN public.vehicles v ON v.user_id = d.user_id
  WHERE d.is_online = true
    AND d.latitude  IS NOT NULL
    AND d.longitude IS NOT NULL
    AND d.latitude  BETWEEN user_lat - (radius_km / 111.0) AND user_lat + (radius_km / 111.0)
    AND d.longitude BETWEEN user_lng - (radius_km / 111.0) AND user_lng + (radius_km / 111.0)
    AND (vehicle_type_filter IS NULL OR v.vehicle_type = vehicle_type_filter)
  ORDER BY
    -- approximate distance using squared-delta (avoids sqrt for speed)
    ((d.latitude  - user_lat) * (d.latitude  - user_lat) +
     (d.longitude - user_lng) * (d.longitude - user_lng)) ASC
  LIMIT max_results;
$$;

-- Grant execute permission to anon + authenticated roles
GRANT EXECUTE ON FUNCTION public.fetch_nearby_drivers TO anon, authenticated;


-- ─── Bonus: increment_driver_trips (called when trip completes) ──────────────

CREATE OR REPLACE FUNCTION public.increment_driver_trips(driver_id text)
RETURNS void
LANGUAGE sql
AS $$
  UPDATE public.drivers
  SET total_trips = total_trips + 1
  WHERE user_id = driver_id;
$$;

GRANT EXECUTE ON FUNCTION public.increment_driver_trips TO anon, authenticated;
