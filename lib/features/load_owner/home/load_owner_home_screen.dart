import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/load_owner_provider.dart';
import 'drivers_list_screen.dart';
import 'send_request_screen.dart';

const _navy = Color(0xFF003F7D);
const _navyLight = Color(0xFFE6EEF8);

class LoadOwnerHomeScreen extends ConsumerStatefulWidget {
  const LoadOwnerHomeScreen({super.key});

  @override
  ConsumerState<LoadOwnerHomeScreen> createState() =>
      _LoadOwnerHomeScreenState();
}

class _LoadOwnerHomeScreenState extends ConsumerState<LoadOwnerHomeScreen> {
  static const _trucks = [
    _TruckPin(name: 'Suresh Patil', vehicle: 'Mini Truck', number: 'MH 14 AB 1234', capacity: '800 kg', distance: '2.4 km', rating: 4.8, trips: 234, dx: 0.62, dy: 0.30),
    _TruckPin(name: 'Ramesh Kumar', vehicle: 'LCV', number: 'MH 12 CD 5678', capacity: '1200 kg', distance: '3.7 km', rating: 4.6, trips: 187, dx: 0.25, dy: 0.52),
    _TruckPin(name: 'Anil Yadav', vehicle: 'HCV', number: 'MH 04 EF 9012', capacity: '2500 kg', distance: '5.1 km', rating: 4.9, trips: 312, dx: 0.70, dy: 0.62),
  ];

  @override
  Widget build(BuildContext context) {
    final selectedType = ref.watch(vehicleTypeFilterProvider);
    final selectedPin = ref.watch(selectedTruckPinProvider);
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
                  const Expanded(
                    child: Text(
                      'TripJio',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
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
                SizedBox.expand(child: CustomPaint(painter: _MapPainter())),
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
                // Truck pins + owner location dot
                LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        // Owner's blue dot
                        Positioned(
                          left: constraints.maxWidth * 0.44 - 10,
                          top: constraints.maxHeight * 0.44 - 10,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF1565C0),
                              boxShadow: [
                                BoxShadow(color: Colors.black26, blurRadius: 6),
                              ],
                            ),
                          ),
                        ),
                        for (int i = 0; i < _trucks.length; i++)
                          Positioned(
                            left: constraints.maxWidth * _trucks[i].dx - 22,
                            top: constraints.maxHeight * _trucks[i].dy - 22,
                            child: GestureDetector(
                              onTap: () {
                                ref.read(selectedTruckPinProvider.notifier).state = i;
                                _showDriverSheet(context, _trucks[i]);
                              },
                              child: _TruckMarker(
                                selected: selectedPin == i,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          // Bottom panel
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: const [
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
                      const Text(
                        '12 trucks nearby',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
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
                        child: const Text(
                          'List view',
                          style: TextStyle(
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
                      children: const [
                        SizedBox(width: 14),
                        Icon(Icons.search, color: Colors.black45, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Search pickup location',
                          style: TextStyle(color: Colors.black45, fontSize: 14),
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
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey.shade200,
                      ),
                      child: const Icon(Icons.person, size: 34, color: Colors.black54),
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
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 15, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          '${truck.rating} · ${truck.trips} trips',
                          style: const TextStyle(fontSize: 13, color: Colors.black54),
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
                      label: const Text(
                        'Call',
                        style: TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w600),
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
                      child: const Text(
                        'Send Request',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
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
          style: const TextStyle(
            fontSize: 11,
            color: Colors.black45,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
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
  final double dx;
  final double dy;

  const _TruckPin({
    required this.name,
    required this.vehicle,
    required this.number,
    required this.capacity,
    required this.distance,
    required this.rating,
    required this.trips,
    required this.dx,
    required this.dy,
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
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}

class _TruckMarker extends StatelessWidget {
  final bool selected;

  const _TruckMarker({required this.selected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? Colors.white : _navy,
        border: selected ? Border.all(color: _navy, width: 2.5) : null,
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Icon(
        Icons.local_shipping,
        size: 22,
        color: selected ? _navy : Colors.white,
      ),
    );
  }
}

// ─── Mock map painter ────────────────────────────────────────────────────────

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFFE8EDF2),
    );
    final block = Paint()..color = const Color(0xFFD6DCE4);
    for (final r in [
      Rect.fromLTWH(0, 0, size.width * 0.18, size.height * 0.26),
      Rect.fromLTWH(size.width * 0.22, 0, size.width * 0.25, size.height * 0.26),
      Rect.fromLTWH(size.width * 0.52, 0, size.width * 0.18, size.height * 0.26),
      Rect.fromLTWH(size.width * 0.74, 0, size.width * 0.26, size.height * 0.26),
      Rect.fromLTWH(0, size.height * 0.33, size.width * 0.18, size.height * 0.16),
      Rect.fromLTWH(size.width * 0.52, size.height * 0.33, size.width * 0.18, size.height * 0.16),
      Rect.fromLTWH(size.width * 0.74, size.height * 0.33, size.width * 0.26, size.height * 0.16),
      Rect.fromLTWH(0, size.height * 0.56, size.width * 0.14, size.height * 0.22),
      Rect.fromLTWH(size.width * 0.28, size.height * 0.56, size.width * 0.20, size.height * 0.22),
      Rect.fromLTWH(size.width * 0.54, size.height * 0.56, size.width * 0.46, size.height * 0.22),
      Rect.fromLTWH(0, size.height * 0.84, size.width * 0.35, size.height * 0.16),
      Rect.fromLTWH(size.width * 0.40, size.height * 0.84, size.width * 0.60, size.height * 0.16),
    ]) {
      canvas.drawRect(r, block);
    }
    final road = Paint()..color = Colors.white..strokeWidth = 10..style = PaintingStyle.stroke;
    final minor = Paint()..color = Colors.white..strokeWidth = 5..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, size.height * 0.285), Offset(size.width, size.height * 0.285), road);
    canvas.drawLine(Offset(0, size.height * 0.525), Offset(size.width, size.height * 0.525), road);
    canvas.drawLine(Offset(0, size.height * 0.80), Offset(size.width, size.height * 0.80), minor);
    canvas.drawLine(Offset(size.width * 0.19, 0), Offset(size.width * 0.19, size.height), road);
    canvas.drawLine(Offset(size.width * 0.49, 0), Offset(size.width * 0.49, size.height), road);
    canvas.drawLine(Offset(size.width * 0.73, 0), Offset(size.width * 0.73, size.height), minor);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
