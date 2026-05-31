import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Singleton wrapper around Firebase Phone Authentication.
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ── Getters ──────────────────────────────────────────────────────────────

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  bool get isLoggedIn => _auth.currentUser != null;

  // ── Phone OTP ─────────────────────────────────────────────────────────────

  /// Sends OTP to [phoneNumber] (must include country code e.g. +91XXXXXXXXXX).
  /// Calls [onCodeSent] with verificationId + resendToken on success.
  /// Calls [onError] with a human-readable message on failure.
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(String error) onError,
    int? resendToken,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        forceResendingToken: resendToken,
        timeout: const Duration(seconds: 60),

        // Android only: auto-verify when OTP is detected from SMS
        verificationCompleted: (PhoneAuthCredential credential) async {
          debugPrint('Auto-verification completed');
          await _auth.signInWithCredential(credential);
        },

        verificationFailed: (FirebaseAuthException e) {
          debugPrint('Verification failed: ${e.code} — ${e.message}');
          final msg = switch (e.code) {
            'invalid-phone-number' =>
              'Invalid phone number. Please check and try again.',
            'too-many-requests' =>
              'Too many attempts. Please try again later.',
            'network-request-failed' =>
              'No internet connection. Please check and try again.',
            _ => e.message ?? 'Verification failed. Please try again.',
          };
          onError(msg);
        },

        codeSent: (String verificationId, int? resendToken) {
          debugPrint('OTP sent. VerificationId: $verificationId');
          onCodeSent(verificationId, resendToken);
        },

        codeAutoRetrievalTimeout: (String verificationId) {
          debugPrint('Auto retrieval timeout');
        },
      );
    } catch (e) {
      debugPrint('verifyPhoneNumber error: $e');
      onError('Something went wrong. Please try again.');
    }
  }

  /// Verifies the OTP entered by the user.
  /// Returns [UserCredential] on success.
  Future<UserCredential> signInWithOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return await _auth.signInWithCredential(credential);
  }

  // ── Sign Out ──────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
