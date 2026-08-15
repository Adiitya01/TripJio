import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

/// App-wide "No Internet" banner.
/// Slides down from the top when device goes offline; slides up when restored.
/// Wrap your home widget with this:
///   ConnectivityBanner(child: SplashScreen())
class ConnectivityBanner extends StatefulWidget {
  final Widget child;
  const ConnectivityBanner({super.key, required this.child});

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner> {
  bool _isOffline = false;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  @override
  void initState() {
    super.initState();
    _checkInitial();
    _sub = Connectivity()
        .onConnectivityChanged
        .listen(_handleConnectivityChange);
  }

  Future<void> _checkInitial() async {
    final results = await Connectivity().checkConnectivity();
    _handleConnectivityChange(results);
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final offline = results.every((r) => r == ConnectivityResult.none);
    if (offline != _isOffline && mounted) {
      setState(() => _isOffline = offline);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        // Banner slides in from top
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          top: _isOffline ? 0 : -60,
          left: 0,
          right: 0,
          child: Material(
            color: Colors.transparent,
            child: SafeArea(
              bottom: false,
              child: Container(
                color: Colors.red.shade700,
                padding: const EdgeInsets.symmetric(
                    vertical: 8, horizontal: 16),
                child: const Row(
                  children: [
                    Icon(Icons.wifi_off,
                        color: Colors.white, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'No internet connection',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
