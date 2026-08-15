// Driver-side profile screen — uses the shared AccountSettingsScreen
// which supports both Driver + Load Owner roles.
export '../../shared/account_settings_screen.dart' show AccountSettingsScreen;

// Re-export with the old name for backward compatibility with existing imports
// (so we don't need to rename every Navigator.push call across the codebase)
import 'package:flutter/material.dart';
import '../../shared/account_settings_screen.dart';

class DriverSettingsScreen extends StatelessWidget {
  const DriverSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => const AccountSettingsScreen();
}
