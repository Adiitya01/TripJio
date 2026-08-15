import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/services/distance_service.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../data/repositories/trip_repository.dart';
import '../../../data/models/trip_model.dart';
import '../../load_owner/providers/load_owner_provider.dart';
import 'driver_home_screen.dart';
import 'drop_gate.dart';

const _navy = Color(0xFF003F7D);

const DropGate _gate = DropGate();

class TripInProgressScreen extends ConsumerStatefulWidget {
  final TripModel trip;

  const TripInProgressScreen({super.key, required this.trip});

  @override
  ConsumerState<TripInProgressScreen> createState() =>
      _TripInProgressScreenState();
}

class _TripInProgressScreenState
    extends ConsumerState<TripInProgressScreen> {
  GoogleMapController? _mapController;
  LatLng? _currentPosition;
  bool _isBusy = false;
  bool _hasReachedPickup = false;
  bool _exitedOnCancellation = false;

  late LatLng _pickup;
  late LatLng _drop;

  // Breadcrumb trail of driver positions for the map polyline.
  final List<LatLng> _trace = [];

  StreamSubscription<Position>? _locationSub;
  DateTime? _softGateStartedAt;
  Timer? _softGateTicker;

  @override
  void initState() {
    super.initState();
    _pickup = LatLng(widget.trip.pickupLat, widget.trip.pickupLng);
    _drop = LatLng(widget.trip.dropLat, widget.trip.dropLng);
    // Resume the right leg if the app was killed mid-trip.
    _hasReachedPickup = widget.trip.pickupConfirmedAt != null;
    _startLocationTracking();

    // Only transition into in_progress if we're actually resuming from
    // 'accepted'. Trips already in_progress/completed/cancelled must not be
    // overwritten (e.g. app relaunched during the drop leg).
    if (widget.trip.status == 'accepted') {
      TripRepository().updateStatus(widget.trip.id, 'in_progress');
    }
  }

  void _startLocationTracking() {
    _locationSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high, distanceFilter: 10),
    ).listen((position) {
      if (!mounted) return;
      final next = LatLng(position.latitude, position.longitude);
      setState(() {
        _currentPosition = next;
        // Keep the trace bounded so we don't grow unbounded over a long trip.
        if (_trace.isEmpty ||
            _distanceMeters(_trace.last, next) >= 8) {
          _trace.add(next);
          if (_trace.length > 500) {
            _trace.removeRange(0, _trace.length - 500);
          }
        }
      });
      _refreshSoftGate();
      _mapController?.animateCamera(CameraUpdate.newLatLng(next));
    });
  }

  LatLng get _target => _hasReachedPickup ? _drop : _pickup;

  double get _distanceToTargetMeters {
    if (_currentPosition == null) return double.infinity;
    return _distanceMeters(_currentPosition!, _target);
  }

  bool get _isWithinSoftRadius =>
      _gate.isWithinSoftRadius(_distanceToTargetMeters);

  bool get _isAtTarget {
    // Soft fallback only applies on the drop leg — pickup confirmation is
    // not gated by radius (driver just taps "I've Reached Pickup").
    if (!_hasReachedPickup) {
      return _distanceToTargetMeters <= _gate.arriveRadiusMeters;
    }
    return _gate.isAtTarget(
      distanceMeters: _distanceToTargetMeters,
      softGateStartedAt: _softGateStartedAt,
      now: DateTime.now(),
    );
  }

  void _refreshSoftGate() {
    if (!_hasReachedPickup) return;
    final inSoftZone = _isWithinSoftRadius;
    final inHardZone = _distanceToTargetMeters <= _gate.arriveRadiusMeters;
    if (inSoftZone && !inHardZone) {
      _softGateStartedAt ??= DateTime.now();
      _softGateTicker ??= Timer.periodic(
          const Duration(seconds: 10), (_) => setState(() {}));
    } else if (!inSoftZone) {
      _softGateStartedAt = null;
      _softGateTicker?.cancel();
      _softGateTicker = null;
    }
  }

  Future<void> _onPrimaryTap() async {
    if (_hasReachedPickup) {
      await _completeTrip();
    } else {
      await _markPickedUp();
    }
  }

  Future<void> _markPickedUp() async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Confirm pickup?',
      message:
          "Confirm that you've reached the pickup location and loaded the goods. The load owner will be notified.",
      confirmText: 'Confirm Pickup',
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isBusy = true);
    try {
      await TripRepository().markPickupConfirmed(widget.trip.id);
      if (!mounted) return;
      setState(() {
        _hasReachedPickup = true;
        // Reset the trace so the drop leg is drawn fresh from the pickup point.
        _trace
          ..clear()
          ..add(_currentPosition ?? _pickup);
      });
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_drop, 14),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Could not confirm pickup. Check your connection and try again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _completeTrip() async {
    if (!_isAtTarget) return;
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Mark trip as complete?',
      message:
          "Confirm that you've reached the drop location and delivered the goods. The load owner will be notified.",
      confirmText: 'Complete Trip',
    );
    if (confirmed != true || !mounted) return;

    await _submitCompletion(
        () => TripRepository().updateStatus(widget.trip.id, 'completed'));
  }

  /// Manual override for when the pinned drop point is wrong or the site is
  /// larger than the arrival radius: completes the trip but flags it for
  /// review and records the driver's actual position.
  Future<void> _completeTripFlagged() async {
    final pos = _currentPosition;
    if (pos == null) return;
    final distanceM = _distanceToTargetMeters;
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Complete away from drop point?',
      message:
          'You are $_distanceLabel from the pinned drop location. The trip '
          'will be completed and flagged for review, and your current '
          'location will be recorded. Only use this if the drop pin is wrong.',
      confirmText: 'Complete & Flag',
      isDestructive: true,
    );
    if (confirmed != true || !mounted) return;

    await _submitCompletion(() => TripRepository().completeTripFlagged(
          tripId: widget.trip.id,
          lat: pos.latitude,
          lng: pos.longitude,
          distanceMeters: distanceM,
        ));
  }

  Future<void> _submitCompletion(Future<void> Function() action) async {
    setState(() => _isBusy = true);
    try {
      await action();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const DriverHomeScreen()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Failed to complete trip. Check your connection and try again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Set<Marker> get _markers {
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('pickup'),
        position: _pickup,
        icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure),
        infoWindow: InfoWindow(
            title: 'Pickup', snippet: widget.trip.pickupAddress),
      ),
      Marker(
        markerId: const MarkerId('drop'),
        position: _drop,
        icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(
            title: 'Drop', snippet: widget.trip.dropAddress),
      ),
    };
    if (_currentPosition != null) {
      markers.add(Marker(
        markerId: const MarkerId('driver'),
        position: _currentPosition!,
        icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: 'You'),
      ));
    }
    return markers;
  }

  Set<Polyline> get _polylines {
    final lines = <Polyline>{};
    if (_trace.length >= 2) {
      lines.add(Polyline(
        polylineId: const PolylineId('trace'),
        points: List<LatLng>.from(_trace),
        color: _navy,
        width: 5,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
      ));
    }
    return lines;
  }

  String get _distanceLabel {
    if (_currentPosition == null) return '...';
    return DistanceService.distanceLabel(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      _target.latitude,
      _target.longitude,
    );
  }

  String get _eta {
    if (_currentPosition == null) return '...';
    final km = DistanceService.distanceInKm(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      _target.latitude,
      _target.longitude,
    );
    return DistanceService.etaLabel(km);
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _softGateTicker?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _handleTripCancelledByOwner() {
    if (_exitedOnCancellation || !mounted) return;
    _exitedOnCancellation = true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('The load owner cancelled this trip.'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const DriverHomeScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // React to load-owner cancellation: pop back to home with a snackbar.
    ref.listen(tripStatusStreamProvider(widget.trip.id), (_, next) {
      next.whenData((trip) {
        if (trip.status == 'cancelled') {
          _handleTripCancelledByOwner();
        }
      });
    });

    final headingLabel =
        _hasReachedPickup ? 'DISTANCE TO DROP' : 'DISTANCE TO PICKUP';
    final destAddress = _hasReachedPickup
        ? widget.trip.dropAddress
        : widget.trip.pickupAddress;

    final String primaryLabel;
    final bool primaryEnabled;
    String? softGateHint;
    if (_hasReachedPickup) {
      primaryLabel = _isAtTarget
          ? 'Complete Trip'
          : 'Drive to drop location';
      primaryEnabled = _isAtTarget && !_isBusy;
      // Tell the driver about the GPS-jitter fallback so they don't think
      // the app is broken at an underground / indoor drop site.
      if (!_isAtTarget &&
          _isWithinSoftRadius &&
          _softGateStartedAt != null) {
        final elapsed = DateTime.now().difference(_softGateStartedAt!);
        final remaining = _gate.softGateWait - elapsed;
        if (remaining > Duration.zero) {
          final mins = remaining.inMinutes;
          final secs = remaining.inSeconds % 60;
          softGateHint =
              'Near drop — GPS-lock unlock in ${mins}m ${secs.toString().padLeft(2, '0')}s';
        }
      }
    } else {
      primaryLabel = "I've Reached Pickup";
      primaryEnabled = !_isBusy;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition:
                      CameraPosition(target: _pickup, zoom: 14),
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
                  onMapCreated: (c) => _mapController = c,
                ),
                Positioned(
                  top: MediaQuery.of(context).padding.top + 14,
                  left: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [
                        BoxShadow(
                            color: Colors.black12,
                            blurRadius: 8,
                            offset: Offset(0, 2))
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(headingLabel,
                            style: const TextStyle(
                                fontSize: 10,
                                color: Colors.black45,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5)),
                        const SizedBox(height: 4),
                        Text(_distanceLabel,
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: _navy)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                    color: Colors.black12,
                    blurRadius: 12,
                    offset: Offset(0, -4))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('GOING TO',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.black45,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5)),
                const SizedBox(height: 4),
                Text(destAddress,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
                const SizedBox(height: 4),
                Text('ETA: $_eta',
                    style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF1A7A4A),
                        fontWeight: FontWeight.w600)),
                if (softGateHint != null) ...[
                  const SizedBox(height: 6),
                  Text(softGateHint,
                      style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                          fontWeight: FontWeight.w500)),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: primaryEnabled ? _onPrimaryTap : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _navy,
                      disabledBackgroundColor: Colors.grey.shade300,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28)),
                      elevation: 0,
                    ),
                    child: _isBusy
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5))
                        : Text(primaryLabel,
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600)),
                  ),
                ),
                // Escape hatch when the drop pin is wrong: only offered on the
                // drop leg, outside the soft-gate radius (inside it the timed
                // unlock already applies), and with a GPS fix to record.
                if (_hasReachedPickup &&
                    !_isAtTarget &&
                    !_isWithinSoftRadius &&
                    _currentPosition != null &&
                    !_isBusy) ...[
                  const SizedBox(height: 6),
                  Center(
                    child: TextButton(
                      onPressed: _completeTripFlagged,
                      child: const Text(
                        'Drop pin wrong? Complete & flag for review',
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

double _distanceMeters(LatLng a, LatLng b) {
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
