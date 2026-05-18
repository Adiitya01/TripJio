import 'package:flutter/material.dart';
import 'driver_home_screen.dart';

const _navy = Color(0xFF003F7D);

class TripInProgressScreen extends StatelessWidget {
  const TripInProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                // Mock map
                SizedBox.expand(
                  child: CustomPaint(painter: _TripMapPainter()),
                ),
                // Distance to pickup — top left card
                Positioned(
                  top: MediaQuery.of(context).padding.top + 14,
                  left: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'DISTANCE TO PICKUP',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.black45,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '1.2 km',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: _navy,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Truck marker (driver location on map)
                LayoutBuilder(
                  builder: (context, constraints) => Positioned(
                    left: constraints.maxWidth * 0.28 - 22,
                    top: constraints.maxHeight * 0.52 - 22,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: _navy,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.local_shipping,
                          color: Colors.white, size: 22),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Bottom info + button
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 12,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'GOING TO',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.black45,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Andheri East, Mumbai',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'ETA: 4 minutes',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1A7A4A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                          builder: (_) => const DriverHomeScreen()),
                      (_) => false,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _navy,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28)),
                      elevation: 0,
                    ),
                    child: const Text(
                      "I've Reached Pickup",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
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
}

class _TripMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFFE8EDF2),
    );

    final blockPaint = Paint()..color = const Color(0xFFD6DCE4);
    for (final r in [
      Rect.fromLTWH(0, 0, size.width * 0.18, size.height * 0.26),
      Rect.fromLTWH(size.width * 0.22, 0, size.width * 0.25, size.height * 0.26),
      Rect.fromLTWH(size.width * 0.52, 0, size.width * 0.18, size.height * 0.26),
      Rect.fromLTWH(size.width * 0.74, 0, size.width * 0.26, size.height * 0.26),
      Rect.fromLTWH(0, size.height * 0.33, size.width * 0.18, size.height * 0.18),
      Rect.fromLTWH(size.width * 0.52, size.height * 0.33, size.width * 0.2, size.height * 0.18),
      Rect.fromLTWH(size.width * 0.74, size.height * 0.33, size.width * 0.26, size.height * 0.18),
      Rect.fromLTWH(size.width * 0.22, size.height * 0.58, size.width * 0.25, size.height * 0.2),
      Rect.fromLTWH(size.width * 0.52, size.height * 0.58, size.width * 0.48, size.height * 0.2),
      Rect.fromLTWH(0, size.height * 0.84, size.width * 0.35, size.height * 0.16),
      Rect.fromLTWH(size.width * 0.40, size.height * 0.84, size.width * 0.60, size.height * 0.16),
    ]) {
      canvas.drawRect(r, blockPaint);
    }

    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke;
    final minor = Paint()
      ..color = Colors.white
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(0, size.height * 0.29), Offset(size.width, size.height * 0.29), road);
    canvas.drawLine(Offset(0, size.height * 0.545), Offset(size.width, size.height * 0.545), road);
    canvas.drawLine(Offset(0, size.height * 0.81), Offset(size.width, size.height * 0.81), minor);
    canvas.drawLine(Offset(size.width * 0.19, 0), Offset(size.width * 0.19, size.height), road);
    canvas.drawLine(Offset(size.width * 0.50, 0), Offset(size.width * 0.50, size.height), road);
    canvas.drawLine(Offset(size.width * 0.73, 0), Offset(size.width * 0.73, size.height), minor);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
