import 'dart:async';
import 'package:flutter/material.dart';
import 'driver_arrived_screen.dart';

class LiveTrackingScreen extends StatefulWidget {
  final dynamic driver;

  const LiveTrackingScreen({super.key, required this.driver});

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _mapAnimationController;
  late Animation<double> _movementAnimation;

  static const Color _navy = Color(0xFF003F7D);
  static const Color _navyLight = Color(0xFFE6EEF8);

  double _distanceLeft = 1.2;
  int _minutesLeft = 8;

  @override
  void initState() {
    super.initState();
    _mapAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );

    _movementAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mapAnimationController, curve: Curves.linear),
    )..addListener(() {
        setState(() {
          _distanceLeft = (1.2 * (1.0 - _movementAnimation.value)).clamp(0.0, 1.2);
          _minutesLeft = (8 * (1.0 - _movementAnimation.value)).ceil().clamp(0, 8);
        });
      });

    _mapAnimationController.forward();

    _mapAnimationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DriverArrivedScreen(driver: widget.driver),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _mapAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String driverName = widget.driver.name ?? 'Suresh Patil';
    final String vehicleInfo = widget.driver.vehicle ?? 'Mini Truck';
    final String vehicleNumber = widget.driver.number ?? 'MH 14 AB 1234';

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
          'Live Tracking',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _movementAnimation,
              builder: (context, child) {
                return CustomPaint(
                  painter: _TrackingMapPainter(
                    progress: _movementAnimation.value,
                    navyColor: _navy,
                  ),
                );
              },
            ),
          ),
          
          Positioned(
            top: 16,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2ECC71),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Driver on the way',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_minutesLeft} min',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: _navy,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 15,
                    offset: Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: _navyLight.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Driver is',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.black54,
                            ),
                          ),
                          Text(
                            '${_distanceLeft.toStringAsFixed(1)} km away',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _navy,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _navyLight,
                          ),
                          child: const Icon(Icons.person, color: _navy, size: 28),
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
                                '$vehicleInfo · $vehicleNumber',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFE8F5E9),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.phone, color: Color(0xFF2ECC71), size: 20),
                            onPressed: () {},
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackingMapPainter extends CustomPainter {
  final double progress;
  final Color navyColor;

  _TrackingMapPainter({required this.progress, required this.navyColor});

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFFE8EDF2);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bg);

    final blockPaint = Paint()..color = const Color(0xFFD6DCE4);
    final blocks = [
      Rect.fromLTWH(20, 80, size.width * 0.4, size.height * 0.2),
      Rect.fromLTWH(size.width * 0.52, 80, size.width * 0.4, size.height * 0.2),
      Rect.fromLTWH(20, size.height * 0.35, size.width * 0.4, size.height * 0.25),
      Rect.fromLTWH(size.width * 0.52, size.height * 0.35, size.width * 0.4, size.height * 0.25),
    ];
    for (final block in blocks) {
      canvas.drawRect(block, blockPaint);
    }

    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 18
      ..style = PaintingStyle.stroke;
    
    final roadBorderPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 22
      ..style = PaintingStyle.stroke;

    final path = Path();
    final double startX = size.width * 0.25;
    final double startY = size.height * 0.70;
    final double midY = size.height * 0.32;
    final double endX = size.width * 0.75;
    final double endY = size.height * 0.32;

    path.moveTo(startX, startY);
    path.lineTo(startX, midY);
    path.lineTo(endX, endY);

    canvas.drawPath(path, roadBorderPaint);
    canvas.drawPath(path, roadPaint);

    final pinPaint = Paint()
      ..color = navyColor
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(Offset(endX, endY), 16, pinPaint);
    canvas.drawCircle(
      Offset(endX, endY),
      12,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset(endX, endY),
      6,
      Paint()
        ..color = navyColor
        ..style = PaintingStyle.fill,
    );

    final double vLen = (startY - midY).abs();
    final double hLen = (endX - startX).abs();
    final double totalLen = vLen + hLen;
    final double currentLen = progress * totalLen;

    double truckX = startX;
    double truckY = startY;

    if (currentLen <= vLen) {
      truckY = startY - currentLen;
    } else {
      truckY = midY;
      truckX = startX + (currentLen - vLen);
    }

    canvas.drawCircle(
      Offset(truckX, truckY),
      20,
      Paint()
        ..color = navyColor.withOpacity(0.2)
        ..style = PaintingStyle.fill,
    );
    
    canvas.drawCircle(Offset(truckX, truckY), 15, pinPaint);

    const textStyle = TextStyle(
      color: Colors.white,
      fontFamily: 'MaterialIcons',
      fontSize: 16,
    );
    final textPainter = TextPainter(
      text: const TextSpan(
        text: '\ue395', // Use direct unicode escape string for Icon instead of fromCharCode
        style: textStyle,
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(truckX - 8, truckY - 8),
    );
  }

  @override
  bool shouldRepaint(covariant _TrackingMapPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
