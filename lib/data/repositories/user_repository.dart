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

  /// Permanently delete a user account.
  /// Foreign-key CASCADE removes related drivers/vehicles/trips/requests rows.
  /// Caller must also sign out of Firebase + clear local SharedPreferences.
  Future<void> deleteAccount(String uid) async {
    await _client.from('users').delete().eq('id', uid);
    // active_sessions, drivers, vehicles cascade automatically via ON DELETE CASCADE
  }

  // ─── ACID atomic signups ──────────────────────────────────────────────────

  /// Single-transaction driver signup. Either all 3 inserts (users + drivers
  /// + vehicles) succeed or NONE — no orphan accounts on partial failure.
  Future<void> signupDriverAtomic({
    required String uid,
    required String phone,
    required String name,
    required String licenseNumber,
    required String experience,
    required String vehicleId,
    required String vehicleNumber,
    required String vehicleType,
  }) async {
    await _client.rpc('signup_driver_atomic', params: {
      'p_uid': uid,
      'p_phone': phone,
      'p_name': name,
      'p_license_number': licenseNumber,
      'p_experience': experience,
      'p_vehicle_id': vehicleId,
      'p_vehicle_number': vehicleNumber,
      'p_vehicle_type': vehicleType,
    });
  }

  /// Single-transaction load owner signup.
  Future<void> signupLoadOwnerAtomic({
    required String uid,
    required String phone,
    required String name,
    String? companyName,
    String? city,
  }) async {
    await _client.rpc('signup_load_owner_atomic', params: {
      'p_uid': uid,
      'p_phone': phone,
      'p_name': name,
      'p_company_name': companyName,
      'p_city': city,
    });
  }
}
