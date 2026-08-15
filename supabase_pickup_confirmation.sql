-- ============================================================
-- Pickup-confirmation migration
-- ============================================================
-- Adds an explicit marker for the moment the driver confirms
-- they have collected the goods at the pickup point. Used to
-- drive the load-owner UI through the second leg of the trip
-- (pickup -> drop) and to survive app kill on the driver side.
--
-- Safe to run repeatedly.
-- ============================================================

ALTER TABLE public.trips
  ADD COLUMN IF NOT EXISTS pickup_confirmed_at timestamptz;

-- Helpful index for the load-owner stream that filters on this column.
CREATE INDEX IF NOT EXISTS idx_trips_pickup_confirmed_at
  ON public.trips (pickup_confirmed_at)
  WHERE pickup_confirmed_at IS NOT NULL;
