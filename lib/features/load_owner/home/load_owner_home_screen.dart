import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/load_owner_provider.dart';
import 'drivers_list_screen.dart';
import 'send_request_screen.dart';

const _navy = Color(0xFF003F7D);
const _navyLight = Color(0xFFE6EEF8);
const _amber = Color(0xFFF59E0B);

String _initials(String name) {
  final parts = name.trim().split(' ');
  if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  return name.substring(0, 2).toUpperCase();
}

class LoadOwnerHomeScreen extends ConsumerStatefulWidget {
  const LoadOwnerHomeScreen({super.key});

  @override
  ConsumerState<LoadOwnerHomeScreen> createState() =>
      _LoadOwnerHomeScreenState();
}

class _LoadOwnerHomeScreenState extends ConsumerState<LoadOwnerHomeScreen> {
  static const _truckData = [
    (name: 'Suresh Patil', vehicle: 'Mini Truck', number: 'MH 14 AB 1234', capacity: '800 kg', distance: '2.4 km', rating: 4.8, trips: 234, dLat: 0.018, dLng: -0.021),
    (name: 'Ramesh Kumar', vehicle: 'LCV', number: 'MH 12 CD 5678', capacity: '1200 kg', distance: '3.7 km', rating: 4.6, trips: 187, dLat: -0.016, dLng: -0.048),
    (name: 'Anil Yadav', vehicle: 'HCV', number: 'MH 04 EF 9012', capacity: '2500 kg', distance: '5.1 km', rating: 4.9, trips: 312, dLat: -0.003, dLng: 0.005),
  ];

  List<_TruckPin> get _trucks => _truckData.map((t) => _TruckPin(
    name: t.name,
    vehicle: t.vehicle,
    number: t.number,
    capacity: t.capacity,
    distance: t.distance,
    rating: t.rating,
    trips: t.trips,
    lat: _mapCenter.latitude + t.dLat,
    lng: _mapCenter.longitude + t.dLng,
  )).toList();

  GoogleMapController? _mapController;
  LatLng _mapCenter = const LatLng(19.0760, 72.8777);
  bool _loadingLocation = true;

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocation();
  }

  Future<void> _fetchCurrentLocation() async {
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
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final newCenter = LatLng(position.latitude, position.longitude);
      setState(() {
        _mapCenter = newCenter;
        _loadingLocation = false;
      });

      _mapController?.animateCamera(CameraUpdate.newLatLng(newCenter));
    } catch (_) {
      setState(() => _loadingLocation = false);
    }
  }

  Set<Marker> _buildMarkers() {
    return _trucks.asMap().entries.map((entry) {
      final i = entry.key;
      final truck = entry.value;
      return Marker(
        markerId: MarkerId('truck_$i'),
        position: LatLng(truck.lat, truck.lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: InfoWindow(title: truck.name, snippet: truck.vehicle),
        onTap: () {
          ref.read(selectedTruckPinProvider.notifier).state = i;
          _showDriverSheet(context, truck);
        },
      );
    }).toSet();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedType = ref.watch(vehicleTypeFilterProvider);
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // AppBar manual (so map can go edge-to-edge)
          SafeArea(
            bottom: false,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.menu, color: Colors.black87),
                    onPressed: () {},
                  ),
                  Expanded(
                    child: Text(
                      'TripJio',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined, color: Colors.black87),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
          // Map
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _mapCenter,
                    zoom: 13,
                  ),
                  markers: _buildMarkers(),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  onMapCreated: (controller) {
                    _mapController = controller;
                    if (!_loadingLocation) {
                      controller.animateCamera(CameraUpdate.newLatLng(_mapCenter));
                    }
                  },
                ),
                if (_loadingLocation)
                  Container(
                    color: Colors.white.withOpacity(0.7),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: _navy),
                          SizedBox(height: 12),
                          Text('Fetching your location...'),
                        ],
                      ),
                    ),
                  ),
                // Filter chips
                Positioned(
                  top: 12,
                  left: 12,
                  child: Row(
                    children: [
                      _TypeChip(
                        label: 'All Types',
                        selected: selectedType == 0,
                        onTap: () =>
                            ref.read(vehicleTypeFilterProvider.notifier).state = 0,
                      ),
                      const SizedBox(width: 8),
                      _TypeChip(
                        label: '12 Online',
                        selected: true,
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Bottom panel
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '12 trucks nearby',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const DriversListScreen()),
                        ),
                        child: Text(
                          'List view',
                          style: GoogleFonts.poppins(
                            color: _navy,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 14),
                        const Icon(Icons.search, color: Colors.black45, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Search pickup location',
                          style: GoogleFonts.poppins(
                            color: Colors.black45,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDriverSheet(BuildContext context, _TruckPin truck) {
    ref.read(selectedTruckPinProvider.notifier).state = _trucks.indexOf(truck);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DriverDetailsSheet(truck: truck),
    ).then((_) => ref.read(selectedTruckPinProvider.notifier).state = null);
  }
}

// ─── Driver Details Bottom Sheet (Screen 14) ────────────────────────────────

class _DriverDetailsSheet extends StatelessWidget {
  final _TruckPin truck;

  const _DriverDetailsSheet({required this.truck});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          // Driver info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFF003F7D), Color(0xFF1565C0)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _initials(truck.name),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF2ECC71),
                          boxShadow: [BoxShadow(color: Colors.white, blurRadius: 0, spreadRadius: 2)],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      truck.name,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 16, color: _amber),
                        const SizedBox(width: 4),
                        Text(
                          '${truck.rating}',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '· ${truck.trips} trips',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Stats grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _StatCell(label: 'VEHICLE', value: truck.vehicle)),
                      Expanded(child: _StatCell(label: 'NUMBER', value: truck.number)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: _StatCell(label: 'CAPACITY', value: truck.capacity)),
                      Expanded(child: _StatCell(label: 'DISTANCE', value: truck.distance)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Buttons
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.phone_outlined, size: 18, color: Colors.black87),
                      label: Text(
                        'Call',
                        style: GoogleFonts.poppins(
                          color: Colors.black87,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SendRequestScreen(driver: truck),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _navy,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                        elevation: 0,
                      ),
                      child: Text(
                        'Send Request',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;

  const _StatCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: Colors.black45,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

// ─── Data model ─────────────────────────────────────────────────────────────

class _TruckPin {
  final String name;
  final String vehicle;
  final String number;
  final String capacity;
  final String distance;
  final double rating;
  final int trips;
  final double lat;
  final double lng;

  const _TruckPin({
    required this.name,
    required this.vehicle,
    required this.number,
    required this.capacity,
    required this.distance,
    required this.rating,
    required this.trips,
    required this.lat,
    required this.lng,
  });
}

// ─── Widgets ─────────────────────────────────────────────────────────────────

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TypeChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? _navy : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}

