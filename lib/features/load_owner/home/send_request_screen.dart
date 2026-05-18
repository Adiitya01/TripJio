import 'package:flutter/material.dart';
import 'waiting_for_driver_screen.dart';

class SendRequestScreen extends StatefulWidget {
  final dynamic driver;

  const SendRequestScreen({super.key, required this.driver});

  @override
  State<SendRequestScreen> createState() => _SendRequestScreenState();
}

class _SendRequestScreenState extends State<SendRequestScreen> {
  final _pickupController = TextEditingController(text: 'Andheri East, Mumbai');
  final _dropController = TextEditingController();
  final _weightController = TextEditingController();
  final _notesController = TextEditingController();

  static const Color _navy = Color(0xFF003F7D);
  static const Color _navyLight = Color(0xFFE6EEF8);

  @override
  void dispose() {
    _pickupController.dispose();
    _dropController.dispose();
    _weightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submitRequest() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WaitingForDriverScreen(driver: widget.driver),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Safely extract properties dynamically from either _TruckPin or _DriverData
    final String driverName = widget.driver.name ?? 'Driver';
    final String vehicleInfo = widget.driver.vehicle ?? '';
    final String distanceInfo = widget.driver.distance ?? '';
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
            fontSize: 18,
          ),
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
                  // Driver Brief Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _navyLight.withOpacity(0.4),
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
                          child: const Icon(Icons.person, color: _navy, size: 30),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                                '$vehicleInfo · $distanceInfo',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.star, size: 16, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(
                              ratingInfo.toString(),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  
                  // Form Fields
                  _label('PICKUP LOCATION'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _pickupController,
                    decoration: _inputDeco(
                      hint: 'Pickup location',
                      prefixIcon: const Icon(Icons.location_on, color: _navy, size: 20),
                    ),
                  ),
                  const SizedBox(height: 20),

                  _label('DROP LOCATION (OPTIONAL)'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _dropController,
                    decoration: _inputDeco(
                      hint: 'Where to drop?',
                      prefixIcon: const Icon(Icons.adjust_rounded, color: _navy, size: 20),
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
                      prefixIcon: const Icon(Icons.scale_outlined, color: _navy, size: 20),
                    ),
                  ),
                  const SizedBox(height: 20),

                  _label('NOTES'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: _inputDeco(
                      hint: 'Fragile items, handle with care',
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(bottom: 30),
                        child: const Icon(Icons.note_alt_outlined, color: _navy, size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          
          // Send Request Button safely padded at the bottom
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _submitRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _navy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Send Request',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Colors.black54,
        letterSpacing: 0.5,
      ),
    );
  }

  InputDecoration _inputDeco({required String hint, required Widget prefixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
      prefixIcon: prefixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _navy, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
