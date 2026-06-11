import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/services/distance_service.dart';
import '../../../data/repositories/trip_repository.dart';
import '../../../data/models/trip_model.dart';
import 'driver_home_screen.dart';

const _navy = Color(0xFF003F7D);

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
  bool _isCompleting = false;

  late LatLng _pickup;
  late LatLng _drop;

  @override
  void initState() {
    super.initState();
    _pickup = LatLng(
        widget.trip.pickupLat, widget.trip.pickupLng);
    _drop = LatLng(widget.trip.dropLat, widget.trip.dropLng);
    _startLocationTracking();

    // Mark trip as in_progress in Supabase
    TripRepository().updateStatus(widget.trip.id, 'in_progress');
  }

  void _startLocationTracking() {
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high, distanceFilter: 10),
    ).listen((position) {
      if (!mounted) return;
      setState(() {
        _currentPosition =
            LatLng(position.latitude, position.longitude);
      });
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(_currentPosition!),
      );
    });
  }

  Future<void> _completeTrip() async {
    setState(() => _isCompleting = true);
    try {
      await TripRepository()
          .updateStatus(widget.trip.id, 'completed');
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
            builder: (_) => const DriverHomeScreen()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to complete trip: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isCompleting = false);
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
            title: 'Pickup',
            snippet: widget.trip.pickupAddress),
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

  String get _distanceToPickup {
    if (_currentPosition == null) return '...';
    return DistanceService.distanceLabel(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      _pickup.latitude,
      _pickup.longitude,
    );
  }

  String get _eta {
    if (_currentPosition == null) return '...';
    final km = DistanceService.distanceInKm(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      _pickup.latitude,
      _pickup.longitude,
    );
    return DistanceService.etaLabel(km);
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                      target: _pickup, zoom: 14),
                  markers: _markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  onMapCreated: (c) => _mapController = c,
                ),
                // Distance to pickup — top left
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
                        const Text('DISTANCE TO PICKUP',
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.black45,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5)),
                        const SizedBox(height: 4),
                        Text(_distanceToPickup,
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
          // Bottom info + button
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
                Text(widget.trip.pickupAddress,
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
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed:
                        _isCompleting ? null : _completeTrip,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _navy,
                      disabledBackgroundColor:
                          Colors.grey.shade300,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(28)),
                      elevation: 0,
                    ),
                    child: _isCompleting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5))
                        : const Text("I've Reached Pickup",
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
