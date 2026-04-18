import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:taal/design/colors.dart';

/// A circular progress ring showing daily goal completion.
///
/// Fills from teal (start) → gold (complete) with an animated sweep.
class DailyGoalRing extends StatelessWidget {
  const DailyGoalRing({
    super.key,
    required this.progress,
    this.size = 64.0,
    this.strokeWidth = 6.0,
    this.child,
  });

  /// Value from 0.0 to 1.0.
  final double progress;

  /// Diameter of the ring.
  final double size;

  /// Width of the arc stroke.
  final double strokeWidth;

  /// Optional widget rendered in the center of the ring.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(
              progress: progress.clamp(0.0, 1.0),
              trackColor: scheme.surfaceContainerHighest,
              strokeWidth: strokeWidth,
            ),
          ),
          ?child,
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track (background ring).
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;

    // Gradient fill: teal → gold.
    final fillPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: -math.pi / 2 + 2 * math.pi * progress,
        colors: const [
          TaalColors.gradePerfect, // teal
          TaalColors.comboActive, // gold
        ],
        stops: const [0.0, 1.0],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect);

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(rect, -math.pi / 2, sweepAngle, false, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

/// Streak counter with a flame icon and day count.
class StreakCounter extends StatelessWidget {
  const StreakCounter({
    super.key,
    required this.days,
    this.message,
  });

  final int days;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isActive = days > 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.local_fire_department,
          color: isActive ? TaalColors.comboActive : scheme.onSurfaceVariant,
          size: 24,
        ),
        const SizedBox(width: 4),
        Text(
          '$days day${days == 1 ? '' : 's'}',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: isActive ? null : scheme.onSurfaceVariant,
              ),
        ),
        if (message != null) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message!,
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}

/// A 7-day practice grid showing practiced vs. skipped days.
class WeeklyPracticeGrid extends StatelessWidget {
  const WeeklyPracticeGrid({
    super.key,
    required this.daysPracticed,
    this.totalDays = 7,
  });

  final int daysPracticed;
  final int totalDays;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final practiced = daysPracticed.clamp(0, totalDays);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(totalDays, (index) {
        final isPracticed = index < practiced;
        return Padding(
          padding: EdgeInsets.only(right: index < totalDays - 1 ? 4.0 : 0),
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: isPracticed
                  ? TaalColors.gradePerfect
                  : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }
}
