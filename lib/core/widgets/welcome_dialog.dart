import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shows a friendly welcome dialog the FIRST time a user lands on home.
/// Uses SharedPreferences to ensure it shows only once.
class WelcomeDialog {
  WelcomeDialog._();

  static const _kSeenKey = 'welcome_dialog_seen';

  /// Show if not seen before. Returns true if shown, false if skipped.
  static Future<void> showOnce(
    BuildContext context, {
    required bool isDriver,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kSeenKey) == true) return;
    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _WelcomeDialogContent(isDriver: isDriver),
    );

    await prefs.setBool(_kSeenKey, true);
  }
}

class _WelcomeDialogContent extends StatelessWidget {
  final bool isDriver;
  const _WelcomeDialogContent({required this.isDriver});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFE6EEF8),
              ),
              child: const Icon(
                Icons.local_shipping_rounded,
                size: 40,
                color: Color(0xFF003F7D),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Welcome to TripJio! 🚛',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF003F7D),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            Text(
              isDriver
                  ? 'You\'re all set!\n\nToggle "Go Online" to start receiving load requests near you. The more available you are, the more trips you\'ll get.'
                  : 'You\'re all set!\n\nTap "Find a Driver" to see trucks near you, then send a request to get your goods moving — anywhere, anytime.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            _Tip(
              icon: Icons.location_on_outlined,
              text: isDriver
                  ? 'Keep GPS on so customers can see you'
                  : 'Allow location so we can find drivers near you',
            ),
            const SizedBox(height: 8),
            _Tip(
              icon: Icons.notifications_active_outlined,
              text: isDriver
                  ? 'Keep the app open for real-time requests'
                  : 'You\'ll get notified when a driver accepts',
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF003F7D),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                  elevation: 0,
                ),
                child: const Text(
                  'Got it!',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Tip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF003F7D)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black54,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
