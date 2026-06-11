import 'user_model.dart';
import 'vehicle_model.dart';

class DriverModel {
  final UserModel user;
  final VehicleModel vehicle;
  final String licenseNumber;
  final String experience;
  final bool isOnline;
  final double? latitude;
  final double? longitude;
  final double rating;
  final int totalTrips;

  const DriverModel({
    required this.user,
    required this.vehicle,
    required this.licenseNumber,
    required this.experience,
    this.isOnline = false,
    this.latitude,
    this.longitude,
    this.rating = 0.0,
    this.totalTrips = 0,
  });

  factory DriverModel.fromMap(Map<String, dynamic> map) {
    return DriverModel(
      user: UserModel.fromMap(map['user'] as Map<String, dynamic>),
      vehicle: VehicleModel.fromMap(map['vehicle'] as Map<String, dynamic>),
      licenseNumber: map['license_number'] as String,
      experience: map['experience'] as String,
      isOnline: map['is_online'] as bool? ?? false,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      totalTrips: map['total_trips'] as int? ?? 0,
    );
  }
}
