import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Phone number entered during auth — shared between PhoneEntryScreen → OtpScreen
final phoneNumberProvider = StateProvider<String>((ref) => '');

// true if user has completed signup and is persisted on device
final authStateProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('isLoggedIn') ?? false;
});

// 'driver' or 'loadOwner' — persisted after profile setup
final storedUserTypeProvider = FutureProvider<String?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('userType');
});
