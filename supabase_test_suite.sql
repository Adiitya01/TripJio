-- ============================================================
-- TripJio — Complete Edge Case Test Suite
-- ============================================================
-- Tests every RPC, validation rule, and edge case.
-- Runs in a transaction → AUTOMATIC ROLLBACK at the end.
-- Nothing persists to your database.
--
-- HOW TO RUN:
--   1. Open Supabase SQL Editor
--   2. Paste this entire file
--   3. Click Run
--   4. Read the NOTICE messages — each should say "PASS"
--   5. Any FAIL message indicates a real bug
-- ============================================================

BEGIN;  -- 🛡️ everything below rolls back on completion

-- Track pass/fail
CREATE TEMP TABLE test_results (
  test_name text,
  status text,
  details text
);

-- Helper: assert_eq
CREATE OR REPLACE FUNCTION pg_temp.assert_eq(
  test_name text, expected anyelement, actual anyelement
) RETURNS void AS $$
BEGIN
  IF expected IS NOT DISTINCT FROM actual THEN
    INSERT INTO test_results VALUES (test_name, 'PASS', NULL);
    RAISE NOTICE '✅ PASS: %', test_name;
  ELSE
    INSERT INTO test_results VALUES (test_name, 'FAIL',
      format('expected=%s actual=%s', expected, actual));
    RAISE NOTICE '❌ FAIL: % — expected=% actual=%', test_name, expected, actual;
  END IF;
END $$ LANGUAGE plpgsql;

-- Helper: assert_throws
CREATE OR REPLACE FUNCTION pg_temp.assert_throws(
  test_name text, sql_to_run text, expected_msg text
) RETURNS void AS $$
DECLARE
  err_msg text;
BEGIN
  BEGIN
    EXECUTE sql_to_run;
    INSERT INTO test_results VALUES (test_name, 'FAIL', 'expected exception not thrown');
    RAISE NOTICE '❌ FAIL: % — expected exception not thrown', test_name;
  EXCEPTION WHEN OTHERS THEN
    err_msg := SQLERRM;
    IF err_msg ILIKE '%' || expected_msg || '%' THEN
      INSERT INTO test_results VALUES (test_name, 'PASS', err_msg);
      RAISE NOTICE '✅ PASS: % — got expected error: %', test_name, err_msg;
    ELSE
      INSERT INTO test_results VALUES (test_name, 'FAIL',
        format('wrong error: %s', err_msg));
      RAISE NOTICE '❌ FAIL: % — wrong error: %', test_name, err_msg;
    END IF;
  END;
END $$ LANGUAGE plpgsql;


-- ╔═══════════════════════════════════════════════════════════╗
-- ║  SETUP — Test fixtures                                     ║
-- ╚═══════════════════════════════════════════════════════════╝

-- Test users
INSERT INTO public.users (id, phone, name, user_type, created_at) VALUES
  ('test_driver_1',     '+919999900001', 'Test Driver 1',     'driver',     now()),
  ('test_driver_2',     '+919999900002', 'Test Driver 2',     'driver',     now()),
  ('test_driver_stale', '+919999900003', 'Test Driver Stale', 'driver',     now()),
  ('test_owner_1',      '+919999900004', 'Test Owner 1',      'load_owner', now()),
  ('test_owner_2',      '+919999900005', 'Test Owner 2',      'load_owner', now());

-- Test drivers (lat/lng in Pune)
INSERT INTO public.drivers (user_id, license_number, experience, is_online, is_busy, latitude, longitude, updated_at) VALUES
  ('test_driver_1',     'MH14-TEST001', '3-5 years', true,  false, 18.5204, 73.8567, now()),
  ('test_driver_2',     'MH14-TEST002', '5+ years',  true,  false, 18.5304, 73.8667, now()),
  ('test_driver_stale', 'MH14-TEST003', '1-2 years', true,  false, 18.5404, 73.8767, now() - interval '1 hour');

-- Test vehicles
INSERT INTO public.vehicles (id, user_id, vehicle_number, vehicle_type, created_at) VALUES
  ('veh_test_1', 'test_driver_1',     'MH14TEST001', 'Mini Truck', now()),
  ('veh_test_2', 'test_driver_2',     'MH14TEST002', 'LCV',        now()),
  ('veh_test_3', 'test_driver_stale', 'MH14TEST003', 'HCV',        now());


