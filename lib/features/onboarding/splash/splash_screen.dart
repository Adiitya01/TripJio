import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import '../onboarding_screen.dart';
import '../../driver/home/driver_home_screen.dart';
import '../../load_owner/home/load_owner_home_screen.dart';
import '../../../core/services/session_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Phase 1 – logo fades in and scales up
  late AnimationController _introController;
  late Animation<double> _logoFadeAnimation;
  late Animation<double> _logoScaleAnimation;

  // Phase 2 – circle halves slide apart
  late AnimationController _splitController;
  late Animation<double> _splitAnimation;

  // Phase 3 – truck drives off right edge; circle halves + text fade out
  late AnimationController _exitController;
  late Animation<double> _truckSlideAnimation;
  late Animation<double> _contentFadeAnimation;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });

    final dataPreloadFuture = _preloadAppData();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _logoFadeAnimation = CurvedAnimation(
      parent: _introController,
      curve: Curves.easeIn,
    );
    _logoScaleAnimation = CurvedAnimation(
      parent: _introController,
      curve: Curves.easeOutBack,
    );

    _splitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _splitAnimation = CurvedAnimation(
      parent: _splitController,
      curve: Curves.easeInOutCubic,
    );

    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    // Truck starts slow then accelerates hard off screen
    _truckSlideAnimation = CurvedAnimation(
      parent: _exitController,
      curve: Curves.easeInQuart,
    );
    // Text + circle fade out in the first 55 % of the exit phase
    _contentFadeAnimation = CurvedAnimation(
      parent: _exitController,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
    );

    _introController.forward().then((_) {
      dataPreloadFuture.then((appData) {
        if (!mounted) return;

        final isLoggedIn = appData['isLoggedIn'] as bool;
        final userType = appData['userType'] as String?;

        final Widget nextScreen;
        if (isLoggedIn && userType != null) {
          nextScreen = userType == 'driver'
              ? const DriverHomeScreen()
              : const LoadOwnerHomeScreen();
        } else {
          nextScreen = const OnboardingScreen();
        }

        // Circle splits open …
        _splitController.forward().then((_) {
          if (!mounted) return;
          // … then truck drives away
          _exitController.forward().then((_) {
            if (!mounted) return;
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => nextScreen,
                transitionsBuilder: (_, animation, __, child) {
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.06),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    )),
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                transitionDuration: const Duration(milliseconds: 350),
              ),
            );
          });
        });
      });
    });
  }

  Future<Map<String, dynamic>> _preloadAppData() async {
    final results = await Future.wait([
      SharedPreferences.getInstance(),
      Future.delayed(const Duration(milliseconds: 2500)),
    ]);
    final prefs = results[0] as SharedPreferences;

    final firebaseUser = FirebaseAuth.instance.currentUser;
    var isLoggedIn = firebaseUser != null;
    final userType = prefs.getString('userType');

    // Refresh Firebase token + verify this device is still the active session.
    // If user signed in on another device → force log out here (1.2 + 1.8).
    if (isLoggedIn) {
      await SessionService.refreshAuthToken();
      try {
        final stillValid =
            await SessionService.isSessionValid(firebaseUser.uid);
        if (!stillValid) {
          await FirebaseAuth.instance.signOut();
          await prefs.clear();
          isLoggedIn = false;
        }
      } catch (_) {
        // Network error — let user in; will re-check on next request
      }
    }

    return {
      'isLoggedIn': isLoggedIn,
      'userType': userType,
    };
  }

  @override
  void dispose() {
    _introController.dispose();
    _splitController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF003F7D),
      body: AnimatedBuilder(
        animation: Listenable.merge(
            [_introController, _splitController, _exitController]),
        builder: (context, _) {
          // How far each circle half has travelled (px from centre)
          final splitOffset =
              _splitAnimation.value * 68.0 + _exitController.value * 68.0;

          // Truck slides from centre to right edge
          final truckOffset =
              _truckSlideAnimation.value * (size.width / 2 + 30);

          // Opacity shared by text, circle, and "Made in India"
          final visibleOpacity =
              (1.0 - _contentFadeAnimation.value).clamp(0.0, 1.0);

          final circleOpacity = _logoFadeAnimation.value * visibleOpacity;
          final textOpacity = _logoFadeAnimation.value * visibleOpacity;
          final scale = 0.8 + (_logoScaleAnimation.value * 0.2);

          return Column(
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ── Circle halves + truck ──────────────────────────
                      Transform.scale(
                        scale: scale,
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            // Animated split circle drawn with CustomPainter
                            CustomPaint(
                              size: const Size(120, 120),
                              painter: _SplitCirclePainter(
                                splitOffset: splitOffset,
                                opacity: circleOpacity,
                              ),
                            ),
                            // Only the truck icon slides right
                            Transform.translate(
                              offset: Offset(truckOffset, 0),
                              child: Opacity(
                                opacity: _logoFadeAnimation.value,
                                child: const Icon(
                                  Icons.local_shipping_outlined,
                                  color: Colors.black,
                                  size: 60,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // ── Text ───────────────────────────────────────────
                      Opacity(
                        opacity: textOpacity,
                        child: const Column(
                          children: [
                            Text(
                              'TripJio',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 52,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Find · Connect · Go',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Made in India ──────────────────────────────────────────
              Opacity(
                opacity: textOpacity,
                child: const Padding(
                  padding: EdgeInsets.only(bottom: 32),
                  child: Text(
                    'Made in India',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Custom painter for the splitting circle ────────────────────────────────────

class _SplitCirclePainter extends CustomPainter {
  final double splitOffset; // pixels each half has moved from centre
  final double opacity;

  const _SplitCirclePainter({
    required this.splitOffset,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;

    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25 * opacity);

    final center = Offset(size.width / 2, size.height / 2);
    const radius = 60.0;

    // Top semicircle – slides upward
    canvas.save();
    canvas.translate(0, -splitOffset);
    canvas.drawPath(
      Path()
        // start at left (π), sweep π clockwise → traces the TOP arc
        ..addArc(
            Rect.fromCircle(center: center, radius: radius), math.pi, math.pi)
        ..close(), // chord closes the semicircle
      paint,
    );
    canvas.restore();

    // Bottom semicircle – slides downward
    canvas.save();
    canvas.translate(0, splitOffset);
    canvas.drawPath(
      Path()
        // start at right (0), sweep π clockwise → traces the BOTTOM arc
        ..addArc(Rect.fromCircle(center: center, radius: radius), 0, math.pi)
        ..close(),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SplitCirclePainter old) =>
      old.splitOffset != splitOffset || old.opacity != opacity;
}
