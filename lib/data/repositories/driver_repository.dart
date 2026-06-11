import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/distance_service.dart';

class NearbyDriver {
  final String userId;
  final String name;
  final String vehicleType;
  final String vehicleNumber;
  final String capacity;
  final double rating;
  final int totalTrips;
  final double latitude;
  final double longitude;
  final double distanceKm;
  final String etaLabel;

  const NearbyDriver({
    required this.userId,
    required this.name,
    required this.vehicleType,
    required this.vehicleNumber,
    required this.capacity,
    required this.rating,
    required this.totalTrips,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
    required this.etaLabel,
  });
}

class DriverRepository {
  final SupabaseClient _client = SupabaseService.client;

  /// Fetch online drivers within [radiusKm] of the given location.
  /// Uses a single Postgres RPC (fetch_nearby_drivers) — backed by a
  /// partial composite index on (is_online, latitude, longitude).
  /// Sub-10ms even with 100k+ drivers in the table.
  Future<List<NearbyDriver>> fetchNearbyDrivers({
    required double lat,
    required double lng,
    double radiusKm = 10.0,
    String? vehicleTypeFilter,
    int maxResults = 50,
  }) async {
    final response = await _client.rpc(
      'fetch_nearby_drivers',
      params: {
        'user_lat': lat,
        'user_lng': lng,
        'radius_km': radiusKm,
        'vehicle_type_filter': vehicleTypeFilter,
        'max_results': maxResults,
      },
    );

    final rows = (response as List).cast<Map<String, dynamic>>();
    final List<NearbyDriver> drivers = [];

    for (final row in rows) {
      final driverLat = (row['latitude'] as num).toDouble();
      final driverLng = (row['longitude'] as num).toDouble();
      final distKm =
          DistanceService.distanceInKm(lat, lng, driverLat, driverLng);

      // The bounding box is square, exact filter ensures circular radius
      if (distKm > radiusKm) continue;

      final vType = row['vehicle_type'] as String? ?? 'Mini Truck';

      drivers.add(NearbyDriver(
        userId: row['user_id'] as String,
        name: row['name'] as String? ?? 'Driver',
        vehicleType: vType,
        vehicleNumber: row['vehicle_number'] as String? ?? 'N/A',
        capacity: _capacityFor(vType),
        rating: (row['rating'] as num?)?.toDouble() ?? 0.0,
        totalTrips: row['total_trips'] as int? ?? 0,
        latitude: driverLat,
        longitude: driverLng,
        distanceKm: distKm,
        etaLabel: DistanceService.etaLabel(distKm),
      ));
    }

    drivers.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return drivers;
  }

  /// Update driver online status — uses safe RPC that blocks going offline
  /// while a trip is active. Returns 'ok' or 'blocked_active_trip'.
  Future<String> setOnlineStatus(String driverId,
      {required bool online}) async {
    final result = await _client.rpc('set_driver_online_safe', params: {
      'p_user_id': driverId,
      'p_online': online,
    });
    return result as String;
  }

  /// Fetch driver's full state (online flag, active trip, last GPS) —
  /// used on app cold-start to restore previous session.
  Future<Map<String, dynamic>?> getDriverState(String driverId) async {
    final response =
        await _client.rpc('get_driver_state', params: {'p_user_id': driverId});
    final list = response as List;
    if (list.isEmpty) return null;
    return list.first as Map<String, dynamic>;
  }

  static String _capacityFor(String vehicleType) {
    switch (vehicleType) {
      case 'Mini Truck':
        return '800 kg';
      case 'LCV':
        return '1200 kg';
      case 'HCV':
        return '2500 kg';
      case 'Container':
        return '10000 kg';
      default:
        return 'N/A';
    }
  }
}
