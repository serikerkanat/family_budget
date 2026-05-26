import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A whimsical tree that grows with [progress] (0..1). At 0 it's a tiny
/// sprout; at 1 it's a full canopy with fruit. Used as a gamified savings
/// progress indicator in Kids Mode.
class GrowingTree extends StatelessWidget {
  final double progress; // 0..1
  final double size;
  final String? label;

  const GrowingTree({
    super.key,
    required this.progress,
    this.size = 220,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final p = progress.clamp(0.0, 1.0);
    return Column(
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(painter: _TreePainter(progress: p)),
        ),
        if (label != null) ...[
          const SizedBox(height: 8),
          Text(
            label!,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF065F46),
            ),
          ),
        ],
      ],
    );
  }
}

class _TreePainter extends CustomPainter {
  final double progress;
  _TreePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final groundY = h * 0.92;

    // Ground
    final groundPaint = Paint()..color = const Color(0xFFA7F3D0);
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(w / 2, groundY),
          width: w * 0.85,
          height: h * 0.12),
      groundPaint,
    );

    if (progress <= 0.001) {
      // Seed in the ground
      final seedPaint = Paint()..color = const Color(0xFF92400E);
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(w / 2, groundY),
            width: w * 0.08,
            height: h * 0.04),
        seedPaint,
      );
      return;
    }

    // Trunk grows from 10% to 55% of height
    final trunkHeight = h * (0.10 + 0.45 * progress);
    final trunkWidth = w * (0.04 + 0.05 * progress);
    final trunkPaint = Paint()
      ..color = const Color(0xFF78350F)
      ..style = PaintingStyle.fill;
    final trunkRect = Rect.fromCenter(
      center: Offset(w / 2, groundY - trunkHeight / 2),
      width: trunkWidth,
      height: trunkHeight,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(trunkRect, Radius.circular(trunkWidth / 2)),
      trunkPaint,
    );

    // Canopy
    final canopyRadius = w * (0.10 + 0.25 * progress);
    final canopyCenter = Offset(w / 2, groundY - trunkHeight - canopyRadius * 0.4);

    // Leaves — three overlapping circles for a puffy look.
    final leafPaints = [
      Paint()..color = const Color(0xFF34D399),
      Paint()..color = const Color(0xFF10B981),
      Paint()..color = const Color(0xFF059669),
    ];
    final offsets = [
      Offset(-canopyRadius * 0.5, 0),
      Offset(canopyRadius * 0.5, -canopyRadius * 0.1),
      Offset(0, -canopyRadius * 0.5),
    ];
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(
        canopyCenter + offsets[i],
        canopyRadius * 0.85,
        leafPaints[i],
      );
    }

    // Fruit/flowers appear past 60% progress.
    if (progress > 0.6) {
      final fruitCount = ((progress - 0.6) / 0.1).round().clamp(1, 6);
      final fruitPaint = Paint()..color = const Color(0xFFEF4444);
      final rng = math.Random(42);
      for (var i = 0; i < fruitCount; i++) {
        final angle = rng.nextDouble() * 2 * math.pi;
        final radius = canopyRadius * (0.4 + rng.nextDouble() * 0.4);
        final pos = canopyCenter +
            Offset(math.cos(angle) * radius, math.sin(angle) * radius);
        canvas.drawCircle(pos, canopyRadius * 0.10, fruitPaint);
      }
    }

    // Sparkle when fully grown
    if (progress >= 0.999) {
      final star = Paint()..color = const Color(0xFFFBBF24);
      for (var i = 0; i < 5; i++) {
        final angle = (i / 5) * 2 * math.pi;
        final pos = canopyCenter +
            Offset(
              math.cos(angle) * canopyRadius * 1.15,
              math.sin(angle) * canopyRadius * 1.15,
            );
        _drawStar(canvas, pos, 6, star);
      }
    }
  }

  void _drawStar(Canvas canvas, Offset c, double r, Paint paint) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final radius = i.isEven ? r : r * 0.45;
      final angle = -math.pi / 2 + (i * math.pi / 5);
      final p =
          c + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TreePainter old) =>
      old.progress != progress;
}
