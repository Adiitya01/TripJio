import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../data/repositories/trip_repository.dart';
import 'trip_completed_screen.dart';

class DriverArrivedScreen extends StatefulWidget {
  final dynamic driver;

  const DriverArrivedScreen({super.key, required this.driver});

  @override
  State<DriverArrivedScreen> createState() => _DriverArrivedScreenState();
}

class _DriverArrivedScreenState extends State<DriverArrivedScreen> {
  static const Color _navy = Color(0xFF003F7D);
  static const Color _navyLight = Color(0xFFE6EEF8);

  Timer? _statusPoll;

  @override
  void initState() {
    super.initState();
    // Poll trip status every 3s — when driver marks complete, navigate
    _statusPoll = Timer.periodic(const Duration(seconds: 3), (_) => _checkTripStatus());
  }

  @override
  void dispose() {
    _statusPoll?.cancel();
    super.dispose();
  }

  Future<void> _checkTripStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final trip = await TripRepository().getActiveTripForUser(uid);
      // If no active trip → driver completed it
      if (trip == null && mounted) {
        _statusPoll?.cancel();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => TripCompletedScreen(
              driverName: widget.driver.name as String?,
            ),
          ),
        );
      }
    } catch (_) {/* network glitch — try again on next tick */}
  }

  @override
  Widget build(BuildContext context) {
    final driver = widget.driver;
    final String driverName = driver.name ?? 'Driver';
    final String vehicleInfo = driver.vehicle ?? '';
    final String vehicleNumber = driver.number ?? '';
    final String firstName = driverName.split(' ')[0];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  Container(
                    width: 140,
                    height: 140,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFE8F5E9),
                    ),
                    child: Center(
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF2ECC71),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x332ECC71),
                              blurRadius: 16,
                              spreadRadius: 4,
                            )
                          ],
                        ),
                        child: const Icon(
                          Icons.local_shipping_rounded,
                          size: 54,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                  const Text(
                    'Driver has arrived!',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '$firstName is at the pickup location.\nPlease meet him.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 48),
                  // Driver Info Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: _navyLight,
                          ),
                          child: const Icon(Icons.person, color: _navy, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                driverName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$vehicleNumber · $vehicleInfo',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(flex: 3),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final phone = driver.phone ?? '';
                          if (phone.isEmpty) return;
                          final uri = Uri.parse('tel:$phone');
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri);
                          }
                        },
                        icon: const Icon(Icons.phone_outlined, size: 18, color: Colors.black87),
                        label: const Text(
                          'Call',
                          style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          // Waiting for driver to complete — polling will auto-navigate
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Waiting for the driver to mark trip complete...'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _navy,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Awaiting Trip End',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
