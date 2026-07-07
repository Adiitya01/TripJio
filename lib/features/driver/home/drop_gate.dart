/// Pure gating logic for when the driver can tap "Complete Trip" on the
/// drop leg. Extracted from TripInProgressScreen so it can be unit-tested
/// without pulling in Flutter, Supabase, or Firebase.
///
/// Two radii + one wait window:
///   - Inside [arriveRadiusMeters]  → button unlocks immediately.
///   - Inside [softGateRadiusMeters] for [softGateWait] continuous seconds
///     → button unlocks (handles GPS jitter at indoor/underground sites).
///   - Beyond the soft radius → button stays locked; the UI shows a
///     "Drop pin wrong? Complete & flag for review" escape hatch.
library;

class DropGate {
  final double arriveRadiusMeters;
  final double softGateRadiusMeters;
  final Duration softGateWait;

  const DropGate({
    this.arriveRadiusMeters = 150,
    this.softGateRadiusMeters = 300,
    this.softGateWait = const Duration(minutes: 3),
  }) : assert(arriveRadiusMeters > 0),
       assert(softGateRadiusMeters >= arriveRadiusMeters);

  bool isAtTarget({
    required double distanceMeters,
    required DateTime? softGateStartedAt,
    required DateTime now,
  }) {
    if (distanceMeters <= arriveRadiusMeters) return true;
    if (distanceMeters > softGateRadiusMeters) return false;
    if (softGateStartedAt == null) return false;
    return now.difference(softGateStartedAt) >= softGateWait;
  }

  bool isWithinSoftRadius(double distanceMeters) =>
      distanceMeters <= softGateRadiusMeters;

  /// Should the "Drop pin wrong?" escape hatch be shown?
  /// Only on the drop leg, when we have a GPS fix, outside the soft
  /// radius (inside it the timed unlock already applies), and while not
  /// mid-submission.
  bool showFlaggedOverride({
    required bool hasReachedPickup,
    required bool hasGpsFix,
    required bool isBusy,
    required double distanceMeters,
    required DateTime? softGateStartedAt,
    required DateTime now,
  }) {
    if (!hasReachedPickup || !hasGpsFix || isBusy) return false;
    if (isAtTarget(
      distanceMeters: distanceMeters,
      softGateStartedAt: softGateStartedAt,
      now: now,
    )) {
      return false;
    }
    return !isWithinSoftRadius(distanceMeters);
  }
}
