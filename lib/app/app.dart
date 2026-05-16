import 'package:flutter/material.dart';
import '../features/onboarding/splash/splash_screen.dart';
import 'theme.dart';

class TripJioApp extends StatelessWidget {
  const TripJioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TripJio',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
    );
  }
}
