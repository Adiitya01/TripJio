import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Manages single-active-session across devices.
/// Logs out the previous device when a new one logs in.
class SessionService {
  static const _deviceIdKey = 'device_id';

  /// Get this device's unique ID (creates one if missing).
  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_deviceIdKey);
    if (id == null) {
      id = const Uuid().v4();
      await prefs.setString(_deviceIdKey, id);
    }
    return id;
  }

  /// Register this device as the active session for the given user.
  /// Returns 'new', 'same', or 'replaced'.
  static Future<String> registerSession(String userId) async {
    final deviceId = await getDeviceId();
    String? fcmToken;
    try {
      fcmToken = await FirebaseMessaging.instance.getToken();
    } catch (_) {/* notifications may be blocked */}

    final result = await Supabase.instance.client.rpc(
      'register_session',
      params: {
        'p_user_id': userId,
        'p_device_id': deviceId,
        'p_fcm_token': fcmToken,
      },
    );
    return result as String;
  }

  /// Check if this device is still the active session for the user.
  /// If false, the user signed in on another device — force log out here.
  static Future<bool> isSessionValid(String userId) async {
    final deviceId = await getDeviceId();
    final result = await Supabase.instance.client.rpc(
      'is_session_valid',
      params: {'p_user_id': userId, 'p_device_id': deviceId},
    );
    return result as bool;
  }

  /// Refresh the Firebase ID token. Call on app resume or before critical
  /// operations to avoid expired-token failures.
  static Future<void> refreshAuthToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await user.getIdToken(true); // force refresh
    } catch (_) {/* will retry on next call */}
  }
}
