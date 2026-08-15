import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../core/services/session_service.dart';
import '../../core/utils/validators.dart';
import '../../data/repositories/user_repository.dart';
import 'location_permission_screen.dart';

class VehicleDetailsScreen extends StatefulWidget {
  final String uid;
  final String phone;
  final String name;
  final String licenseNumber;
  final String experience;

  const VehicleDetailsScreen({
    super.key,
    required this.uid,
    required this.phone,
    required this.name,
    required this.licenseNumber,
    required this.experience,
  });

  @override
  State<VehicleDetailsScreen> createState() => _VehicleDetailsScreenState();
}

class _VehicleDetailsScreenState extends State<VehicleDetailsScreen> {
  final _vehicleNumberController = TextEditingController();
  String? _selectedType;
  bool _isSaving = false;

  static const _vehicleTypes = ['Mini Truck', 'LCV', 'HCV', 'Container'];

  bool get _canComplete =>
      _vehicleNumberController.text.trim().isNotEmpty &&
      _selectedType != null &&
      !_isSaving;

  @override
  void dispose() {
    _vehicleNumberController.dispose();
    super.dispose();
  }

  Future<void> _completeSetup() async {
    // Validate vehicle number
    final vehicleErr =
        Validators.vehicleNumber(_vehicleNumberController.text);
    if (vehicleErr != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(vehicleErr),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    setState(() => _isSaving = true);
    try {
      // ⚛️ ACID: all 3 inserts wrapped in a single atomic transaction.
      // If any step fails, ALL roll back — no orphan accounts.
      await UserRepository().signupDriverAtomic(
        uid: widget.uid,
        phone: widget.phone,
        name: widget.name,
        licenseNumber: widget.licenseNumber,
        experience: widget.experience,
        vehicleId: const Uuid().v4(),
        vehicleNumber:
            _vehicleNumberController.text.trim().toUpperCase(),
        vehicleType: _selectedType!,
      );

      // 4. Persist login state locally (uid stored for background GPS isolate)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userType', 'driver');
      await prefs.setString('uid', widget.uid);

      // 5. Register this device as the active session (kicks out other devices)
      await SessionService.registerSession(widget.uid);

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
            builder: (_) => const LocationPermissionScreen(isDriver: true)),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString();
      final friendly = raw.contains('idx_vehicles_unique_number')
          ? 'This vehicle number is already registered'
          : raw.contains('idx_drivers_unique_license')
              ? 'This license number is already registered'
              : 'Failed to save profile';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendly),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Vehicle details',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Step 2 of 2',
                      style: TextStyle(fontSize: 15, color: Colors.black54),
                    ),
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: () {},
                      child: Container(
                        width: double.infinity,
                        height: 110,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6EEF8),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFF003F7D),
                            width: 1.5,
                          ),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt_outlined,
                                size: 36, color: Color(0xFF003F7D)),
                            SizedBox(height: 8),
                            Text(
                              'Add Vehicle Photo',
                              style: TextStyle(
                                color: Color(0xFF003F7D),
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _label('VEHICLE NUMBER'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _vehicleNumberController,
                      textCapitalization: TextCapitalization.characters,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'MH 14 AB 1234',
                        hintStyle: const TextStyle(color: Colors.black38),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFF003F7D)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _label('VEHICLE TYPE'),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 3,
                      children: _vehicleTypes.map((type) {
                        final selected = _selectedType == type;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedType = type),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0xFFE6EEF8)
                                  : Colors.white,
                              border: Border.all(
                                color: selected
                                    ? const Color(0xFF003F7D)
                                    : Colors.grey.shade300,
                                width: selected ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                type,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: selected
                                      ? const Color(0xFF003F7D)
                                      : Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _canComplete ? _completeSetup : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF003F7D),
                    disabledBackgroundColor: Colors.grey.shade300,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28)),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Text('Complete Setup',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.black54,
          letterSpacing: 0.5,
        ),
      );
}
