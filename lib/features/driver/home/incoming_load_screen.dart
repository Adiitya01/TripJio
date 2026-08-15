import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/services/distance_service.dart';
import '../../../data/repositories/request_repository.dart';
import '../../../data/models/request_model.dart';
import 'trip_accepted_screen.dart';

const _navy = Color(0xFF003F7D);
const _navyLight = Color(0xFFE6EEF8);

class IncomingLoadScreen extends StatefulWidget {
  final RequestModel request;
  final String loadOwnerName;

  const IncomingLoadScreen({
    super.key,
    required this.request,
    required this.loadOwnerName,
  });

  @override
  State<IncomingLoadScreen> createState() => _IncomingLoadScreenState();
}

class _IncomingLoadScreenState extends State<IncomingLoadScreen> {
  int _secondsLeft = 120;
  Timer? _timer;
  bool _isResponding = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        t.cancel();
        Navigator.of(context).pop(); // auto-expire
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _timerText {
    final mins = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final secs = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  Future<void> _accept() async {
    setState(() => _isResponding = true);
    _timer?.cancel();
    try {
      // Atomic — marks request accepted, sets driver busy, creates trip
      final tripId =
          await RequestRepository().acceptRequestAtomic(widget.request.id);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => TripAcceptedScreen(
            request: widget.request,
            loadOwnerName: widget.loadOwnerName,
            tripId: tripId,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().contains('expired')
              ? 'Request expired'
              : 'Could not accept request. Please try again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() => _isResponding = false);
    }
  }

  Future<void> _reject() async {
    _timer?.cancel();
    await RequestRepository().respondToRequest(
      requestId: widget.request.id,
      accepted: false,
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final distLabel = DistanceService.distanceLabel(
      widget.request.pickupLat, widget.request.pickupLng,
      widget.request.dropLat, widget.request.dropLng,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 36),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _navyLight.withValues(alpha: 0.4),
                          ),
                        ),
                        Container(
                          width: 90,
                          height: 90,
                          decoration: const BoxDecoration(
                              shape: BoxShape.circle, color: _navyLight),
                        ),
                        Container(
                          width: 68,
                          height: 68,
                          decoration: const BoxDecoration(
                              shape: BoxShape.circle, color: _navy),
                          child: const Icon(Icons.notifications,
                              size: 36, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    const Text('New Load Request!',
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Expires in ',
                            style: TextStyle(
                                fontSize: 15, color: Colors.black54)),
                        Text(_timerText,
                            style: const TextStyle(
                                fontSize: 15,
                                color: _navy,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 28),
                    // Request details card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.grey.shade200),
                              child: const Icon(Icons.person,
                                  color: Colors.black54, size: 26),
                            ),
                            const SizedBox(width: 12),
                            Text(widget.loadOwnerName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.black87)),
                          ]),
                          const SizedBox(height: 18),
                          _DotRow(
                            label: 'PICKUP',
                            value: widget.request.pickupAddress,
                            dotColor: _navy,
                          ),
                          const SizedBox(height: 12),
                          _DotRow(
                            label: 'DROP',
                            value: widget.request.dropAddress,
                            dotColor: const Color(0xFF2ECC71),
                          ),
                          const SizedBox(height: 18),
                          Row(children: [
                            Expanded(
                              child: _LabelValue(
                                label: 'LOAD',
                                value: widget.request.weightKg != null
                                    ? '${widget.request.weightKg!.round()} kg'
                                    : 'N/A',
                              ),
                            ),
                            Expanded(
                              child: _LabelValue(
                                  label: 'DISTANCE', value: distLabel),
                            ),
                          ]),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              decoration: BoxDecoration(
                color: Colors.white,
                border:
                    Border(top: BorderSide(color: Colors.grey.shade100)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isResponding ? null : _reject,
                      icon: const Icon(Icons.close,
                          color: Colors.red, size: 20),
                      label: const Text('Reject',
                          style: TextStyle(
                              color: Colors.red,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isResponding ? null : _accept,
                      icon: _isResponding
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.check,
                              color: Colors.white, size: 20),
                      label: Text(_isResponding ? '...' : 'Accept',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A7A4A),
                        disabledBackgroundColor: Colors.grey.shade300,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DotRow extends StatelessWidget {
  final String label;
  final String value;
  final Color dotColor;

  const _DotRow(
      {required this.label,
      required this.value,
      required this.dotColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                shape: BoxShape.circle, color: dotColor),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11,
                      color: Colors.black45,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5)),
              const SizedBox(height: 3),
              Text(value,
                  style: const TextStyle(
                      fontSize: 15,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }
}

class _LabelValue extends StatelessWidget {
  final String label;
  final String value;

  const _LabelValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                color: Colors.black45,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87)),
      ],
    );
  }
}
