-- ============================================================
-- TripJio — Enable Supabase Realtime on critical tables
-- Run this in Supabase SQL Editor
-- ============================================================
-- Without this, driver apps don't receive incoming request events
-- ============================================================

-- Enable realtime on requests (driver listens for new INSERTs)
ALTER PUBLICATION supabase_realtime ADD TABLE public.requests;

-- Enable realtime on trips (load owner listens for status changes)
ALTER PUBLICATION supabase_realtime ADD TABLE public.trips;

-- Enable realtime on drivers (load owner listens for location updates)
ALTER PUBLICATION supabase_realtime ADD TABLE public.drivers;

-- Verify it worked — should return 3 rows
SELECT schemaname, tablename
FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
  AND schemaname = 'public'
  AND tablename IN ('requests', 'trips', 'drivers');