-- ╔═══════════════════════════════════════════════════════════╗
-- ║  1. DISTANCE & FETCH NEARBY DRIVERS                        ║
-- ╚═══════════════════════════════════════════════════════════╝

DO $$
DECLARE
  v_count int;
BEGIN
  -- 1.1: Fresh drivers within radius show up
  SELECT count(*) INTO v_count FROM public.fetch_nearby_drivers(18.5204, 73.8567, 10);
  PERFORM pg_temp.assert_eq('1.1 nearby drivers found', true, v_count >= 2);

  -- 1.2: Stale driver (>3 min old) is hidden
  SELECT count(*) INTO v_count FROM public.fetch_nearby_drivers(18.5204, 73.8567, 10)
    WHERE user_id = 'test_driver_stale';
  PERFORM pg_temp.assert_eq('1.2 stale driver hidden from search', 0, v_count);

  -- 1.3: Vehicle type filter works
  SELECT count(*) INTO v_count FROM public.fetch_nearby_drivers(18.5204, 73.8567, 10, 'LCV');
  PERFORM pg_temp.assert_eq('1.3 LCV filter returns only LCV', 1, v_count);

  -- 1.4: Tiny radius excludes far drivers
  SELECT count(*) INTO v_count FROM public.fetch_nearby_drivers(18.5204, 73.8567, 0.1);
  PERFORM pg_temp.assert_eq('1.4 tiny radius excludes far drivers', 1, v_count);
END $$;


-- ╔═══════════════════════════════════════════════════════════╗
-- ║  2. INPUT VALIDATION (create_request_safe)                 ║
-- ╚═══════════════════════════════════════════════════════════╝

-- 2.1: Negative weight rejected
SELECT pg_temp.assert_throws('2.1 negative weight rejected',
  $sql$ SELECT public.create_request_safe(
    'test_owner_1', 'test_driver_1', 'Pickup', 'Drop',
    18.52, 73.85, 18.55, 73.88, NULL, -100
  ) $sql$,
  'Weight must be'
);

-- 2.2: Excessive weight rejected
SELECT pg_temp.assert_throws('2.2 weight > 50000kg rejected',
  $sql$ SELECT public.create_request_safe(
    'test_owner_1', 'test_driver_1', 'Pickup', 'Drop',
    18.52, 73.85, 18.55, 73.88, NULL, 999999
  ) $sql$,
  'Weight must be'
);

-- 2.3: Address too long rejected
SELECT pg_temp.assert_throws('2.3 address > 500 chars rejected',
  format($sql$ SELECT public.create_request_safe(
    'test_owner_1', 'test_driver_1', %L, 'Drop',
    18.52, 73.85, 18.55, 73.88
  ) $sql$, repeat('x', 600)),
  'Invalid pickup address'
);

-- 2.4: Empty pickup address rejected
SELECT pg_temp.assert_throws('2.4 empty pickup address rejected',
  $sql$ SELECT public.create_request_safe(
    'test_owner_1', 'test_driver_1', '', 'Drop',
    18.52, 73.85, 18.55, 73.88
  ) $sql$,
  'Invalid pickup address'
);

-- 2.5: Invalid coordinates rejected
SELECT pg_temp.assert_throws('2.5 invalid latitude (>90) rejected',
  $sql$ SELECT public.create_request_safe(
    'test_owner_1', 'test_driver_1', 'Pickup', 'Drop',
    95.0, 73.85, 18.55, 73.88
  ) $sql$,
  'Invalid pickup coordinates'
);

-- 2.6: Request to unavailable driver rejected
SELECT pg_temp.assert_throws('2.6 request to offline driver rejected',
  $sql$ SELECT public.create_request_safe(
    'test_owner_1', 'test_driver_stale', 'Pickup', 'Drop',
    18.52, 73.85, 18.55, 73.88
  ) $sql$,
  'Driver is not available'
);


-- ╔═══════════════════════════════════════════════════════════╗
-- ║  3. RATE LIMITING                                          ║
-- ╚═══════════════════════════════════════════════════════════╝

