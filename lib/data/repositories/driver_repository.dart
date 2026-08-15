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

/// Signup-time driver details shown in the profile screen.
class DriverDetails {
  final String licenseNumber;
  final String experience;
  final double rating;
  final int totalTrips;
  final bool isOnline;
  final String? vehicleId;
  final String? vehicleNumber;
  final String? vehicleType;

  const DriverDetails({
    required this.licenseNumber,
    required this.experience,
    required this.rating,
    required this.totalTrips,
    required this.isOnline,
    this.vehicleId,
    this.vehicleNumber,
    this.vehicleType,
  });
}

/// Display-only driver record used by LiveTracking / DriverArrived /
/// TripCompleted screens. Exposes the four fields those screens read on
/// the dynamic `driver` argument (name, phone, vehicle, number).
class DriverProfile {
  final String userId;
  final String name;
  final String phone;
  final String vehicle;
  final String number;

  const DriverProfile({
    required this.userId,
    required this.name,
    required this.phone,
    required this.vehicle,
    required this.number,
  });
}

class DriverRepository {
  final SupabaseClient _client = SupabaseService.client;

  /// Fetch online drivers within [radiusKm] using PostGIS.
  /// Backed by a GIST spatial index — sub-millisecond at million-row scale.
  /// Distance comes pre-computed from PostGIS (real spherical math).
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
      // PostGIS returns distance in meters — no Dart re-computation needed
      final distMeters =
          (row['distance_meters'] as num?)?.toDouble() ?? 0.0;
      final distKm = distMeters / 1000;

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

    // Already sorted by DB using KNN (<->) operator
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

  /// Look up a driver's display profile by user id.
  /// Used when we have a driverId (e.g. from an active TripModel during
  /// resume) and need to populate the live-tracking UI without re-running
  /// the nearby-drivers RPC.
  Future<DriverProfile?> getDriverProfile(String driverId) async {
    final user = await _client
        .from('users')
        .select('id, name, phone')
        .eq('id', driverId)
        .maybeSingle();
    if (user == null) return null;

    final vehicle = await _client
        .from('vehicles')
        .select('vehicle_type, vehicle_number')
        .eq('user_id', driverId)
        .maybeSingle();

    return DriverProfile(
      userId: user['id'] as String,
      name: (user['name'] as String?) ?? 'Driver',
      phone: (user['phone'] as String?) ?? '',
      vehicle: (vehicle?['vehicle_type'] as String?) ?? '',
      number: (vehicle?['vehicle_number'] as String?) ?? '',
    );
  }

  /// Fetch the driver's signup-time details for display in the profile
  /// screen (license, experience, rating, total trips, vehicle).
  Future<DriverDetails?> getDriverDetails(String driverId) async {
    final driverRow = await _client
        .from('drivers')
        .select(
            'license_number, experience, rating, total_trips, is_online')
        .eq('user_id', driverId)
        .maybeSingle();
    if (driverRow == null) return null;
    final vehicleRow = await _client
        .from('vehicles')
        .select('id, vehicle_number, vehicle_type')
        .eq('user_id', driverId)
        .maybeSingle();
    return DriverDetails(
      licenseNumber: (driverRow['license_number'] as String?) ?? '',
      experience: (driverRow['experience'] as String?) ?? '',
      rating: (driverRow['rating'] as num?)?.toDouble() ?? 0.0,
      totalTrips: (driverRow['total_trips'] as num?)?.toInt() ?? 0,
      isOnline: (driverRow['is_online'] as bool?) ?? false,
      vehicleId: vehicleRow?['id'] as String?,
      vehicleNumber: vehicleRow?['vehicle_number'] as String?,
      vehicleType: vehicleRow?['vehicle_type'] as String?,
    );
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
