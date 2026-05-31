import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

const _navy = Color(0xFF003F7D);

class DriverMapScreen extends StatefulWidget {
  const DriverMapScreen({super.key});

  @override
  State<DriverMapScreen> createState() => _DriverMapScreenState();
}

class _DriverMapScreenState extends State<DriverMapScreen> {
  GoogleMapController? _mapController;
  LatLng? _currentPosition;
  bool _loadingLocation = true;
  int _selectedIndex = 0;
  Set<Marker> _markers = {};

  // Hardcoded load data (will come from Supabase in Phase 6)
  static const _loads = [
    _LoadInfo(company: 'Rajesh Textiles', distance: '2.4 km', type: 'LCV · 800kg'),
    _LoadInfo(company: 'Mehta Traders', distance: '4.1 km', type: 'Mini · 400kg'),
    _LoadInfo(company: 'Singh Logistics', distance: '6.2 km', type: 'HCV · 2000kg'),
  ];

  // Offsets from driver's current position (lat, lng)
  static const _pinOffsets = [
    Offset(0.018, -0.021),
    Offset(-0.016, 0.028),
    Offset(0.012, 0.035),
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _loadingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _loadingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _loadingLocation = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final current = LatLng(position.latitude, position.longitude);

      setState(() {
        _currentPosition = current;
        _loadingLocation = false;
        _markers = _buildMarkers(current);
      });

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(current, 14),
      );
    } catch (e) {
      setState(() => _loadingLocation = false);
    }
  }

  Set<Marker> _buildMarkers(LatLng center) {
    return Set.from(
      List.generate(_loads.length, (i) {
        return Marker(
          markerId: MarkerId('load_$i'),
          position: LatLng(
            center.latitude + _pinOffsets[i].dx,
            center.longitude + _pinOffsets[i].dy,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            i == _selectedIndex
                ? BitmapDescriptor.hueAzure
                : BitmapDescriptor.hueRed,
          ),
          infoWindow: InfoWindow(
            title: _loads[i].company,
            snippet: '${_loads[i].distance} · ${_loads[i].type}',
          ),
          onTap: () => setState(() {
            _selectedIndex = i;
            _markers = _buildMarkers(center);
          }),
        );
      }),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Fallback center (Mumbai) if GPS unavailable
    final mapCenter = _currentPosition ?? const LatLng(19.0760, 72.8777);

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
          'Loads Near Me',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Map ────────────────────────────────────────────────────────
          Expanded(
            child: Stack(
              children: [
                _loadingLocation
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: _navy),
                            SizedBox(height: 16),
                            Text(
                              'Getting your location...',
                              style: TextStyle(color: Colors.black54),
                            ),
                          ],
                        ),
                      )
                    : GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: mapCenter,
                          zoom: 14,
                        ),
                        onMapCreated: (controller) {
                          _mapController = controller;
                        },
                        markers: _markers,
                        myLocationEnabled: true,
                        myLocationButtonEnabled: true,
                        zoomControlsEnabled: false,
                        mapToolbarEnabled: false,
                      ),

                // Filter chips
                if (!_loadingLocation)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Row(
                      children: [
                        _FilterChip(label: '${_loads.length} Loads'),
                        const SizedBox(width: 8),
                        const _FilterChip(label: '≤ 5 km'),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // ── Selected load card ─────────────────────────────────────────
          _SelectedLoadCard(
            load: _loads[_selectedIndex],
            onView: () {},
          ),
        ],
      ),
    );
  }
}

// ── Data & Sub-widgets ────────────────────────────────────────────────────────

class _LoadInfo {
  final String company;
  final String distance;
  final String type;

  const _LoadInfo({
    required this.company,
    required this.distance,
    required this.type,
  });
}

class _FilterChip extends StatelessWidget {
  final String label;
  const _FilterChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
    );
  }
}

class _SelectedLoadCard extends StatelessWidget {
  final _LoadInfo load;
  final VoidCallback onView;

  const _SelectedLoadCard({required this.load, required this.onView});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -3)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                load.company,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${load.distance} · ${load.type}',
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ],
          ),
          TextButton(
            onPressed: onView,
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            child: const Text(
              'View',
              style: TextStyle(
                color: _navy,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
