import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/distance_service.dart';
import '../../../data/repositories/trip_repository.dart';
import '../../../data/models/request_model.dart';
import '../../../data/models/trip_model.dart';
import 'trip_in_progress_screen.dart';

const _navy = Color(0xFF003F7D);
const _navyLight = Color(0xFFE6EEF8);
const _green = Color(0xFF1A7A4A);

class TripAcceptedScreen extends ConsumerStatefulWidget {
  final RequestModel request;
  final String loadOwnerName;
  final String tripId; // Pre-created by accept_request_and_create_trip RPC

  const TripAcceptedScreen({
    super.key,
    required this.request,
    required this.loadOwnerName,
    required this.tripId,
  });

  @override
  ConsumerState<TripAcceptedScreen> createState() =>
      _TripAcceptedScreenState();
}

class _TripAcceptedScreenState extends ConsumerState<TripAcceptedScreen> {
  bool _isStarting = false;

  String get _distanceLabel => DistanceService.distanceLabel(
        widget.request.pickupLat,
        widget.request.pickupLng,
        widget.request.dropLat,
        widget.request.dropLng,
      );

  Future<void> _startTrip() async {
    setState(() => _isStarting = true);
    try {
      // Trip was already created atomically when accepting — just fetch and
      // mark it as in_progress.
      await TripRepository()
          .updateStatus(widget.tripId, 'in_progress');

      // Build a local TripModel from the request data we already have
      final trip = TripModel(
        id: widget.tripId,
        loadOwnerId: widget.request.loadOwnerId,
        driverId: widget.request.driverId,
        pickupAddress: widget.request.pickupAddress,
        dropAddress: widget.request.dropAddress,
        pickupLat: widget.request.pickupLat,
        pickupLng: widget.request.pickupLng,
        dropLat: widget.request.dropLat,
        dropLng: widget.request.dropLng,
        status: 'in_progress',
        distanceKm: null,
        goodsDescription: widget.request.goodsDescription,
        weightKg: widget.request.weightKg,
        createdAt: DateTime.now(),
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => TripInProgressScreen(trip: trip),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to start trip. Check your connection and try again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  Future<void> _cancelTrip() async {
    try {
      // Trip was already created atomically when the request was accepted, so
      // cancel the trip (which also releases the driver's is_busy flag) rather
      // than the request row.
      await TripRepository().updateStatus(widget.tripId, 'cancelled');
    } catch (_) {/* surface via home; still pop */}
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Green confirmed banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 18),
              color: _green,
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                    child: const Icon(Icons.check,
                        color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Trip Confirmed',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18)),
                      SizedBox(height: 2),
                      Text('Head to pickup location',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const SizedBox(height: 4),
                    // Contact card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey.shade200,
                            ),
                            child: const Icon(Icons.person,
                                color: Colors.black54, size: 28),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(widget.loadOwnerName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.black87)),
                                const SizedBox(height: 3),
                                const Text('Load Owner',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Pickup + Drop card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.only(top: 4),
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _navy),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    const Text('PICKUP',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.black45,
                                            fontWeight:
                                                FontWeight.w600,
                                            letterSpacing: 0.5)),
                                    const SizedBox(height: 3),
                                    Text(
                                        widget.request.pickupAddress,
                                        style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight:
                                                FontWeight.w600,
                                            color: Colors.black87)),
                                    const SizedBox(height: 2),
                                    Text(_distanceLabel,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            color: _navy,
                                            fontWeight:
                                                FontWeight.w500)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(
                                left: 4, top: 6, bottom: 6),
                            child: Container(
                                width: 2,
                                height: 20,
                                color: Colors.grey.shade300),
                          ),
                          Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.only(top: 4),
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0xFF2ECC71)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    const Text('DROP',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.black45,
                                            fontWeight:
                                                FontWeight.w600,
                                            letterSpacing: 0.5)),
                                    const SizedBox(height: 3),
                                    Text(
                                        widget.request.dropAddress,
                                        style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight:
                                                FontWeight.w600,
                                            color: Colors.black87)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Load details
                    if (widget.request.goodsDescription != null ||
                        widget.request.weightKg != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _navyLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('LOAD DETAILS',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.black45,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5)),
                            const SizedBox(height: 6),
                            Text(
                              [
                                if (widget.request.weightKg != null)
                                  '${widget.request.weightKg!.round()} kg',
                                if (widget.request.goodsDescription !=
                                    null)
                                  widget.request.goodsDescription!,
                              ].join(' · '),
                              style: const TextStyle(
                                  fontSize: 14, color: Colors.black87),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                    top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _cancelTrip,
                      icon: const Icon(Icons.close,
                          color: Colors.black87, size: 18),
                      label: const Text('Cancel',
                          style: TextStyle(
                              color: Colors.black87,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            vertical: 14),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _isStarting ? null : _startTrip,
                      icon: _isStarting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.navigation_outlined,
                              color: Colors.white, size: 18),
                      label: Text(
                          _isStarting ? 'Starting...' : 'Start Trip',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _navy,
                        disabledBackgroundColor: Colors.grey.shade300,
                        padding: const EdgeInsets.symmetric(
                            vertical: 14),
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
