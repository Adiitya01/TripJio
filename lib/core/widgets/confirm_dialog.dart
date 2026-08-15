import 'package:flutter/material.dart';

/// Reusable confirmation dialog with TripJio styling.
///
/// Usage:
///   final confirmed = await ConfirmDialog.show(
///     context,
///     title: 'Log out?',
///     message: 'You\'ll need to sign in again.',
///     confirmText: 'Log out',
///     isDestructive: true,
///   );
///   if (confirmed == true) { ... }
class ConfirmDialog {
  ConfirmDialog._();

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 15, color: Colors.black87),
        ),
        actionsPadding:
            const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              cancelText,
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDestructive
                  ? Colors.red.shade700
                  : const Color(0xFF003F7D),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 10),
            ),
            child: Text(
              confirmText,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
