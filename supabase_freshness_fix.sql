-- ============================================================
-- TripJio — Driver Freshness Fix
-- Only show drivers whose location was updated in last 5 minutes
-- ============================================================

-- Replace the existing RPC with a freshness-aware version
CREATE OR REPLACE FUNCTION public.fetch_nearby_drivers(
  user_lat float,
  user_lng float,
  radius_km float,
  vehicle_type_filter text DEFAULT NULL,
  max_results int DEFAULT 50,
  freshness_minutes int DEFAULT 5
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
    -- ⭐ Freshness check: location updated within last N minutes
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

-- Add index on updated_at for fast freshness check
CREATE INDEX IF NOT EXISTS idx_drivers_updated_at
  ON public.drivers (updated_at DESC)
  WHERE is_online = true;
