import 'user_model.dart';

class LoadOwnerModel {
  final UserModel user;
  final int totalRequests;
  final int completedTrips;

  const LoadOwnerModel({
    required this.user,
    this.totalRequests = 0,
    this.completedTrips = 0,
  });

  factory LoadOwnerModel.fromMap(Map<String, dynamic> map) {
    return LoadOwnerModel(
      user: UserModel.fromMap(map['user'] as Map<String, dynamic>),
      totalRequests: map['total_requests'] as int? ?? 0,
      completedTrips: map['completed_trips'] as int? ?? 0,
    );
  }
}
