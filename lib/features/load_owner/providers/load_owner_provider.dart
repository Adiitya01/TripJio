import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/location_repository.dart';
import '../../../data/repositories/driver_repository.dart';
import '../../../data/repositories/request_repository.dart';
import '../../../data/repositories/trip_repository.dart';
import '../../../data/models/request_model.dart';
import '../../../data/models/trip_model.dart';

// ─── Map / filter state ───────────────────────────────────────────────────────

final vehicleTypeFilterProvider = StateProvider<int>((ref) => 0);
final selectedTruckPinProvider = StateProvider<int?>((ref) => null);
final trackedDriverIdProvider = StateProvider<String?>((ref) => null);

// ─── User's current location ──────────────────────────────────────────────────

final userLocationProvider =
    StateProvider<({double lat, double lng})?>((_) => null);

// ─── Nearby drivers from Supabase ─────────────────────────────────────────────

final nearbyDriversProvider =
    FutureProvider.family<List<NearbyDriver>, ({double lat, double lng})>(
        (ref, location) async {
  final filterIndex = ref.watch(vehicleTypeFilterProvider);
  final typeFilter = _vehicleTypeFromIndex(filterIndex);
  return DriverRepository().fetchNearbyDrivers(
    lat: location.lat,
    lng: location.lng,
    radiusKm: 10.0,
    vehicleTypeFilter: typeFilter,
  );
});

String? _vehicleTypeFromIndex(int index) {
  switch (index) {
    case 1:
      return 'Mini Truck';
    case 2:
      return 'LCV';
    case 3:
      return 'HCV';
    default:
      return null;
  }
}

// ─── Supabase Realtime driver location stream ─────────────────────────────────

final driverRealtimeLocationProvider =
    StreamProvider.family<Map<String, dynamic>, String>((ref, driverId) {
  return LocationRepository().listenToDriverLocation(driverId);
});

// ─── Active request ───────────────────────────────────────────────────────────

final activeRequestProvider =
    StateProvider<RequestModel?>((ref) => null);

final requestStatusStreamProvider =
    StreamProvider.family<RequestModel, String>((ref, requestId) {
  return RequestRepository().listenToRequestStatus(requestId);
});

// ─── Active trip ──────────────────────────────────────────────────────────────

final activeTripProvider = StateProvider<TripModel?>((ref) => null);

final tripStatusStreamProvider =
    StreamProvider.family<TripModel, String>((ref, tripId) {
  return TripRepository().listenToTrip(tripId);
});
