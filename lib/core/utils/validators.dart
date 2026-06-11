/// Input validators used across the app.
class Validators {
  // ─── Phone ─────────────────────────────────────────────────────────────────

  /// Validates an Indian mobile number (10 digits, optionally with +91).
  /// Returns null if valid, else an error message.
  static String? phone(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'Phone number required';
    final cleaned = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.length < 10) return 'Enter a valid 10-digit number';
    if (cleaned.length > 12) return 'Number too long';
    return null;
  }

  static String? otp(String? raw) {
    if (raw == null) return 'OTP required';
    final cleaned = raw.trim();
    if (cleaned.length != 6 || int.tryParse(cleaned) == null) {
      return 'Enter the 6-digit OTP';
    }
    return null;
  }

  // ─── Vehicle ───────────────────────────────────────────────────────────────

  /// Validates an Indian vehicle plate: e.g. MH14AB1234, KA01M2345.
  /// Strips spaces and dashes before checking.
  static String? vehicleNumber(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'Vehicle number required';
    final cleaned = raw.replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();
    final regex = RegExp(r'^[A-Z]{2}[0-9]{1,2}[A-Z]{1,3}[0-9]{1,4}$');
    if (!regex.hasMatch(cleaned)) return 'Invalid plate format (e.g. MH14AB1234)';
    return null;
  }

  // ─── Weight ────────────────────────────────────────────────────────────────

  static String? weightKg(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null; // weight is optional
    final value = double.tryParse(raw.trim());
    if (value == null) return 'Enter a valid number';
    if (value <= 0) return 'Weight must be positive';
    if (value > 50000) return 'Weight cannot exceed 50,000 kg';
    return null;
  }

  // ─── Address / text fields ────────────────────────────────────────────────

  static String? address(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'Address required';
    if (raw.trim().length < 3) return 'Address too short';
    if (raw.length > 500) return 'Address too long (max 500 chars)';
    return null;
  }

  static String? notes(String? raw, {int maxLen = 1000}) {
    if (raw == null) return null;
    if (raw.length > maxLen) return 'Notes too long (max $maxLen chars)';
    return null;
  }

  static String? name(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'Name required';
    if (raw.trim().length < 2) return 'Name too short';
    if (raw.length > 100) return 'Name too long';
    return null;
  }
}
