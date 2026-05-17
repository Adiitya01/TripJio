import 'package:flutter/material.dart';
import 'location_permission_screen.dart';

class VehicleDetailsScreen extends StatefulWidget {
  const VehicleDetailsScreen({super.key});

  @override
  State<VehicleDetailsScreen> createState() => _VehicleDetailsScreenState();
}

class _VehicleDetailsScreenState extends State<VehicleDetailsScreen> {
  final _vehicleNumberController = TextEditingController();
  String? _selectedType;

  static const _vehicleTypes = ['Mini Truck', 'LCV', 'HCV', 'Container'];

  bool get _canComplete =>
      _vehicleNumberController.text.trim().isNotEmpty &&
      _selectedType != null;

  @override
  void dispose() {
    _vehicleNumberController.dispose();
    super.dispose();
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
                      style:
                          TextStyle(fontSize: 15, color: Colors.black54),
                    ),
                    const SizedBox(height: 24),
                    // Vehicle photo upload area
                    GestureDetector(
                      onTap: () {},
                      child: Container(
                        width: double.infinity,
                        height: 110,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF0EA),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFFFF6B35),
                            width: 1.5,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.camera_alt_outlined,
                              size: 36,
                              color: Color(0xFFFF6B35),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Add Vehicle Photo',
                              style: TextStyle(
                                color: Color(0xFFFF6B35),
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
                        hintStyle:
                            const TextStyle(color: Colors.black38),
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
                          borderSide: const BorderSide(
                              color: Color(0xFFFF6B35)),
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
                                  ? const Color(0xFFFFF0EA)
                                  : Colors.white,
                              border: Border.all(
                                color: selected
                                    ? const Color(0xFFFF6B35)
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
                                      ? const Color(0xFFFF6B35)
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
                  onPressed: _canComplete
                      ? () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) =>
                                const LocationPermissionScreen(),
                          ))
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                    disabledBackgroundColor: Colors.grey.shade300,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28)),
                    elevation: 0,
                  ),
                  child: const Text('Complete Setup',
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
