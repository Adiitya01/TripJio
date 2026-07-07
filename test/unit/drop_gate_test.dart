import 'package:flutter_test/flutter_test.dart';
import 'package:tripjio/features/driver/home/drop_gate.dart';

void main() {
  const gate = DropGate();
  final t0 = DateTime.utc(2026, 1, 1, 12, 0, 0);

  group('DropGate.isAtTarget', () {
    test('inside hard radius unlocks immediately', () {
      expect(
        gate.isAtTarget(
          distanceMeters: 100,
          softGateStartedAt: null,
          now: t0,
        ),
        isTrue,
      );
    });

    test('exactly at hard radius (150 m) unlocks', () {
      expect(
        gate.isAtTarget(
          distanceMeters: 150,
          softGateStartedAt: null,
          now: t0,
        ),
        isTrue,
      );
    });

    test('beyond soft radius (> 300 m) stays locked even with old timer', () {
      expect(
        gate.isAtTarget(
          distanceMeters: 350,
          softGateStartedAt: t0.subtract(const Duration(minutes: 10)),
          now: t0,
        ),
        isFalse,
      );
    });

    test('inside soft radius with no timer stays locked', () {
      expect(
        gate.isAtTarget(
          distanceMeters: 250,
          softGateStartedAt: null,
          now: t0,
        ),
        isFalse,
      );
    });

    test('inside soft radius, timer under 3 min stays locked', () {
      expect(
        gate.isAtTarget(
          distanceMeters: 250,
          softGateStartedAt: t0.subtract(const Duration(seconds: 179)),
          now: t0,
        ),
        isFalse,
      );
    });

    test('inside soft radius, timer >= 3 min unlocks', () {
      expect(
        gate.isAtTarget(
          distanceMeters: 250,
          softGateStartedAt: t0.subtract(const Duration(minutes: 3)),
          now: t0,
        ),
        isTrue,
      );
    });

    test('boundary: exactly at soft radius (300 m) with timer unlocks', () {
      expect(
        gate.isAtTarget(
          distanceMeters: 300,
          softGateStartedAt: t0.subtract(const Duration(minutes: 3)),
          now: t0,
        ),
        isTrue,
      );
    });
  });

  group('DropGate.showFlaggedOverride', () {
    test('hidden on pickup leg', () {
      expect(
        gate.showFlaggedOverride(
          hasReachedPickup: false,
          hasGpsFix: true,
          isBusy: false,
          distanceMeters: 500,
          softGateStartedAt: null,
          now: t0,
        ),
        isFalse,
      );
    });

    test('hidden without a GPS fix', () {
      expect(
        gate.showFlaggedOverride(
          hasReachedPickup: true,
          hasGpsFix: false,
          isBusy: false,
          distanceMeters: 500,
          softGateStartedAt: null,
          now: t0,
        ),
        isFalse,
      );
    });

    test('hidden while a completion is submitting', () {
      expect(
        gate.showFlaggedOverride(
          hasReachedPickup: true,
          hasGpsFix: true,
          isBusy: true,
          distanceMeters: 500,
          softGateStartedAt: null,
          now: t0,
        ),
        isFalse,
      );
    });

    test('hidden inside the soft radius (timed unlock applies)', () {
      expect(
        gate.showFlaggedOverride(
          hasReachedPickup: true,
          hasGpsFix: true,
          isBusy: false,
          distanceMeters: 250,
          softGateStartedAt: null,
          now: t0,
        ),
        isFalse,
      );
    });

    test('hidden when already at target', () {
      expect(
        gate.showFlaggedOverride(
          hasReachedPickup: true,
          hasGpsFix: true,
          isBusy: false,
          distanceMeters: 100,
          softGateStartedAt: null,
          now: t0,
        ),
        isFalse,
      );
    });

    test('shown when far outside soft radius with GPS fix', () {
      expect(
        gate.showFlaggedOverride(
          hasReachedPickup: true,
          hasGpsFix: true,
          isBusy: false,
          distanceMeters: 500,
          softGateStartedAt: null,
          now: t0,
        ),
        isTrue,
      );
    });
  });

  group('DropGate.isWithinSoftRadius', () {
    test('inside', () => expect(gate.isWithinSoftRadius(299), isTrue));
    test('at boundary', () => expect(gate.isWithinSoftRadius(300), isTrue));
    test('outside', () => expect(gate.isWithinSoftRadius(301), isFalse));
  });
}
