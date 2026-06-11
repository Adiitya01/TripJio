import 'dart:math' as math;

class DistanceService {
  static const double _earthRadius = 6371000; // metres

  // ─── Haversine distance ────────────────────────────────────────────────────

  /// Returns distance in metres between two lat/lng points.
  static double distanceInMeters(
      double lat1, double lng1, double lat2, double lng2) {
    final dLat = _deg2rad(lat2 - lat1);
    final dLng = _deg2rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return _earthRadius * c;
  }

  /// Returns distance in km (2 decimal places).
  static double distanceInKm(
          double lat1, double lng1, double lat2, double lng2) =>
      distanceInMeters(lat1, lng1, lat2, lng2) / 1000;

  // ─── ETA calculation ───────────────────────────────────────────────────────

  /// Returns ETA in minutes based on distance and assumed city speed.
  /// City average speed: 25 km/h. Adds 20% buffer for traffic.
  static int etaInMinutes(double distanceKm, {double speedKmh = 25}) {
    final rawMinutes = (distanceKm / speedKmh) * 60;
    return (rawMinutes * 1.2).ceil(); // 20% traffic buffer
  }

  /// Human-readable ETA string e.g. "8 min" or "1 hr 12 min"
  static String etaLabel(double distanceKm) {
    final minutes = etaInMinutes(distanceKm);
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final rem = minutes % 60;
    return rem == 0 ? '$hours hr' : '$hours hr $rem min';
  }

  /// Human-readable distance string e.g. "2.4 km" or "850 m"
  static String distanceLabel(double lat1, double lng1, double lat2,
      double lng2) {
    final metres = distanceInMeters(lat1, lng1, lat2, lng2);
    if (metres < 1000) return '${metres.round()} m';
    return '${(metres / 1000).toStringAsFixed(1)} km';
  }

  // ─── Fare estimation ───────────────────────────────────────────────────────

  /// Base fare by vehicle type (₹/km). Mini=12, LCV=16, HCV=22, Container=28
  static const Map<String, double> _ratePerKm = {
    'Mini Truck': 12.0,
    'LCV': 16.0,
    'HCV': 22.0,
    'Container': 28.0,
  };

  static const double _baseFare = 50.0; // ₹ flat base
  static const double _weightSurchargePerTonne = 10.0; // ₹/tonne above 500kg

  /// Estimated fare in ₹ based on distance, vehicle type and weight.
  static double estimateFare({
    required double distanceKm,
    required String vehicleType,
    double weightKg = 0,
  }) {
    final rate = _ratePerKm[vehicleType] ?? 15.0;
    double fare = _baseFare + (distanceKm * rate);

    // Weight surcharge for every 500kg above first 500kg
    if (weightKg > 500) {
      final extraTonnes = (weightKg - 500) / 1000;
      fare += extraTonnes * _weightSurchargePerTonne * distanceKm;
    }
    return fare;
  }

  /// Returns fare as a formatted string e.g. "₹ 320"
  static String fareLabel({
    required double distanceKm,
    required String vehicleType,
    double weightKg = 0,
  }) {
    final fare = estimateFare(
        distanceKm: distanceKm,
        vehicleType: vehicleType,
        weightKg: weightKg);
    return '₹ ${fare.round()}';
  }

  static double _deg2rad(double deg) => deg * (math.pi / 180.0);
}
