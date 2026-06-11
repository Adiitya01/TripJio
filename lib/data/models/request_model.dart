class RequestModel {
  final String id;
  final String loadOwnerId;
  final String driverId;
  final String pickupAddress;
  final String dropAddress;
  final double pickupLat;
  final double pickupLng;
  final double dropLat;
  final double dropLng;
  final String? goodsDescription;
  final double? weightKg;
  final String status; // 'pending', 'accepted', 'rejected', 'expired'
  final DateTime createdAt;
  final DateTime expiresAt;

  const RequestModel({
    required this.id,
    required this.loadOwnerId,
    required this.driverId,
    required this.pickupAddress,
    required this.dropAddress,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropLat,
    required this.dropLng,
    this.goodsDescription,
    this.weightKg,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
  });

  factory RequestModel.fromMap(Map<String, dynamic> map) {
    return RequestModel(
      id: map['id'] as String,
      loadOwnerId: map['load_owner_id'] as String,
      driverId: map['driver_id'] as String,
      pickupAddress: map['pickup_address'] as String,
      dropAddress: map['drop_address'] as String,
      pickupLat: (map['pickup_lat'] as num).toDouble(),
      pickupLng: (map['pickup_lng'] as num).toDouble(),
      dropLat: (map['drop_lat'] as num).toDouble(),
      dropLng: (map['drop_lng'] as num).toDouble(),
      goodsDescription: map['goods_description'] as String?,
      weightKg: (map['weight_kg'] as num?)?.toDouble(),
      status: map['status'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      expiresAt: DateTime.parse(map['expires_at'] as String),
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
      'goods_description': goodsDescription,
      'weight_kg': weightKg,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
    };
  }
}
