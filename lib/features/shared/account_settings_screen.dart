import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../data/repositories/driver_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/models/user_model.dart';
import '../onboarding/onboarding_screen.dart';
import 'legal_document_screen.dart';
import 'trip_history_screen.dart';

const String _supportEmail = 'support@tripjio.in';

const _navy = Color(0xFF003F7D);
const _navyLight = Color(0xFFE6EEF8);

/// Provider — fetches the current user's profile from Supabase.
final accountProfileProvider = FutureProvider<UserModel?>((ref) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return null;
  return UserRepository().getUser(uid);
});

/// Provider — fetches driver-specific details (license, vehicle, stats).
/// Returns null for load owners.
final driverDetailsProvider = FutureProvider<DriverDetails?>((ref) async {
  final user = await ref.watch(accountProfileProvider.future);
  if (user == null || user.userType != 'driver') return null;
  return DriverRepository().getDriverDetails(user.id);
});

/// Unified Account Settings screen for both Driver and Load Owner.
class AccountSettingsScreen extends ConsumerWidget {
  const AccountSettingsScreen({super.key});

  Future<void> _openSupportEmail(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      queryParameters: {
        'subject': 'TripJio support request',
      },
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No email app available. Write to $_supportEmail.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Log out?',
      message:
          'You\'ll need to sign in again next time you open TripJio.',
      confirmText: 'Log out',
      isDestructive: true,
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    // If driver, set offline first
    if (uid != null) {
      try {
        await DriverRepository().setOnlineStatus(uid, online: false);
      } catch (_) {/* might not be a driver, ignore */}
    }
    await FirebaseAuth.instance.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      (_) => false,
    );
  }

  Future<void> _deleteAccount(BuildContext context) async {
    // First warning
    final confirmed1 = await ConfirmDialog.show(
      context,
      title: 'Delete your account?',
      message:
          'This will permanently delete your TripJio account, profile, vehicle info, and trip history. This cannot be undone.',
      confirmText: 'Continue',
      isDestructive: true,
    );
    if (confirmed1 != true) return;
    if (!context.mounted) return;

    // Second confirmation (Uber/Rapido pattern)
    final confirmed2 = await ConfirmDialog.show(
      context,
      title: 'Are you absolutely sure?',
      message:
          'Type-deleting your account is irreversible. Tap Delete to continue or Cancel to keep your account.',
      confirmText: 'Delete Account',
      isDestructive: true,
    );
    if (confirmed2 != true) return;
    if (!context.mounted) return;

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await UserRepository().deleteAccount(uid);
      }
      // Delete Firebase auth user too
      try {
        await FirebaseAuth.instance.currentUser?.delete();
      } catch (_) {
        // If recent login required, just sign out — DB row is already deleted
        await FirebaseAuth.instance.signOut();
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your account has been deleted'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        (_) => false,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'Could not delete account. Please try again or contact support.'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(accountProfileProvider);
    final driverDetailsAsync = ref.watch(driverDetailsProvider);

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
        title: const Text(
          'Profile',
          style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ─── Profile card ───
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
                          Text(user?.name ?? 'User',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.black87)),
                          const SizedBox(height: 4),
                          Text(user?.phone ?? '',
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.black54)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _navyLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              user?.userType == 'driver'
                                  ? 'Driver'
                                  : 'Load Owner',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: _navy,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (user?.companyName != null &&
                              user!.companyName!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.business_outlined,
                                    size: 14, color: Colors.black54),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(user.companyName!,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.black87,
                                          fontWeight: FontWeight.w500),
                                      overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            ),
                          ],
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
              loading: () =>
                  const Center(child: CircularProgressIndicator(color: _navy)),
              error: (_, __) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 16),

            // ─── Driver-only: vehicle & license details ───
            driverDetailsAsync.maybeWhen(
              data: (details) => details == null
                  ? const SizedBox.shrink()
                  : _DriverDetailsCard(details: details),
              orElse: () => const SizedBox.shrink(),
            ),

            const SizedBox(height: 16),

            // ─── Menu items ───
            _MenuItem(
              icon: Icons.history,
              label: 'Trip history',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const TripHistoryScreen(),
                ),
              ),
            ),
            _MenuItem(
              icon: Icons.help_outline,
              label: 'Help & Support',
              onTap: () => _openSupportEmail(context),
            ),
            _MenuItem(
              icon: Icons.privacy_tip_outlined,
              label: 'Privacy Policy',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const LegalDocumentScreen(
                    title: 'Privacy Policy',
                    assetPath: 'assets/legal/privacy.md',
                  ),
                ),
              ),
            ),
            _MenuItem(
              icon: Icons.description_outlined,
              label: 'Terms & Conditions',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const LegalDocumentScreen(
                    title: 'Terms & Conditions',
                    assetPath: 'assets/legal/terms.md',
                  ),
                ),
              ),
            ),
            _MenuItem(
              icon: Icons.info_outline,
              label: 'About TripJio',
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'TripJio',
                  applicationVersion: '1.0.0',
                  applicationLegalese:
                      '© 2026 Trip-Jio Logistics',
                  children: const [
                    SizedBox(height: 12),
                    Text(
                      'Connecting load owners with truck drivers across India.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),

            _MenuItem(
              icon: Icons.logout,
              label: 'Log Out',
              labelColor: Colors.red,
              iconColor: Colors.red,
              iconBgColor: Colors.red.shade50,
              onTap: () => _logout(context),
            ),
            _MenuItem(
              icon: Icons.delete_forever_outlined,
              label: 'Delete Account',
              labelColor: Colors.red.shade900,
              iconColor: Colors.red.shade900,
              iconBgColor: Colors.red.shade50,
              showDivider: false,
              onTap: () => _deleteAccount(context),
            ),

            const SizedBox(height: 24),
            const Text(
              'TripJio v1.0.0',
              style: TextStyle(fontSize: 11, color: Colors.black38),
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
            padding:
                const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: iconBgColor ?? _navyLight,
                  ),
                  child:
                      Icon(icon, color: iconColor ?? _navy, size: 20),
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

class _DriverDetailsCard extends StatelessWidget {
  final DriverDetails details;
  const _DriverDetailsCard({required this.details});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vehicle & licence',
            style: TextStyle(
              fontSize: 11,
              color: Colors.black45,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          if (details.vehicleNumber != null && details.vehicleNumber!.isNotEmpty)
            _DetailRow(
              icon: Icons.local_shipping_outlined,
              label: 'Vehicle',
              value: '${details.vehicleType ?? ''} · ${details.vehicleNumber}',
            ),
          if (details.licenseNumber.isNotEmpty)
            _DetailRow(
              icon: Icons.badge_outlined,
              label: 'Licence',
              value: details.licenseNumber,
            ),
          if (details.experience.isNotEmpty)
            _DetailRow(
              icon: Icons.work_history_outlined,
              label: 'Experience',
              value: details.experience,
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: 'Rating',
                  value: details.rating > 0
                      ? details.rating.toStringAsFixed(1)
                      : '—',
                  icon: Icons.star_rounded,
                  iconColor: const Color(0xFFF59E0B),
                ),
              ),
              Container(
                  width: 1,
                  height: 36,
                  color: Colors.grey.shade200),
              Expanded(
                child: _Stat(
                  label: 'Trips',
                  value: details.totalTrips.toString(),
                  icon: Icons.local_shipping_rounded,
                  iconColor: _navy,
                ),
              ),
              Container(
                  width: 1,
                  height: 36,
                  color: Colors.grey.shade200),
              Expanded(
                child: _Stat(
                  label: 'Status',
                  value: details.isOnline ? 'Online' : 'Offline',
                  icon: Icons.circle,
                  iconColor: details.isOnline
                      ? const Color(0xFF2ECC71)
                      : Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.black54),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  const _Stat({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
