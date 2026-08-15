import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../driver/home/driver_home_screen.dart';
import '../load_owner/home/load_owner_home_screen.dart';

class LocationPermissionScreen extends StatelessWidget {
  final bool isDriver;

  const LocationPermissionScreen({super.key, required this.isDriver});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(),
              // Illustration
              Container(
                width: 200,
                height: 200,
                decoration: const BoxDecoration(
                  color: Color(0xFFE6EEF8),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: const BoxDecoration(
                      color: Color(0xFF003F7D),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.black,
                      size: 56,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 36),
              const Text(
                'Enable Location',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'We need your location to find trucks near you and show tracking.',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.black54,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              const _BenefitRow('Find nearby trucks/loads'),
              const SizedBox(height: 14),
              const _BenefitRow('Live tracking during trips'),
              const SizedBox(height: 14),
              const _BenefitRow('Accurate distance estimates'),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () async {
                    // Check if location services are enabled
                    final serviceEnabled =
                        await Geolocator.isLocationServiceEnabled();
                    if (!serviceEnabled) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Please enable Location Services in your phone settings'),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 4),
                        ),
                      );
                      return;
                    }

                    // Request permission
                    LocationPermission permission =
                        await Geolocator.checkPermission();
                    if (permission == LocationPermission.denied) {
                      permission = await Geolocator.requestPermission();
                    }

                    // BLOCK if denied — don't proceed to home with wrong location
                    if (permission == LocationPermission.denied) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'TripJio needs location to work. Please tap Allow.'),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 4),
                        ),
                      );
                      return;
                    }
                    if (permission == LocationPermission.deniedForever) {
                      if (!context.mounted) return;
                      // Show dialog directing them to settings
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Location Permission Required'),
                          content: const Text(
                              'You\'ve denied location permanently. Please enable it in your phone\'s Settings → Apps → TripJio → Permissions → Location.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('OK'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                Geolocator.openAppSettings();
                              },
                              child: const Text('Open Settings'),
                            ),
                          ],
                        ),
                      );
                      return;
                    }

                    // Permission granted — get an initial GPS fix BEFORE entering home
                    // This guarantees the home screen has a real location
                    try {
                      final position = await Geolocator.getCurrentPosition(
                        locationSettings: const LocationSettings(
                          accuracy: LocationAccuracy.medium,
                          timeLimit: Duration(seconds: 10),
                        ),
                      );
                      // Cache to SharedPreferences so home screen uses it
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setDouble(
                          'last_known_lat', position.latitude);
                      await prefs.setDouble(
                          'last_known_lng', position.longitude);
                      await prefs.setString(
                          'userType', isDriver ? 'driver' : 'loadOwner');
                    } catch (_) {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString(
                          'userType', isDriver ? 'driver' : 'loadOwner');
                    }

                    if (!context.mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => isDriver
                            ? const DriverHomeScreen()
                            : const LoadOwnerHomeScreen(),
                      ),
                      (_) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF003F7D),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Allow Location Access',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final String text;
  const _BenefitRow(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.check, color: Colors.green, size: 22),
        const SizedBox(width: 12),
        Text(
          text,
          style: const TextStyle(fontSize: 15, color: Colors.black87),
        ),
      ],
    );
  }
}
