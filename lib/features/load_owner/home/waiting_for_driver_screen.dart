import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../data/repositories/request_repository.dart';
import '../../../data/models/request_model.dart';
import 'request_accepted_screen.dart';

class WaitingForDriverScreen extends ConsumerStatefulWidget {
  final dynamic driver;
  final String driverId;
  final LatLng pickupLocation;
  final String requestId;

  const WaitingForDriverScreen({
    super.key,
    required this.driver,
    required this.driverId,
    required this.pickupLocation,
    required this.requestId,
  });

  @override
  ConsumerState<WaitingForDriverScreen> createState() =>
      _WaitingForDriverScreenState();
}

class _WaitingForDriverScreenState extends ConsumerState<WaitingForDriverScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Timer _timer;
  int _secondsLeft = 120; // 2 minutes to match request expiry
  StreamSubscription<RequestModel>? _requestSub;

  static const Color _navy = Color(0xFF003F7D);
  static const Color _navyLight = Color(0xFFE6EEF8);

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Countdown timer — auto-cancel when expires
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft > 0) {
        setState(() => _secondsLeft--);
      } else {
        timer.cancel();
        _cancelRequest();
      }
    });

    // Listen to Supabase Realtime for request acceptance
    _requestSub = RequestRepository()
        .listenToRequestStatus(widget.requestId)
        .listen((request) {
      if (!mounted) return;
      if (request.status == 'accepted') {
        _timer.cancel();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => RequestAcceptedScreen(
              driver: widget.driver,
              driverId: widget.driverId,
              pickupLocation: widget.pickupLocation,
              requestId: widget.requestId,
            ),
          ),
        );
      } else if (request.status == 'rejected') {
        _timer.cancel();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Driver rejected the request. Try another driver.'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context);
        }
      }
    });
  }

  Future<void> _cancelRequest() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    try {
      await RequestRepository().cancelRequestByLoadOwner(
        requestId: widget.requestId,
        callerId: uid,
      );
    } catch (e) {
      // If driver accepted at the exact moment, server refuses
      if (!mounted) return;
      if (e.toString().contains('already accepted')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Driver just accepted — going to tracking'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return; // let the realtime listener navigate us forward
      }
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _timer.cancel();
    _requestSub?.cancel();
    super.dispose();
  }

  String _formatTime(int totalSeconds) {
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final String driverName = widget.driver.name ?? 'Driver';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.black87),
                  onPressed: _cancelRequest,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ScaleTransition(
                      scale: Tween<double>(begin: 0.92, end: 1.08).animate(
                        CurvedAnimation(
                            parent: _pulseController,
                            curve: Curves.easeInOut),
                      ),
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _navyLight.withValues(alpha: 0.5),
                        ),
                        child: Center(
                          child: Container(
                            width: 110,
                            height: 110,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: _navy,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x33003F7D),
                                  blurRadius: 16,
                                  spreadRadius: 4,
                                )
                              ],
                            ),
                            child: const Icon(Icons.alarm_rounded,
                                size: 56, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                    const Text(
                      'Waiting for response',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '$driverName is reviewing your request',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 16, color: Colors.black54, height: 1.5),
                    ),
                    const SizedBox(height: 40),
                    const Text('Auto-cancel in',
                        style: TextStyle(
                            fontSize: 14,
                            color: Colors.black38,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    Text(
                      _formatTime(_secondsLeft),
                      style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: _navy,
                          letterSpacing: 1),
                    ),
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24.0, vertical: 16.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton(
                    onPressed: _cancelRequest,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                          color: Colors.redAccent, width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(27)),
                    ),
                    child: const Text(
                      'Cancel Request',
                      style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
