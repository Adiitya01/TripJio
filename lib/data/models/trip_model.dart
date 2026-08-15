class TripModel {
  final String id;
  final String loadOwnerId;
  final String driverId;
  final String pickupAddress;
  final String dropAddress;
  final double pickupLat;
  final double pickupLng;
  final double dropLat;
  final double dropLng;
  final String status; // 'pending', 'accepted', 'in_progress', 'completed', 'cancelled'
  final double? distanceKm;
  final String? goodsDescription;
  final double? weightKg;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? pickupConfirmedAt;

  const TripModel({
    required this.id,
    required this.loadOwnerId,
    required this.driverId,
    required this.pickupAddress,
    required this.dropAddress,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropLat,
    required this.dropLng,
    required this.status,
    this.distanceKm,
    this.goodsDescription,
    this.weightKg,
    required this.createdAt,
    this.completedAt,
    this.pickupConfirmedAt,
  });

  factory TripModel.fromMap(Map<String, dynamic> map) {
    return TripModel(
      id: map['id'] as String,
      loadOwnerId: map['load_owner_id'] as String,
      driverId: map['driver_id'] as String,
      pickupAddress: map['pickup_address'] as String,
      dropAddress: map['drop_address'] as String,
      pickupLat: (map['pickup_lat'] as num).toDouble(),
      pickupLng: (map['pickup_lng'] as num).toDouble(),
      dropLat: (map['drop_lat'] as num).toDouble(),
      dropLng: (map['drop_lng'] as num).toDouble(),
      status: map['status'] as String,
      distanceKm: (map['distance_km'] as num?)?.toDouble(),
      goodsDescription: map['goods_description'] as String?,
      weightKg: (map['weight_kg'] as num?)?.toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
      completedAt: map['completed_at'] != null
          ? DateTime.parse(map['completed_at'] as String)
          : null,
      pickupConfirmedAt: map['pickup_confirmed_at'] != null
          ? DateTime.parse(map['pickup_confirmed_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'load_owner_id': loadOwnerId,
      'driver_id': driverId,
      'pickup_address': pickupAddress,
      'drop_address': dropAddress,
      'pickup_lat': pickupLat,
      'pickup_lng': pickupLng,
      'drop_lat': dropLat,
      'drop_lng': dropLng,
      'status': status,
      'distance_km': distanceKm,
      'goods_description': goodsDescription,
      'weight_kg': weightKg,
      'created_at': createdAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'pickup_confirmed_at': pickupConfirmedAt?.toIso8601String(),
    };
  }
}
