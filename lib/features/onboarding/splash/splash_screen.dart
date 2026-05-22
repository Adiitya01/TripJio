import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'widgets/skeleton_screens.dart';
import '../onboarding_screen.dart';
import '../../driver/home/driver_home_screen.dart';
import '../../load_owner/home/load_owner_home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _introController;
  late Animation<double> _logoFadeAnimation;
  late Animation<double> _logoScaleAnimation;

  late AnimationController _splitController;
  late Animation<double> _splitAnimation;

  Widget? _backgroundWidget;

  @override
  void initState() {
    super.initState();

    // 1. Remove the native splash screen after the first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });

    // 2. Start preloading data IMMEDIATELY in parallel
    final dataPreloadFuture = _preloadAppData();

    // 3. Initialize Animations
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
      duration: const Duration(milliseconds: 900),
    );
    _splitAnimation = CurvedAnimation(
      parent: _splitController,
      curve: Curves.easeInOutCubic,
    );

    // 4. Start entry animation and coordinate split
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

        setState(() {
          if (isLoggedIn && userType != null) {
            _backgroundWidget = userType == 'driver'
                ? const DriverHomeSkeleton()
                : const LoadOwnerHomeSkeleton();
          } else {
            _backgroundWidget = const OnboardingScreen();
          }
        });


        // 5. Trigger the split door animation
        _splitController.forward().then((_) {
          if (!mounted) return;
          // Navigate to the next screen immediately without further transitions
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => nextScreen,
              transitionDuration: Duration.zero,
            ),
          );
        });
      });
    });
  }

  Future<Map<String, dynamic>> _preloadAppData() async {
    // Concurrently fetch local settings and simulate minor API latency (GPS, active list pre-fetch)
    final results = await Future.wait([
      SharedPreferences.getInstance(),
      Future.delayed(const Duration(milliseconds: 1200)),
    ]);

    final prefs = results[0] as SharedPreferences;
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    final userType = prefs.getString('userType');

    return {
      'isLoggedIn': isLoggedIn,
      'userType': userType,
    };
  }

  @override
  void dispose() {
    _introController.dispose();
    _splitController.dispose();
    super.dispose();
  }

  Widget _buildFullSplashContent(BuildContext context) {
    // Fade out logo and text in the first 35% of the splitting animation
    final double splitOpacity = (1.0 - (_splitAnimation.value / 0.35)).clamp(0.0, 1.0);

    return ColoredBox(
      color: const Color(0xFF003F7D),
      child: Opacity(
        opacity: splitOpacity,
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _introController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: 0.8 + (_logoScaleAnimation.value * 0.2),
                          child: Opacity(
                            opacity: _logoFadeAnimation.value,
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.local_shipping_outlined,
                          color: Colors.black,
                          size: 60,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    AnimatedBuilder(
                      animation: _introController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _logoFadeAnimation.value,
                          child: child,
                        );
                      },
                      child: Column(
                        children: const [
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
            const Padding(
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
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF003F7D),
      body: Stack(
        children: [
          // 1. Target Screen / Skeleton Screen revealed behind the splitting doors
          if (_backgroundWidget != null) _backgroundWidget!,

          // 2. The Splitting Splash Doors
          AnimatedBuilder(
            animation: _splitController,
            builder: (context, child) {
              final double offset = _splitAnimation.value * (size.height / 2);

              return Stack(
                children: [
                  // Top half of Splash Screen
                  Positioned(
                    top: -offset,
                    left: 0,
                    right: 0,
                    height: size.height / 2,
                    child: ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.topCenter,
                        maxHeight: size.height,
                        child: SizedBox(
                          width: size.width,
                          height: size.height,
                          child: _buildFullSplashContent(context),
                        ),
                      ),
                    ),
                  ),
                  // Bottom half of Splash Screen
                  Positioned(
                    bottom: -offset,
                    left: 0,
                    right: 0,
                    height: size.height / 2,
                    child: ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.bottomCenter,
                        maxHeight: size.height,
                        child: SizedBox(
                          width: size.width,
                          height: size.height,
                          child: _buildFullSplashContent(context),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

