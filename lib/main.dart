import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/firebase_options.dart';
import 'core/config/supabase_config.dart';
import 'core/services/notification_service.dart';
import 'core/services/app_lifecycle_service.dart';
import 'core/widgets/connectivity_banner.dart';
import 'features/onboarding/splash/splash_screen.dart';

/// Top-level handler called when an FCM message arrives while
/// the app is in the background or terminated. Must be a
/// top-level function (not closure).
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundMessageHandler(RemoteMessage message) async {
  // Initialize Firebase for this isolate
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // The OS will automatically display the notification banner from
  // the `notification` payload of the FCM message. No code needed here.
  // Tapping the notification opens the app to the default route.
}

void main() async {
  // Catch uncaught Flutter errors → log + report (replace with Sentry/Crashlytics later)
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    final widgetsBinding = WidgetsBinding.instance;
    FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      if (kReleaseMode) {
        // TODO: report to Sentry / Crashlytics
      }
    };

    // ─── Initialize Firebase ───────────────────────────────
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Register background FCM handler (must be done early, before runApp)
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundMessageHandler);

    // ─── Initialize Supabase ───────────────────────────────
    // Bridge Firebase identity into Supabase: every PostgREST / RPC / Realtime
    // request carries the current user's Firebase ID token as the bearer, so
    // Postgres RLS and RPCs can trust `auth.jwt()->>'sub'` (the Firebase UID)
    // instead of a client-supplied id. Requires Firebase to be registered as a
    // third-party auth provider in the Supabase dashboard (see
    // supabase_auth_hardening.sql header). Returns null before login, which
    // leaves those requests anonymous — acceptable because pre-login screens
    // touch no protected tables.
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
      accessToken: () async {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return null;
        return await user.getIdToken();
      },
    );

    // ─── Initialize notifications (safe — wrapped in try/catch internally) ─
    await NotificationService().initialize();

    // ─── Debug-only: bypass Firebase phone verification ────
    // CRITICAL: only runs in debug mode. Release builds enforce real OTP.
    if (kDebugMode) {
      await FirebaseAuth.instance.setSettings(
        appVerificationDisabledForTesting: true,
      );
    }

    runApp(const ProviderScope(child: MyApp()));
  }, (error, stack) {
    // Global async error catcher
    if (kDebugMode) {
      debugPrint('💥 Uncaught async error: $error\n$stack');
    }
    // TODO: report to Sentry / Crashlytics in release
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TripJio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF003F7D),
        useMaterial3: true,
      ),
      home: const ConnectivityBanner(
        child: AppLifecycleService(child: SplashScreen()),
      ),
    );
  }
}
