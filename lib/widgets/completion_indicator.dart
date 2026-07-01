import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class CompletionIndicator extends StatelessWidget {
  const CompletionIndicator({
    super.key,
    required this.completed,
    required this.total,
    this.size = 32,
    this.compact = false,
  });

  final int completed;
  final int total;
  final double size;
  final bool compact;

  double get ratio => total == 0 ? 0 : completed / total;

  @override
  Widget build(BuildContext context) {
    if (total == 0) {
      return SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.divider.withValues(alpha: 0.4)),
          ),
        ),
      );
    }

    if (completed >= total) {
      return SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.potty,
          ),
          child: Icon(Icons.check, color: Colors.white, size: size * 0.55),
        ),
      );
    }

    const strokeWidth = 3.0;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _ProgressRingPainter(
              progress: ratio.clamp(0.0, 1.0),
              backgroundColor: AppColors.feedBg,
              foregroundColor: AppColors.feed,
              strokeWidth: strokeWidth,
            ),
          ),
          if (!compact && completed > 0)
            Text(
              '$completed',
              style: TextStyle(
                fontSize: size * 0.28,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  const _ProgressRingPainter({
    required this.progress,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color backgroundColor;
  final Color foregroundColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final foregroundPaint = Paint()
      ..color = foregroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        foregroundPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.foregroundColor != foregroundColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
