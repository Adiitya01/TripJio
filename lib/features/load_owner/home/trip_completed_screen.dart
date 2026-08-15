import 'package:flutter/material.dart';
import 'load_owner_home_screen.dart';

const _navy = Color(0xFF003F7D);
const _navyLight = Color(0xFFE6EEF8);
const _green = Color(0xFF2ECC71);

/// Shown to the Load Owner after the Driver marks their trip as completed.
class TripCompletedScreen extends StatelessWidget {
  final String? driverName;
  final String? distanceKm;

  const TripCompletedScreen({
    super.key,
    this.driverName,
    this.distanceKm,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            // Success badge
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
                    color: _green,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x332ECC71),
                        blurRadius: 16,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 64,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            const Text(
              'Trip Completed',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                driverName != null
                    ? 'Your goods have been delivered by $driverName.'
                    : 'Your goods have been successfully delivered.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _navyLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.account_balance_wallet_outlined,
                      color: _navy, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Please pay the driver directly via UPI.',
                      style: TextStyle(
                        fontSize: 14,
                        color: _navy,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(flex: 3),
            // Back to home button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                        builder: (_) => const LoadOwnerHomeScreen()),
                    (_) => false,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _navy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Back to Home',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
