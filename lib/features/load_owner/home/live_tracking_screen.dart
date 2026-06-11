import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/load_owner_provider.dart';
import 'driver_arrived_screen.dart';

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

  @override
  void initState() {
    super.initState();
    // Set the driver we're tracking
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(trackedDriverIdProvider.notifier).state = widget.driverId;
    });
  }

  void _updateDriverMarker(LatLng position) {
    setState(() {
      _driverPosition = position;
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
          markerId: const MarkerId('pickup'),
          position: widget.pickupLocation,
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Your Location'),
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
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen to Supabase Realtime updates
    final locationStream =
        ref.watch(driverRealtimeLocationProvider(widget.driverId));

    locationStream.whenData((data) {
      final lat = (data['latitude'] as num?)?.toDouble();
      final lng = (data['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        final newPos = LatLng(lat, lng);
        _updateDriverMarker(newPos);

        // Check if driver has arrived (within 100m of pickup)
        if (_driverPosition != null) {
          final distance = _distanceInMeters(newPos, widget.pickupLocation);
          if (distance < 100) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    DriverArrivedScreen(driver: widget.driver),
              ),
            );
          }
        }
      }
    });

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
      ),
      body: Stack(
        children: [
          // Real Google Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.pickupLocation,
              zoom: 15,
            ),
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
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
                  Text(
                    locationStream.when(
                      data: (_) => 'Driver on the way',
                      loading: () => 'Connecting...',
                      error: (_, __) => 'Connection lost',
                    ),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  if (_driverPosition != null)
                    Text(
                      '${(_distanceInMeters(_driverPosition!, widget.pickupLocation) / 1000).toStringAsFixed(1)} km',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: _navy,
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
