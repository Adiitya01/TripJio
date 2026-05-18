import 'package:flutter/material.dart';

const _navy = Color(0xFF003F7D);

class DriverMapScreen extends StatefulWidget {
  const DriverMapScreen({super.key});

  @override
  State<DriverMapScreen> createState() => _DriverMapScreenState();
}

class _DriverMapScreenState extends State<DriverMapScreen> {
  int _selectedIndex = 0;

  static const _loads = [
    _LoadInfo(company: 'Rajesh Textiles', distance: '2.4 km', type: 'LCV · 800kg'),
    _LoadInfo(company: 'Mehta Traders', distance: '4.1 km', type: 'Mini · 400kg'),
    _LoadInfo(company: 'Singh Logistics', distance: '6.2 km', type: 'HCV · 2000kg'),
  ];

  // Normalized positions on the mock map (dx, dy) 0.0–1.0
  static const _pinPositions = [
    Offset(0.62, 0.32),
    Offset(0.22, 0.54),
    Offset(0.72, 0.67),
  ];

  @override
  Widget build(BuildContext context) {
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
          Expanded(
            child: Stack(
              children: [
                // Mock map background
                SizedBox.expand(
                  child: CustomPaint(painter: _MockMapPainter()),
                ),
                // Filter chips
                Positioned(
                  top: 12,
                  left: 12,
                  child: Row(
                    children: const [
                      _FilterChip(label: '8 Loads'),
                      SizedBox(width: 8),
                      _FilterChip(label: '≤ 5 km'),
                    ],
                  ),
                ),
                // Pins and driver dot
                LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        // Driver's location (green dot)
                        Positioned(
                          left: constraints.maxWidth * 0.45 - 10,
                          top: constraints.maxHeight * 0.47 - 10,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF2ECC71),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Load pins
                        for (int i = 0; i < _pinPositions.length; i++)
                          Positioned(
                            left: constraints.maxWidth * _pinPositions[i].dx - 20,
                            top: constraints.maxHeight * _pinPositions[i].dy - 20,
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedIndex = i),
                              child: _LoadPin(selected: _selectedIndex == i),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          // Selected load card
          _SelectedLoadCard(
            load: _loads[_selectedIndex],
            onView: () {},
          ),
        ],
      ),
    );
  }
}

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

class _LoadPin extends StatelessWidget {
  final bool selected;

  const _LoadPin({required this.selected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? Colors.white : _navy,
        border: selected ? Border.all(color: _navy, width: 2.5) : null,
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Icon(
        Icons.inventory_2_outlined,
        size: 20,
        color: selected ? _navy : Colors.white,
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -3),
          ),
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

class _MockMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFFE8EDF2);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bg);

    final blockPaint = Paint()..color = const Color(0xFFD6DCE4);
    final blocks = [
      Rect.fromLTWH(0, 0, size.width * 0.18, size.height * 0.25),
      Rect.fromLTWH(size.width * 0.22, 0, size.width * 0.24, size.height * 0.25),
      Rect.fromLTWH(size.width * 0.5, 0, size.width * 0.18, size.height * 0.25),
      Rect.fromLTWH(0, size.height * 0.32, size.width * 0.18, size.height * 0.18),
      Rect.fromLTWH(size.width * 0.54, size.height * 0.32, size.width * 0.14, size.height * 0.18),
      Rect.fromLTWH(size.width * 0.72, size.height * 0.32, size.width * 0.28, size.height * 0.18),
      Rect.fromLTWH(0, size.height * 0.56, size.width * 0.14, size.height * 0.22),
      Rect.fromLTWH(size.width * 0.28, size.height * 0.56, size.width * 0.2, size.height * 0.22),
      Rect.fromLTWH(size.width * 0.54, size.height * 0.56, size.width * 0.46, size.height * 0.22),
      Rect.fromLTWH(0, size.height * 0.84, size.width * 0.35, size.height * 0.16),
      Rect.fromLTWH(size.width * 0.4, size.height * 0.84, size.width * 0.6, size.height * 0.16),
    ];
    for (final block in blocks) {
      canvas.drawRect(block, blockPaint);
    }

    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke;
    final minorPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(0, size.height * 0.285), Offset(size.width, size.height * 0.285), roadPaint);
    canvas.drawLine(Offset(0, size.height * 0.525), Offset(size.width, size.height * 0.525), roadPaint);
    canvas.drawLine(Offset(0, size.height * 0.80), Offset(size.width, size.height * 0.80), minorPaint);
    canvas.drawLine(Offset(size.width * 0.19, 0), Offset(size.width * 0.19, size.height), roadPaint);
    canvas.drawLine(Offset(size.width * 0.49, 0), Offset(size.width * 0.49, size.height), roadPaint);
    canvas.drawLine(Offset(size.width * 0.71, 0), Offset(size.width * 0.71, size.height), minorPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
