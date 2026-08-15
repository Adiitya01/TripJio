import 'dart:async';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../data/models/trip_model.dart';
import '../../../data/repositories/trip_repository.dart';
import '../providers/load_owner_provider.dart';
import 'load_owner_home_screen.dart';
import 'trip_completed_screen.dart';

class LiveTrackingScreen extends ConsumerStatefulWidget {
  final dynamic driver;
  final String driverId;
  final LatLng pickupLocation;
  final String requestId;

  const LiveTrackingScreen({
    super.key,
    required this.driver,
    required this.driverId,
    required this.pickupLocation,
    required this.requestId,
  });

  @override
  ConsumerState<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends ConsumerState<LiveTrackingScreen> {
  static const Color _navy = Color(0xFF003F7D);
  static const Color _navyLight = Color(0xFFE6EEF8);

  GoogleMapController? _mapController;
  LatLng? _driverPosition;
  Set<Marker> _markers = {};
  final List<LatLng> _trace = [];
  Set<Polyline> _polylines = {};

  TripModel? _trip;
  LatLng? _dropLocation;
  bool _navigatedAway = false;
  Timer? _statusPoll;

  @override
  void initState() {
    super.initState();
    // Set the driver we're tracking
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(trackedDriverIdProvider.notifier).state = widget.driverId;
    });
    _loadActiveTrip();
    // Realtime is the primary signal; this poll is a safety net in case the
    // websocket drops mid-trip (poor network, OS backgrounding).
    _statusPoll = Timer.periodic(
        const Duration(seconds: 5), (_) => _pollTripStatus());
  }

  Future<void> _loadActiveTrip() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final trip = await TripRepository().getActiveTripForUser(uid);
      if (!mounted) return;
      if (trip == null) {
        // No active trip — best assumption is the driver completed it before
        // we finished initializing. We can't tell cancelled vs completed
        // without a row, so default to the completion screen rather than
        // stranding the load owner here.
        _exitToCompletion();
        return;
      }
      setState(() {
        _trip = trip;
        _dropLocation = LatLng(trip.dropLat, trip.dropLng);
      });
    } catch (_) {/* network glitch; poll/stream will catch up */}
  }

  Future<void> _pollTripStatus() async {
    if (_navigatedAway || !mounted) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final trip = await TripRepository().getActiveTripForUser(uid);
      if (!mounted || _navigatedAway) return;
      if (trip == null) {
        // Active trip is gone — Realtime may have missed the final event. Look
        // up the specific trip row to distinguish cancelled from completed.
        final knownId = _trip?.id;
        if (knownId != null) {
          try {
            final row = await TripRepository()
                .getTripById(knownId);
            if (row?.status == 'cancelled') {
              _exitToHomeCancelled();
              return;
            }
          } catch (_) {/* fall through to completion */}
        }
        _exitToCompletion();
        return;
      }
      // Catch up on pickup confirmation if Realtime missed the event.
      if (_trip?.pickupConfirmedAt == null &&
          trip.pickupConfirmedAt != null) {
        setState(() {
          _trip = trip;
          _dropLocation = LatLng(trip.dropLat, trip.dropLng);
        });
        if (_driverPosition != null) _updateDriverMarker(_driverPosition!);
      } else {
        _trip = trip;
        _dropLocation ??= LatLng(trip.dropLat, trip.dropLng);
      }
    } catch (_) {/* try again on next tick */}
  }

  void _exitToCompletion() {
    if (_navigatedAway) return;
    _navigatedAway = true;
    _statusPoll?.cancel();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => TripCompletedScreen(
          driverName: widget.driver.name as String?,
        ),
      ),
    );
  }

  void _exitToHomeCancelled() {
    if (_navigatedAway) return;
    _navigatedAway = true;
    _statusPoll?.cancel();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoadOwnerHomeScreen()),
      (_) => false,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Trip was cancelled.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  bool get _hasReachedPickup => _trip?.pickupConfirmedAt != null;

  LatLng get _targetLocation =>
      _hasReachedPickup && _dropLocation != null
          ? _dropLocation!
          : widget.pickupLocation;

  String get _targetMarkerTitle =>
      _hasReachedPickup ? 'Drop location' : 'Your location';

  void _updateDriverMarker(LatLng position) {
    setState(() {
      _driverPosition = position;
      if (_trace.isEmpty ||
          _distanceInMeters(_trace.last, position) >= 8) {
        _trace.add(position);
        if (_trace.length > 500) {
          _trace.removeRange(0, _trace.length - 500);
        }
      }
      _polylines = _trace.length >= 2
          ? {
              Polyline(
                polylineId: const PolylineId('driver_trace'),
                points: List<LatLng>.from(_trace),
                color: _navy,
                width: 5,
                startCap: Cap.roundCap,
                endCap: Cap.roundCap,
                jointType: JointType.round,
              ),
            }
          : <Polyline>{};
      _markers = {
        Marker(
          markerId: const MarkerId('driver'),
          position: position,
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueAzure),
          infoWindow: InfoWindow(
            title: widget.driver.name ?? 'Driver',
            snippet: widget.driver.vehicle ?? '',
          ),
        ),
        Marker(
          markerId: const MarkerId('target'),
          position: _targetLocation,
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(title: _targetMarkerTitle),
        ),
      };
    });
    // Animate camera to follow driver
    _mapController?.animateCamera(
      CameraUpdate.newLatLng(position),
    );
  }

  @override
  void dispose() {
    _statusPoll?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen to Supabase Realtime updates. Use ref.listen so setState fires
    // outside of build; ref.watch here only reads the current AsyncValue for
    // banner/spinner rendering.
    final locationStream =
        ref.watch(driverRealtimeLocationProvider(widget.driverId));
    ref.listen(driverRealtimeLocationProvider(widget.driverId), (_, next) {
      next.whenData((data) {
        final lat = (data['latitude'] as num?)?.toDouble();
        final lng = (data['longitude'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          _updateDriverMarker(LatLng(lat, lng));
        }
      });
    });

    // Watch the trip itself so we can pivot to the drop leg when the
    // driver confirms pickup, and navigate to the completion screen
    // when the driver marks the trip complete.
    final tripId = _trip?.id;
    if (tripId != null) {
      ref.listen(tripStatusStreamProvider(tripId), (_, next) {
        next.whenData((trip) {
          if (!mounted) return;
          final justConfirmedPickup = _trip?.pickupConfirmedAt == null &&
              trip.pickupConfirmedAt != null;
          setState(() {
            _trip = trip;
            _dropLocation = LatLng(trip.dropLat, trip.dropLng);
          });
          if (justConfirmedPickup && _driverPosition != null) {
            // Refresh markers/banner for the new target.
            _updateDriverMarker(_driverPosition!);
          }
          if (trip.status == 'completed') {
            _exitToCompletion();
          } else if (trip.status == 'cancelled') {
            _exitToHomeCancelled();
          }
        });
      });
    }

    // Banner state derived from trip + GPS proximity.
    final String bannerText;
    if (_trip?.status == 'completed') {
      bannerText = 'Trip completed';
    } else if (_hasReachedPickup) {
      bannerText = 'In transit to drop';
    } else if (_driverPosition != null &&
        _distanceInMeters(_driverPosition!, widget.pickupLocation) < 100) {
      bannerText = 'Driver arrived — awaiting pickup confirmation';
    } else {
      bannerText = locationStream.when(
        data: (_) => 'Driver on the way',
        loading: () => 'Connecting...',
        error: (_, __) => 'Connection lost',
      );
    }

    final String driverName = widget.driver.name ?? 'Driver';
    final String vehicleInfo = widget.driver.vehicle ?? '';
    final String vehicleNumber = widget.driver.number ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Live Tracking',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.cancel_outlined, color: Colors.red),
            tooltip: 'Cancel Trip',
            onPressed: () => _cancelTrip(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Real Google Map (Uber-style optimizations)
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.pickupLocation,
              zoom: 15,
            ),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            buildingsEnabled: false,
            trafficEnabled: false,
            indoorViewEnabled: false,
            compassEnabled: false,
            rotateGesturesEnabled: false,
            tiltGesturesEnabled: false,
            onMapCreated: (controller) {
              _mapController = controller;
            },
          ),

          // Top status banner
          Positioned(
            top: 16,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  locationStream.when(
                    data: (_) => const _PulseDot(),
                    loading: () => const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _navy),
                    ),
                    error: (_, __) => const Icon(Icons.error_outline,
                        size: 16, color: Colors.red),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      bannerText,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom driver info card
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 15,
                    offset: Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: _navyLight,
                      ),
                      child:
                          const Icon(Icons.person, color: _navy, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            driverName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$vehicleInfo · $vehicleNumber',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFE8F5E9),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.phone,
                            color: Color(0xFF2ECC71), size: 20),
                        onPressed: () async {
                          final phone = widget.driver.phone ?? '';
                          if (phone.isEmpty) return;
                          final uri = Uri.parse('tel:$phone');
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelTrip(BuildContext context) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Cancel this trip?',
      message: 'The driver will be notified. You can request a new driver after cancelling.',
      confirmText: 'Cancel Trip',
      cancelText: 'Keep Trip',
      isDestructive: true,
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in again to cancel this trip.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    try {
      // Find active trip and cancel it
      final trip = await TripRepository().getActiveTripForUser(uid);
      if (trip != null) {
        await TripRepository().updateStatus(trip.id, 'cancelled');
      }
    } catch (_) {/* ignore */}

    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoadOwnerHomeScreen()),
      (_) => false,
    );
  }

  double _distanceInMeters(LatLng a, LatLng b) {
    const double earthRadius = 6371000;
    final double dLat = _deg2rad(b.latitude - a.latitude);
    final double dLng = _deg2rad(b.longitude - a.longitude);
    final double sinHalfDlat = math.sin(dLat / 2);
    final double sinHalfDlng = math.sin(dLng / 2);
    final double x = sinHalfDlat * sinHalfDlat +
        math.cos(_deg2rad(a.latitude)) *
            math.cos(_deg2rad(b.latitude)) *
            sinHalfDlng *
            sinHalfDlng;
    final double c = 2 * math.atan2(math.sqrt(x), math.sqrt(1 - x));
    return earthRadius * c;
  }

  double _deg2rad(double deg) => deg * (math.pi / 180.0);
}

// Pulsing green dot widget
class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.6, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color:
              Color.fromRGBO(46, 204, 113, _anim.value),
        ),
      ),
    );
  }
}