DO $$
DECLARE
  v_allowed boolean;
  v_pass_count int := 0;
  v_block_count int := 0;
BEGIN
  -- Reset rate limit for clean test
  DELETE FROM public.rate_limits WHERE user_id = 'test_owner_2';

  -- Try 12 actions (limit is 10)
  FOR i IN 1..12 LOOP
    SELECT public.check_rate_limit('test_owner_2', 'test_action', 10, 60) INTO v_allowed;
    IF v_allowed THEN v_pass_count := v_pass_count + 1;
    ELSE v_block_count := v_block_count + 1;
    END IF;
  END LOOP;

  PERFORM pg_temp.assert_eq('3.1 first 10 requests allowed', 10, v_pass_count);
  PERFORM pg_temp.assert_eq('3.2 11th and 12th blocked',     2,  v_block_count);
END $$;


-- ╔═══════════════════════════════════════════════════════════╗
-- ║  4. ATOMIC ACCEPT (race conditions)                        ║
-- ╚═══════════════════════════════════════════════════════════╝

DO $$
DECLARE
  v_request public.requests;
  v_trip_id uuid;
  v_driver_busy boolean;
BEGIN
  -- 4.1: Create a request
  SELECT * INTO v_request FROM public.create_request_safe(
    'test_owner_1', 'test_driver_1', 'Test Pickup', 'Test Drop',
    18.52, 73.85, 18.55, 73.88, 'Test goods', 500
  );
  PERFORM pg_temp.assert_eq('4.1 request created with pending status', 'pending', v_request.status);

  -- 4.2: Driver accepts atomically → trip created + driver busy
  v_trip_id := public.accept_request_and_create_trip(v_request.id);
  PERFORM pg_temp.assert_eq('4.2 accept returns trip_id', true, v_trip_id IS NOT NULL);

  -- Verify driver is now busy
  SELECT is_busy INTO v_driver_busy FROM public.drivers WHERE user_id = 'test_driver_1';
  PERFORM pg_temp.assert_eq('4.3 driver marked busy after accept', true, v_driver_busy);

  -- 4.4: Second accept on same request fails
  PERFORM pg_temp.assert_throws('4.4 double accept blocked',
    format($sql$ SELECT public.accept_request_and_create_trip(%L) $sql$, v_request.id),
    'no longer pending'
  );

  -- 4.5: Busy driver hidden from nearby search
  PERFORM pg_temp.assert_eq('4.5 busy driver hidden from nearby search', 0,
    (SELECT count(*) FROM public.fetch_nearby_drivers(18.5204, 73.8567, 10)
     WHERE user_id = 'test_driver_1'));
END $$;


-- ╔═══════════════════════════════════════════════════════════╗
-- ║  5. CANCEL RACE (load owner vs driver)                     ║
-- ╚═══════════════════════════════════════════════════════════╝

DO $$
DECLARE
  v_request public.requests;
  v_result text;
BEGIN
  -- 5.1: Create new request
  SELECT * INTO v_request FROM public.create_request_safe(
    'test_owner_1', 'test_driver_2', 'Pickup', 'Drop',
    18.52, 73.85, 18.55, 73.88
  );

  -- 5.2: Wrong user trying to cancel → blocked
  PERFORM pg_temp.assert_throws('5.1 unauthorized cancel blocked',
    format($sql$ SELECT public.cancel_request_safe(%L, %L) $sql$,
      v_request.id, 'test_driver_1'),
    'Not authorized'
  );

  -- 5.3: Correct user cancels → succeeds
  v_result := public.cancel_request_safe(v_request.id, 'test_owner_1');
  PERFORM pg_temp.assert_eq('5.2 valid cancel succeeds', 'cancelled', v_result);

  -- 5.4: Cancelling an already-accepted request → blocked
  DECLARE
    v_request2 public.requests;
  BEGIN
    SELECT * INTO v_request2 FROM public.create_request_safe(
      'test_owner_1', 'test_driver_2', 'Pickup', 'Drop',
      18.52, 73.85, 18.55, 73.88
    );
    PERFORM public.accept_request_and_create_trip(v_request2.id);

    PERFORM pg_temp.assert_throws('5.3 cancel after accept blocked',
      format($sql$ SELECT public.cancel_request_safe(%L, %L) $sql$,
        v_request2.id, 'test_owner_1'),
      'already accepted'
    );
  END;
