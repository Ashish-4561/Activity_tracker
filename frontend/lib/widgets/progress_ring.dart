import 'dart:math';
import 'package:flutter/material.dart';
import '../services/theme_service.dart';

/// Premium multi-layered circular progress ring with gradient arc,
/// soft inner depth, and animated progress display.
class ProgressRing extends StatelessWidget {
  final double percentage; // 0 to 100
  final int completedCount;
  final int totalCount;
  final double size;
  final double strokeWidth;
  final String? subtitle;

  const ProgressRing({
    super.key,
    required this.percentage,
    required this.completedCount,
    required this.totalCount,
    this.size = 180,
    this.strokeWidth = 14,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final clampedPct = percentage.clamp(0.0, 100.0);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Inner soft shadow background circle
          Container(
            width: size - strokeWidth * 2 - 12,
            height: size - strokeWidth * 2 - 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? AppColors.darkSurfaceRaised : AppColors.lightSurfaceRaised,
              boxShadow: [
                BoxShadow(
                  color: isDark ? const Color(0x60080B10) : const Color(0x1594A3B8),
                  blurRadius: 10,
                  spreadRadius: -2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),

          // Custom Painted Arc
          CustomPaint(
            size: Size(size, size),
            painter: _ProgressRingPainter(
              percentage: clampedPct,
              strokeWidth: strokeWidth,
              trackColor: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
              gradientStart: clampedPct >= 100 ? AppColors.emeraldSuccess : AppColors.primary,
              gradientEnd: clampedPct >= 100 ? const Color(0xFF6EE7D8) : AppColors.secondaryAqua,
            ),
          ),

          // Center Stats
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${clampedPct.toInt()}%',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: size * 0.20,
                  letterSpacing: -1,
                  color: clampedPct >= 100
                      ? AppColors.emeraldSuccess
                      : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$completedCount of $totalCount completed',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: size * 0.075,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: size * 0.065,
                    color: AppColors.cyanAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  final double percentage;
  final double strokeWidth;
  final Color trackColor;
  final Color gradientStart;
  final Color gradientEnd;

  _ProgressRingPainter({
    required this.percentage,
    required this.strokeWidth,
    required this.trackColor,
    required this.gradientStart,
    required this.gradientEnd,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background track paint
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    if (percentage <= 0) return;

    // Progress arc paint
    final sweepAngle = 2 * pi * (percentage / 100);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final sweepGradient = SweepGradient(
      startAngle: -pi / 2,
      endAngle: -pi / 2 + sweepAngle,
      colors: [gradientStart, gradientEnd],
      tileMode: TileMode.clamp,
    );

    final progressPaint = Paint()
      ..shader = sweepGradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect,
      -pi / 2, // Start at 12 o'clock
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) {
    return oldDelegate.percentage != percentage ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.gradientStart != gradientStart ||
        oldDelegate.gradientEnd != gradientEnd;
  }
}
