import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../data/repositories/driver_repository.dart';
import '../../../data/models/user_model.dart';
import '../../onboarding/onboarding_screen.dart';

const _navy = Color(0xFF003F7D);
const _navyLight = Color(0xFFE6EEF8);

// Provider to load driver profile from Supabase
final driverProfileProvider = FutureProvider<UserModel?>((ref) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return null;
  return UserRepository().getUser(uid);
});

class DriverSettingsScreen extends ConsumerWidget {
  const DriverSettingsScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    // Set offline in Supabase
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await DriverRepository().setOnlineStatus(uid, online: false);
    }

    // Sign out Firebase
    await FirebaseAuth.instance.signOut();

    // Clear local prefs
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(driverProfileProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Profile',
            style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile card
            profileAsync.when(
              data: (user) => Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey.shade200,
                      ),
                      child: const Icon(Icons.person,
                          color: Colors.black54, size: 36),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user?.name ?? 'Driver',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.black87)),
                          const SizedBox(height: 2),
                          Text(user?.phone ?? '',
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.black54)),
                          if (user?.city != null) ...[
                            const SizedBox(height: 4),
                            Text(user!.city!,
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.black45)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              loading: () => const Center(
                  child: CircularProgressIndicator(color: _navy)),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 24),
            _MenuItem(
              icon: Icons.local_shipping_outlined,
              label: 'Vehicle Details',
              onTap: () {},
            ),
            _MenuItem(
              icon: Icons.description_outlined,
              label: 'Documents',
              onTap: () {},
            ),
            _MenuItem(
              icon: Icons.notifications_outlined,
              label: 'Notifications',
              onTap: () {},
            ),
            _MenuItem(
              icon: Icons.help_outline,
              label: 'Help & Support',
              onTap: () {},
            ),
            const SizedBox(height: 8),
            _MenuItem(
              icon: Icons.logout,
              label: 'Log Out',
              labelColor: Colors.red,
              iconColor: Colors.red,
              iconBgColor: Colors.red.shade50,
              showDivider: false,
              onTap: () => _logout(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? labelColor;
  final Color? iconColor;
  final Color? iconBgColor;
  final bool showDivider;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.labelColor,
    this.iconColor,
    this.iconBgColor,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                vertical: 14, horizontal: 4),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: iconBgColor ?? _navyLight,
                  ),
                  child: Icon(icon,
                      color: iconColor ?? _navy, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(label,
                      style: TextStyle(
                          fontSize: 16,
                          color: labelColor ?? Colors.black87,
                          fontWeight: FontWeight.w500)),
                ),
                Icon(Icons.chevron_right,
                    color: Colors.grey.shade400, size: 22),
              ],
            ),
          ),
        ),
        if (showDivider) Divider(height: 1, color: Colors.grey.shade100),
      ],
    );
  }
}