END $$;


-- ╔═══════════════════════════════════════════════════════════╗
-- ║  6. TRIP COMPLETION & AUTHORIZATION                        ║
-- ╚═══════════════════════════════════════════════════════════╝

DO $$
DECLARE
  v_request public.requests;
  v_trip_id uuid;
  v_total_trips_before int;
  v_total_trips_after int;
BEGIN
  -- Setup: need a driver who's not busy
  UPDATE public.drivers SET is_busy = false, is_online = true, updated_at = now()
    WHERE user_id = 'test_driver_1';

  -- 6.1: Create + accept new trip
  SELECT * INTO v_request FROM public.create_request_safe(
    'test_owner_1', 'test_driver_1', 'Pickup', 'Drop',
    18.52, 73.85, 18.55, 73.88
  );
  v_trip_id := public.accept_request_and_create_trip(v_request.id);

  SELECT total_trips INTO v_total_trips_before FROM public.drivers WHERE user_id = 'test_driver_1';

  -- 6.2: Unauthorized user trying to complete → blocked
  PERFORM pg_temp.assert_throws('6.1 unauthorized complete blocked',
    format($sql$ SELECT public.complete_trip(%L, %L) $sql$,
      v_trip_id, 'test_owner_2'),
    'Not authorized'
  );

  -- 6.3: Authorized complete succeeds
  PERFORM public.complete_trip(v_trip_id, 'test_driver_1');

  -- 6.4: Driver is_busy = false after complete
  PERFORM pg_temp.assert_eq('6.2 driver free after complete', false,
    (SELECT is_busy FROM public.drivers WHERE user_id = 'test_driver_1'));

  -- 6.5: total_trips incremented
  SELECT total_trips INTO v_total_trips_after FROM public.drivers WHERE user_id = 'test_driver_1';
  PERFORM pg_temp.assert_eq('6.3 total_trips incremented', v_total_trips_before + 1, v_total_trips_after);
END $$;


-- ╔═══════════════════════════════════════════════════════════╗
-- ║  7. AUTO-OFFLINE STALE DRIVERS                             ║
-- ╚═══════════════════════════════════════════════════════════╝

DO $$
DECLARE
  v_offlined int;
  v_still_online boolean;
BEGIN
  -- Reset driver_2 to a stale state (> 30 min)
  UPDATE public.drivers
    SET is_online = true, is_busy = false, updated_at = now() - interval '45 minutes'
    WHERE user_id = 'test_driver_2';

  -- 7.1: auto_offline_stale_drivers should offline them
  SELECT public.auto_offline_stale_drivers(30) INTO v_offlined;
  PERFORM pg_temp.assert_eq('7.1 auto-offlined at least 1 stale driver', true, v_offlined >= 1);

  -- 7.2: Driver 2 now is_online = false
  SELECT is_online INTO v_still_online FROM public.drivers WHERE user_id = 'test_driver_2';
  PERFORM pg_temp.assert_eq('7.2 stale driver set offline', false, v_still_online);

  -- 7.3: Busy drivers protected from auto-offline (even if stale)
  UPDATE public.drivers
    SET is_online = true, is_busy = true, updated_at = now() - interval '45 minutes'
    WHERE user_id = 'test_driver_1';

  PERFORM public.auto_offline_stale_drivers(30);

  PERFORM pg_temp.assert_eq('7.3 busy driver protected from auto-offline', true,
    (SELECT is_online FROM public.drivers WHERE user_id = 'test_driver_1'));
END $$;


-- ╔═══════════════════════════════════════════════════════════╗
-- ║  8. SESSION MANAGEMENT (multi-device)                      ║
-- ╚═══════════════════════════════════════════════════════════╝

DO $$
DECLARE
  v_result text;
  v_valid boolean;
