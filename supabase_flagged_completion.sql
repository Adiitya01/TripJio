-- ============================================================
-- Flagged-completion migration
-- ============================================================
-- Manual override for the drop-radius gate: when the pinned drop
-- location is wrong (or the compound is larger than 300m), the
-- driver can still complete the trip, but it is flagged for
-- review and the driver's actual position + distance from the
-- pin are recorded for the back office.
--
-- Safe to run repeatedly.
--
-- NOTE: supabase_auth_hardening.sql (run LAST) re-creates
-- complete_trip_flagged as SECURITY DEFINER and derives the caller
-- from the verified Firebase token. That is the authoritative
-- version; the definition here is the interim standalone one.
-- ============================================================

ALTER TABLE public.trips
  ADD COLUMN IF NOT EXISTS completion_flagged boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS completion_lat double precision,
  ADD COLUMN IF NOT EXISTS completion_lng double precision,
  ADD COLUMN IF NOT EXISTS completion_distance_m double precision;

-- Back-office review queue: flagged completions, newest first.
CREATE INDEX IF NOT EXISTS idx_trips_completion_flagged
  ON public.trips (completed_at DESC)
  WHERE completion_flagged = true;

CREATE OR REPLACE FUNCTION public.complete_trip_flagged(
  p_trip_id uuid,
  p_caller_id text,
  p_lat double precision,
  p_lng double precision,
  p_distance_m double precision
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_driver_id text;
  v_status text;
BEGIN
  SELECT driver_id, status INTO v_driver_id, v_status
    FROM public.trips WHERE id = p_trip_id;

  IF v_driver_id IS NULL THEN
    RAISE EXCEPTION 'Trip not found';
  END IF;

  -- Unlike complete_trip, the flagged override is driver-only and the
  -- caller id is mandatory.
  IF p_caller_id IS NULL OR p_caller_id != v_driver_id THEN
    RAISE EXCEPTION 'Not authorized to complete this trip';
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
    SET completion_flagged    = true,
        completion_lat        = p_lat,
        completion_lng        = p_lng,
        completion_distance_m = p_distance_m
    WHERE id = p_trip_id;

  PERFORM public.complete_trip(p_trip_id, p_caller_id);
END;
$$;
GRANT EXECUTE ON FUNCTION public.complete_trip_flagged TO anon, authenticated;
