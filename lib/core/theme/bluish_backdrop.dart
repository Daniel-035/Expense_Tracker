import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Soft bluish gradient + light geometric texture.
class BluishBackdrop extends StatelessWidget {
  const BluishBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? const [
                      Color(0xFF0B1220),
                      Color(0xFF10233F),
                      Color(0xFF0B1A2E),
                    ]
                  : const [
                      Color(0xFFF7FBFF),
                      Color(0xFFEEF5FF),
                      Color(0xFFE0F2FE),
                    ],
            ),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: _BlueTexturePainter(
              color: isDark
                  ? const Color(0xFF60A5FA).withValues(alpha: 0.06)
                  : AppColors.azure.withValues(alpha: 0.06),
            ),
          ),
        ),
        Positioned(
          top: -80,
          right: -40,
          child: _GlowOrb(
            size: 220,
            color: isDark
                ? const Color(0xFF2563EB).withValues(alpha: 0.25)
                : AppColors.sky.withValues(alpha: 0.22),
          ),
        ),
        Positioned(
          bottom: 80,
          left: -60,
          child: _GlowOrb(
            size: 180,
            color: isDark
                ? const Color(0xFF38BDF8).withValues(alpha: 0.14)
                : AppColors.ice.withValues(alpha: 0.28),
          ),
        ),
        child,
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

class _BlueTexturePainter extends CustomPainter {
  _BlueTexturePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const step = 28.0;
    for (double x = 0; x < size.width + step; x += step) {
      for (double y = 0; y < size.height + step; y += step) {
        final phase = ((x + y) / step) % 4;
        if (phase < 1) {
          canvas.drawCircle(Offset(x, y), 1.4, paint);
        } else if (phase < 2) {
          canvas.drawLine(
            Offset(x - 3, y),
            Offset(x + 3, y),
            paint,
          );
        }
      }
    }

    final wave = Paint()
      ..color = color.withValues(alpha: color.a * 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final path = Path();
    path.moveTo(0, size.height * 0.35);
    for (double x = 0; x <= size.width; x += 8) {
      final y = size.height * 0.35 +
          math.sin(x / 42) * 10 +
          math.cos(x / 70) * 6;
      path.lineTo(x, y);
    }
    canvas.drawPath(path, wave);
  }

  @override
  bool shouldRepaint(covariant _BlueTexturePainter oldDelegate) =>
      oldDelegate.color != color;
}