BEGIN
  -- 8.1: First device registers
  v_result := public.register_session('test_driver_1', 'device_phone_a', 'fcm_token_a');
  PERFORM pg_temp.assert_eq('8.1 first session is "new"', 'new', v_result);

  -- 8.2: Same device re-registers
  v_result := public.register_session('test_driver_1', 'device_phone_a', 'fcm_token_a');
  PERFORM pg_temp.assert_eq('8.2 same device re-register is "same"', 'same', v_result);

  -- 8.3: Different device takes over
  v_result := public.register_session('test_driver_1', 'device_phone_b', 'fcm_token_b');
  PERFORM pg_temp.assert_eq('8.3 different device is "replaced"', 'replaced', v_result);

  -- 8.4: Old device's session no longer valid
  v_valid := public.is_session_valid('test_driver_1', 'device_phone_a');
  PERFORM pg_temp.assert_eq('8.4 old device session invalid', false, v_valid);

  -- 8.5: New device's session is valid
  v_valid := public.is_session_valid('test_driver_1', 'device_phone_b');
  PERFORM pg_temp.assert_eq('8.5 new device session valid', true, v_valid);
END $$;


-- ╔═══════════════════════════════════════════════════════════╗
-- ║  9. ONLINE TOGGLE — BLOCKED MID-TRIP                       ║
-- ╚═══════════════════════════════════════════════════════════╝

DO $$
DECLARE
  v_request public.requests;
  v_trip_id uuid;
  v_result text;
BEGIN
  -- Set up driver with active trip
  UPDATE public.drivers SET is_busy = false, is_online = true, updated_at = now()
    WHERE user_id = 'test_driver_1';

  SELECT * INTO v_request FROM public.create_request_safe(
    'test_owner_1', 'test_driver_1', 'Pickup', 'Drop',
    18.52, 73.85, 18.55, 73.88
  );
  v_trip_id := public.accept_request_and_create_trip(v_request.id);

  -- 9.1: Try to go offline mid-trip → blocked
  v_result := public.set_driver_online_safe('test_driver_1', false);
  PERFORM pg_temp.assert_eq('9.1 cannot go offline mid-trip', 'blocked_active_trip', v_result);

  -- 9.2: Driver still online
  PERFORM pg_temp.assert_eq('9.2 driver still online after blocked toggle', true,
    (SELECT is_online FROM public.drivers WHERE user_id = 'test_driver_1'));

  -- Complete the trip
  PERFORM public.complete_trip(v_trip_id, 'test_driver_1');

  -- 9.3: After trip, can go offline
  v_result := public.set_driver_online_safe('test_driver_1', false);
  PERFORM pg_temp.assert_eq('9.3 can go offline after trip complete', 'ok', v_result);
END $$;


-- ╔═══════════════════════════════════════════════════════════╗
-- ║  10. POSTGIS DISTANCE ACCURACY                             ║
-- ╚═══════════════════════════════════════════════════════════╝

DO $$
DECLARE
  v_distance double precision;
BEGIN
  -- Reset driver to known location
  UPDATE public.drivers
    SET latitude = 18.5204, longitude = 73.8567, is_online = true, is_busy = false, updated_at = now()
    WHERE user_id = 'test_driver_1';

  -- Distance from (18.5204, 73.8567) to (18.5304, 73.8667) ≈ 1.4 km
  SELECT distance_meters INTO v_distance FROM public.fetch_nearby_drivers(18.5304, 73.8667, 10)
    WHERE user_id = 'test_driver_1';

  PERFORM pg_temp.assert_eq('10.1 PostGIS distance roughly 1.4 km',
    true, v_distance BETWEEN 1000 AND 2000);
END $$;


-- ╔═══════════════════════════════════════════════════════════╗
-- ║  TEST SUMMARY                                              ║
-- ╚═══════════════════════════════════════════════════════════╝

SELECT
  count(*) FILTER (WHERE status = 'PASS') AS passed,
  count(*) FILTER (WHERE status = 'FAIL') AS failed,
  count(*) AS total,
  round(100.0 * count(*) FILTER (WHERE status = 'PASS') / count(*), 1) || '%' AS pass_rate
FROM test_results;

-- Show failed tests (if any)
SELECT test_name, details FROM test_results WHERE status = 'FAIL';

-- ⛔ Roll back everything so the test data doesn't persist
ROLLBACK;
