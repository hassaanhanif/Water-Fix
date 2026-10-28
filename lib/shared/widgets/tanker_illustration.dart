import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Custom painter that draws the exact WaterFix tanker truck with water droplet
/// seen across the PDF screens (Welcome, Home, Supplier Profile, Compare Suppliers).
class TankerTruckPainter extends CustomPainter {
  final Color truckColor;
  final Color dropletColor;
  final bool showDroplet;

  const TankerTruckPainter({
    this.truckColor = WaterFixColors.tankerBlue,
    this.dropletColor = Colors.white,
    this.showDroplet = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final bodyPaint = Paint()
      ..color = truckColor
      ..style = PaintingStyle.fill;

    // 1. Elliptical/rounded cylindrical water tank on the left
    final tankRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.06, h * 0.22, w * 0.56, h * 0.42),
      Radius.circular(h * 0.21),
    );
    canvas.drawRRect(tankRect, bodyPaint);

    // 2. Chassis bar connecting tank and cab
    final chassisRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.16, h * 0.58, w * 0.72, h * 0.08),
      Radius.circular(h * 0.03),
    );
    canvas.drawRRect(chassisRect, bodyPaint);

    // 3. Truck cab on the right
    final cabPath = Path()
      ..moveTo(w * 0.65, h * 0.34)
      ..lineTo(w * 0.84, h * 0.34)
      ..quadraticBezierTo(w * 0.90, h * 0.34, w * 0.92, h * 0.46)
      ..lineTo(w * 0.94, h * 0.64)
      ..lineTo(w * 0.65, h * 0.64)
      ..close();
    canvas.drawPath(cabPath, bodyPaint);

    // 4. Cab window cutout (white)
    final windowPaint = Paint()
      ..color = dropletColor
      ..style = PaintingStyle.fill;
    final windowPath = Path()
      ..moveTo(w * 0.70, h * 0.40)
      ..lineTo(w * 0.83, h * 0.40)
      ..lineTo(w * 0.87, h * 0.50)
      ..lineTo(w * 0.70, h * 0.50)
      ..close();
    canvas.drawPath(windowPath, windowPaint);

    // 5. Water droplet inside the tank
    if (showDroplet) {
      final dropCenterX = w * 0.34;
      final dropTopY = h * 0.30;
      final dropPath = Path()
        ..moveTo(dropCenterX, dropTopY)
        ..cubicTo(
          dropCenterX + w * 0.09,
          dropTopY + h * 0.12,
          dropCenterX + w * 0.08,
          dropTopY + h * 0.24,
          dropCenterX,
          dropTopY + h * 0.24,
        )
        ..cubicTo(
          dropCenterX - w * 0.08,
          dropTopY + h * 0.24,
          dropCenterX - w * 0.09,
          dropTopY + h * 0.12,
          dropCenterX,
          dropTopY,
        )
        ..close();
      canvas.drawPath(dropPath, windowPaint);
    }

    // 6. Front and rear wheels
    final wheelOuterPaint = Paint()
      ..color = const Color(0xFF142B3E)
      ..style = PaintingStyle.fill;
    final wheelRadius = h * 0.115;

    final rearWheelCenter = Offset(w * 0.28, h * 0.69);
    final frontWheelCenter = Offset(w * 0.79, h * 0.69);

    canvas.drawCircle(rearWheelCenter, wheelRadius, wheelOuterPaint);
    canvas.drawCircle(rearWheelCenter, wheelRadius * 0.44, windowPaint);

    canvas.drawCircle(frontWheelCenter, wheelRadius, wheelOuterPaint);
    canvas.drawCircle(frontWheelCenter, wheelRadius * 0.44, windowPaint);
  }

  @override
  bool shouldRepaint(covariant TankerTruckPainter oldDelegate) => false;
}

class TankerIllustration extends StatelessWidget {
  final double width;
  final double height;
  final bool showDroplet;

  const TankerIllustration({
    super.key,
    this.width = 110,
    this.height = 76,
    this.showDroplet = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(painter: TankerTruckPainter(showDroplet: showDroplet)),
    );
  }
}

/// Small square pastel icon card used in supplier list items (Screen 2, 3, 6, 7).
class SupplierTankerAvatar extends StatelessWidget {
  final double size;
  final Color backgroundColor;

  const SupplierTankerAvatar({
    super.key,
    this.size = 56,
    this.backgroundColor = WaterFixColors.pastelBlueCard,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      alignment: Alignment.center,
      child: TankerIllustration(
        width: size * 0.72,
        height: size * 0.52,
        showDroplet: false,
      ),
    );
  }
}

/// Tilted sky-blue rounded square with tanker illustration used in Welcome & Home hero cards.
class TiltedTankerBadge extends StatelessWidget {
  final double size;

  const TiltedTankerBadge({super.key, this.size = 130});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 8 * (math.pi / 180),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: WaterFixColors.skyBlue,
          borderRadius: BorderRadius.circular(size * 0.24),
        ),
        alignment: Alignment.center,
        child: TankerIllustration(
          width: size * 0.74,
          height: size * 0.54,
          showDroplet: true,
        ),
      ),
    );
  }
}
