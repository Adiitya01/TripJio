import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/firebase_options.dart';
import 'core/config/supabase_config.dart';
import 'core/services/notification_service.dart';
import 'core/services/app_lifecycle_service.dart';
import 'core/widgets/connectivity_banner.dart';
import 'features/onboarding/splash/splash_screen.dart';

/// Global navigator key — used by NotificationService to route notification
/// taps into the widget tree from outside of any BuildContext.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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

    // ─── Initialize Firebase ───────────────────────────────
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Crashlytics: collect only in release, mirror to console in debug.
    await FirebaseCrashlytics.instance
        .setCrashlyticsCollectionEnabled(kReleaseMode);
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    };
    // Catches errors from the platform/Flutter engine outside the framework.
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

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

    // ─── Preload Poppins in parallel with the splash animation ─────────────
    // Without this, the first-launch onboarding screen renders with the system
    // fallback (Roboto) and then visibly re-flows to Poppins once Google Fonts
    // finishes downloading. Fire-and-forget: don't block startup on it.
    unawaited(GoogleFonts.pendingFonts([
      GoogleFonts.poppins(fontWeight: FontWeight.w400),
      GoogleFonts.poppins(fontWeight: FontWeight.w500),
      GoogleFonts.poppins(fontWeight: FontWeight.w600),
      GoogleFonts.poppins(fontWeight: FontWeight.w700),
    ]));

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
    if (kDebugMode) {
      debugPrint('Uncaught async error: $error\n$stack');
    }
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TripJio',
      navigatorKey: navigatorKey,
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
