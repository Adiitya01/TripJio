class VehicleModel {
  final String id;
  final String userId;
  final String vehicleNumber;
  final String vehicleType; // 'Mini Truck', 'LCV', 'HCV', 'Container'
  final String? photoUrl;
  final DateTime createdAt;

  const VehicleModel({
    required this.id,
    required this.userId,
    required this.vehicleNumber,
    required this.vehicleType,
    this.photoUrl,
    required this.createdAt,
  });

  factory VehicleModel.fromMap(Map<String, dynamic> map) {
    return VehicleModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      vehicleNumber: map['vehicle_number'] as String,
      vehicleType: map['vehicle_type'] as String,
      photoUrl: map['photo_url'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'vehicle_number': vehicleNumber,
      'vehicle_type': vehicleType,
      'photo_url': photoUrl,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
