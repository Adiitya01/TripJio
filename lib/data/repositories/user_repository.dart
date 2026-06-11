import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../models/vehicle_model.dart';

class UserRepository {
  final SupabaseClient _client = Supabase.instance.client;

  /// Save or update a user profile in Supabase.
  Future<void> saveUser(UserModel user) async {
    await _client.from('users').upsert(user.toMap());
  }

  /// Save a vehicle linked to a driver user.
  Future<void> saveVehicle(VehicleModel vehicle) async {
    await _client.from('vehicles').upsert(vehicle.toMap());
  }

  /// Save driver-specific info (license, experience) to drivers table.
  Future<void> saveDriverDetails({
    required String userId,
    required String licenseNumber,
    required String experience,
  }) async {
    await _client.from('drivers').upsert({
      'user_id': userId,
      'license_number': licenseNumber,
      'experience': experience,
      'is_online': false,
      'rating': 0.0,
      'total_trips': 0,
    });
  }

  /// Fetch a user profile by Firebase UID.
  Future<UserModel?> getUser(String uid) async {
    final response = await _client
        .from('users')
        .select()
        .eq('id', uid)
        .maybeSingle();
    if (response == null) return null;
    return UserModel.fromMap(response);
  }

  /// Check if a user has completed their profile setup.
  Future<bool> isProfileComplete(String uid) async {
    final user = await getUser(uid);
    return user != null;
  }
}
