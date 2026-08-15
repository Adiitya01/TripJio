import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/load_owner_provider.dart';
import '../../../data/repositories/driver_repository.dart';
import '../../../data/repositories/trip_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../core/widgets/welcome_dialog.dart';
import '../../shared/account_settings_screen.dart';
import 'drivers_list_screen.dart';
import 'live_tracking_screen.dart';
import 'send_request_screen.dart';

const _navy = Color(0xFF003F7D);
// ignore: unused_element
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
  // Real drivers fetched from Supabase — populated in build()
  List<_TruckPin> _trucks = [];

  GoogleMapController? _mapController;
  // Default to (0, 0) — invisible "no location" state
  // Real location is set as soon as GPS or cache provides it
  LatLng _mapCenter = const LatLng(20.5937, 78.9629); // India center (neutral)
  bool _hasRealLocation = false; // ⭐ Tracks if we have actual user GPS
  bool _locationPermissionDenied = false;

  static const _kLastLatKey = 'last_known_lat';
  static const _kLastLngKey = 'last_known_lng';

  @override
  void initState() {
    super.initState();
    _initLocationFast();
    // First-time welcome (shows once)
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => WelcomeDialog.showOnce(context, isDriver: false));
    // If a trip is already running, jump back into live tracking. Mirrors
    // the driver-side _resumeActiveTrip — the load owner must not lose
    // visibility into an in-flight trip on app restart.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _resumeActiveTrip());
  }

  Future<void> _resumeActiveTrip() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final trip = await TripRepository().getActiveTripForUser(uid);
      if (trip == null || !mounted) return;
      final driver = await DriverRepository().getDriverProfile(trip.driverId);
      if (driver == null || !mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LiveTrackingScreen(
            driver: driver,
            driverId: trip.driverId,
            pickupLocation: LatLng(trip.pickupLat, trip.pickupLng),
            requestId: trip.id,
          ),
        ),
      );
    } catch (_) {/* network glitch — user can manually re-enter via UI */}
  }

  /// Uber-style fast location:
  /// 1. Use SharedPreferences cached location (instant)
  /// 2. Use Geolocator's last known position (instant, no GPS lock)
  /// 3. In the background, fetch fresh GPS and animate to it
  Future<void> _initLocationFast() async {
    // ─── Step 1: SharedPreferences cache (instant, survives app restarts)
    final prefs = await SharedPreferences.getInstance();
    final cachedLat = prefs.getDouble(_kLastLatKey);
    final cachedLng = prefs.getDouble(_kLastLngKey);
    if (cachedLat != null && cachedLng != null) {
      final cached = LatLng(cachedLat, cachedLng);
      if (mounted) {
        setState(() {
          _mapCenter = cached;
          _hasRealLocation = true;
        });
      }
      ref.read(userLocationProvider.notifier).state =
          (lat: cachedLat, lng: cachedLng);
    }

    // ─── Step 2: Geolocator's last known position (instant, no GPS wait)
    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null && mounted) {
        setState(() {
          _mapCenter = LatLng(lastKnown.latitude, lastKnown.longitude);
          _hasRealLocation = true;
        });
        ref.read(userLocationProvider.notifier).state =
            (lat: lastKnown.latitude, lng: lastKnown.longitude);
      }
    } catch (_) {/* ignore */}

    // ─── Step 3: Fresh GPS in background
    _fetchFreshLocation();
  }

  Future<void> _fetchFreshLocation() async {
    try {
      // Check service
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) {
          setState(() => _locationPermissionDenied = !_hasRealLocation);
        }
        return;
      }

      // Permission
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() => _locationPermissionDenied = !_hasRealLocation);
        }
        return;
      }

      // Get fresh GPS
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final newCenter = LatLng(position.latitude, position.longitude);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kLastLatKey, position.latitude);
      await prefs.setDouble(_kLastLngKey, position.longitude);

      ref.read(userLocationProvider.notifier).state =
          (lat: position.latitude, lng: position.longitude);

      if (!mounted) return;
      setState(() {
        _mapCenter = newCenter;
        _hasRealLocation = true;
        _locationPermissionDenied = false;
      });
      _mapController?.animateCamera(CameraUpdate.newLatLng(newCenter));
    } catch (_) {
      // GPS failed — if we still don't have a real location, show the warning
      if (mounted && !_hasRealLocation) {
        setState(() => _locationPermissionDenied = true);
      }
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
    final userLocation = ref.watch(userLocationProvider);

    // Fetch real drivers from Supabase when location is available
    // CRITICAL: only query when we have a REAL user location, not the
    // fallback. Otherwise we'd query drivers around the wrong city.
    final driversAsync = (userLocation == null || !_hasRealLocation)
        ? const AsyncValue<List<NearbyDriver>>.data([])
        : ref.watch(nearbyDriversProvider(userLocation));

    // Convert real drivers to truck pins
    _trucks = driversAsync.maybeWhen(
      data: (drivers) => drivers
          .map((d) => _TruckPin(
                userId: d.userId,
                name: d.name,
                vehicle: d.vehicleType,
                vehicleType: d.vehicleType,
                number: d.vehicleNumber,
                capacity: d.capacity,
                distance: '${d.distanceKm.toStringAsFixed(1)} km',
                distanceKm: d.distanceKm,
                rating: d.rating,
                trips: d.totalTrips,
                lat: d.latitude,
                lng: d.longitude,
              ))
          .toList(),
      orElse: () => <_TruckPin>[],
    );

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
                    icon: const Icon(Icons.account_circle_outlined,
                        color: Colors.black87, size: 28),
                    tooltip: 'Profile',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AccountSettingsScreen(),
                      ),
                    ),
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
                    zoom: 14, // Zoom 14 = neighbourhood view, loads fewer tiles
                  ),
                  markers: _buildMarkers(),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  // ⭐ Performance optimizations (Uber-style)
                  buildingsEnabled: false,    // No 3D buildings — faster tiles
                  trafficEnabled: false,      // No traffic overlay — fewer API calls
                  indoorViewEnabled: false,   // No indoor maps — faster render
                  liteModeEnabled: false,     // Keep interactive (false = full map)
                  compassEnabled: false,      // Save GPU
                  rotateGesturesEnabled: false, // Disable rotate for cleaner UX
                  tiltGesturesEnabled: false,   // Disable tilt
                  onMapCreated: (controller) {
                    _mapController = controller;
                    controller.animateCamera(CameraUpdate.newLatLng(_mapCenter));
                  },
                ),
                // Tiny non-blocking GPS indicator (corner)
                Positioned(
                  top: 12,
                  right: 12,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: 0.0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black12,
                              blurRadius: 4,
                              offset: Offset(0, 2))
                        ],
                      ),
                      child: const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _navy),
                      ),
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
                        label: '${_trucks.length} Online',
                        selected: true,
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
                // ⚠️ Critical: warn user if location isn't real
                if (_locationPermissionDenied || !_hasRealLocation)
                  Positioned(
                    top: 60,
                    left: 12,
                    right: 12,
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: Colors.orange.shade300),
                          boxShadow: const [
                            BoxShadow(
                                color: Colors.black12,
                                blurRadius: 6,
                                offset: Offset(0, 2)),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                color: Colors.orange.shade800, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _locationPermissionDenied
                                        ? 'Location not available'
                                        : 'Getting your location...',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange.shade900,
                                    ),
                                  ),
                                  Text(
                                    _locationPermissionDenied
                                        ? 'Map shows wrong area. Enable GPS to see drivers near you.'
                                        : 'Searching for your GPS...',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.orange.shade900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_locationPermissionDenied)
                              TextButton(
                                onPressed: _fetchFreshLocation,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  minimumSize: Size.zero,
                                ),
                                child: Text(
                                  'Retry',
                                  style: TextStyle(
                                    color: Colors.orange.shade900,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                // Recenter-to-me FAB (Uber-style)
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: Material(
                    color: Colors.white,
                    elevation: 4,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        if (userLocation != null) {
                          _mapController?.animateCamera(
                            CameraUpdate.newLatLngZoom(
                              LatLng(userLocation.lat, userLocation.lng),
                              15,
                            ),
                          );
                        } else {
                          // Trigger a fresh GPS fetch
                          _fetchFreshLocation();
                        }
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Icon(
                          Icons.my_location,
                          color: _navy,
                          size: 22,
                        ),
                      ),
                    ),
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
                        '${_trucks.length} trucks nearby',
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
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: (_trucks.isEmpty || !_hasRealLocation)
                          ? null
                          : () => _findNearestDriver(context),
                      icon: const Icon(Icons.local_shipping_rounded,
                          color: Colors.white, size: 22),
                      label: Text(
                        !_hasRealLocation
                            ? 'Enable Location to Find Drivers'
                            : _trucks.isEmpty
                                ? 'No drivers available'
                                : 'Find a Driver',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _navy,
                        disabledBackgroundColor: Colors.grey.shade300,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(27)),
                      ),
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

  /// "Uber-style" auto-find: picks the closest online driver and
  /// opens the SendRequest screen with them pre-selected.
  void _findNearestDriver(BuildContext context) {
    if (_trucks.isEmpty) return;
    // _trucks already sorted by distance ascending from nearbyDriversProvider
    final nearest = _trucks.first;
    ref.read(selectedTruckPinProvider.notifier).state = 0;

    // Animate map to the chosen driver
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(nearest.lat, nearest.lng), 15),
    );

    // Quick feedback then open SendRequest
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Closest driver: ${nearest.name}'),
        backgroundColor: _navy,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SendRequestScreen(driver: nearest),
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
                      const Expanded(child: SizedBox()),
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
                      onPressed: () async {
                        final user =
                            await UserRepository().getUser(truck.userId);
                        final phone = user?.phone ?? '';
                        if (phone.isEmpty) return;
                        final uri = Uri.parse('tel:$phone');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        }
                      },
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
  final String userId;
  final String name;
  final String vehicle;
  final String vehicleType;
  final String number;
  final String capacity;
  final String distance;
  final double distanceKm;
  final double rating;
  final int trips;
  final double lat;
  final double lng;

  const _TruckPin({
    required this.userId,
    required this.name,
    required this.vehicle,
    required this.vehicleType,
    required this.number,
    required this.capacity,
    required this.distance,
    required this.distanceKm,
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

