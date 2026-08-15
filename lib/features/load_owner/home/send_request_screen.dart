import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../data/repositories/request_repository.dart';
import 'waiting_for_driver_screen.dart';

class SendRequestScreen extends StatefulWidget {
  final dynamic driver;

  const SendRequestScreen({super.key, required this.driver});

  @override
  State<SendRequestScreen> createState() => _SendRequestScreenState();
}

class _SendRequestScreenState extends State<SendRequestScreen> {
  final _pickupController = TextEditingController();
  final _dropController = TextEditingController();
  final _weightController = TextEditingController();
  final _notesController = TextEditingController();

  static const Color _navy = Color(0xFF003F7D);
  static const Color _navyLight = Color(0xFFE6EEF8);

  LatLng _pickupLatLng = const LatLng(19.0760, 72.8777);
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocation();
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (mounted) {
        setState(() =>
            _pickupLatLng = LatLng(position.latitude, position.longitude));
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _dropController.dispose();
    _weightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _submitRequest() async {
    // ─── Client-side validation (defense-in-depth) ───────────────────────
    final pickup = _pickupController.text.trim();
    final drop = _dropController.text.trim();
    final weightStr = _weightController.text.trim();
    final notes = _notesController.text.trim();

    if (pickup.isEmpty) {
      _showError('Pickup location required');
      return;
    }
    if (drop.isEmpty) {
      _showError('Please provide a valid drop address');
      return;
    }
    if (pickup.length > 500 || drop.length > 500) {
      _showError('Address too long (max 500 chars)');
      return;
    }
    if (notes.length > 1000) {
      _showError('Notes too long (max 1000 chars)');
      return;
    }
    double? weightKg;
    if (weightStr.isNotEmpty) {
      weightKg = double.tryParse(weightStr);
      if (weightKg == null || weightKg <= 0 || weightKg > 50000) {
        _showError('Weight must be between 1 and 50000 kg');
        return;
      }
    }

    setState(() => _isSending = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

      // Geocode drop address so the trip has real coordinates for tracking
      // and arrival detection. Fail hard rather than fall through with fakes.
      double dropLat;
      double dropLng;
      try {
        final results = await geo.locationFromAddress(drop);
        if (results.isEmpty) {
          _showError('Please provide a valid drop address');
          if (mounted) setState(() => _isSending = false);
          return;
        }
        dropLat = results.first.latitude;
        dropLng = results.first.longitude;
      } catch (_) {
        _showError('Please provide a valid drop address');
        if (mounted) setState(() => _isSending = false);
        return;
      }

      // Create real Supabase request
      final request = await RequestRepository().createRequest(
        loadOwnerId: uid,
        driverId: widget.driver.userId ?? '',
        pickupAddress: _pickupController.text.trim(),
        dropAddress: drop,
        pickupLat: _pickupLatLng.latitude,
        pickupLng: _pickupLatLng.longitude,
        dropLat: dropLat,
        dropLng: dropLng,
        goodsDescription: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        weightKg: weightKg,
      );

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WaitingForDriverScreen(
            driver: widget.driver,
            driverId: widget.driver.userId ?? '',
            pickupLocation: _pickupLatLng,
            requestId: request.id,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString();
      final friendly = raw.contains('Too many requests')
          ? 'Slow down — wait a moment and try again'
          : raw.contains('not available')
              ? 'Driver is no longer available'
              : raw.contains('Weight must be')
                  ? 'Weight must be 1 to 50,000 kg'
                  : 'Failed to send request';
      _showError(friendly);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String driverName = widget.driver.name ?? 'Driver';
    final String vehicleInfo = widget.driver.vehicle ?? '';
    final double ratingInfo = widget.driver.rating ?? 4.8;

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
          'Trip Details',
          style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 18),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),

                  // Driver brief card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _navyLight.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _navyLight),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(color: _navyLight),
                          ),
                          child: const Icon(Icons.person,
                              color: _navy, size: 30),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(driverName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.black87)),
                              const SizedBox(height: 4),
                              Text(vehicleInfo,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black54)),
                            ],
                          ),
                        ),
                        Row(children: [
                          const Icon(Icons.star,
                              size: 16, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(ratingInfo.toString(),
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87)),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Form fields
                  _label('PICKUP LOCATION'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _pickupController,
                    decoration: _inputDeco(
                      hint: 'Pickup location',
                      prefixIcon: const Icon(Icons.location_on,
                          color: _navy, size: 20),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _label('DROP LOCATION'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _dropController,
                    decoration: _inputDeco(
                      hint: 'Where to drop?',
                      prefixIcon: const Icon(Icons.adjust_rounded,
                          color: _navy, size: 20),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _label('LOAD WEIGHT (KG)'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _weightController,
                    keyboardType: TextInputType.number,
                    decoration: _inputDeco(
                      hint: '650',
                      prefixIcon: const Icon(Icons.scale_outlined,
                          color: _navy, size: 20),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _label('NOTES (OPTIONAL)'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: _inputDeco(
                      hint: 'Fragile items, handle with care',
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 30),
                        child: Icon(Icons.note_alt_outlined,
                            color: _navy, size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 16),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSending ? null : _submitRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _navy,
                    disabledBackgroundColor: Colors.grey.shade300,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28)),
                    elevation: 0,
                  ),
                  child: _isSending
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : const Text('Send Request',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.black54,
          letterSpacing: 0.5));

  InputDecoration _inputDeco(
          {required String hint, required Widget prefixIcon}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
        prefixIcon: prefixIcon,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                const BorderSide(color: _navy, width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );
}

