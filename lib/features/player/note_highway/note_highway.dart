import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:taal/design/colors.dart';

class NoteHighwayWidget extends StatelessWidget {
  const NoteHighwayWidget({
    super.key,
    required this.lanes,
    required this.notes,
    required this.currentTimeMs,
    this.feedback = const [],
    this.pixelsPerSecond = 260,
    this.pastWindowMs = 500,
    this.lookaheadMs = 3000,
  });

  final List<NoteHighwayLane> lanes;
  final List<NoteHighwayNote> notes;
  final List<NoteHighwayFeedback> feedback;
  final double currentTimeMs;
  final double pixelsPerSecond;
  final double pastWindowMs;
  final double lookaheadMs;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 640.0;
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 420.0;
        return CustomPaint(
          size: Size(width, height),
          painter: NoteHighwayPainter(
            lanes: lanes,
            notes: notes,
            feedback: feedback,
            currentTimeMs: currentTimeMs,
            pixelsPerSecond: pixelsPerSecond,
            pastWindowMs: pastWindowMs,
            lookaheadMs: lookaheadMs,
            colorScheme: Theme.of(context).colorScheme,
          ),
        );
      },
    );
  }
}

class NoteHighwayLane {
  const NoteHighwayLane({
    required this.laneId,
    required this.label,
    required this.color,
  });

  final String laneId;
  final String label;
  final Color color;
}

class NoteHighwayNote {
  const NoteHighwayNote({
    required this.expectedId,
    required this.laneId,
    required this.tMs,
  });

  final String expectedId;
  final String laneId;
  final double tMs;
}

class NoteHighwayFeedback {
  const NoteHighwayFeedback({
    required this.expectedId,
    required this.laneId,
    required this.tMs,
    required this.deltaMs,
    required this.grade,
  });

  final String expectedId;
  final String laneId;
  final double tMs;
  final double deltaMs;
  final NoteHighwayGrade grade;
}

enum NoteHighwayGrade { perfect, good, early, late, miss }

class NoteHighwayGeometry {
  const NoteHighwayGeometry({
    required this.size,
    required this.laneCount,
    this.hitLineFraction = 0.72,
    this.horizontalPadding = 20,
    this.markerMaxOffsetFraction = 0.28,
    this.markerWindowMs = 120,
  }) : assert(laneCount > 0, 'laneCount must be positive');

  final Size size;
  final int laneCount;
  final double hitLineFraction;
  final double horizontalPadding;
  final double markerMaxOffsetFraction;
  final double markerWindowMs;

  double get hitLineY => size.height * hitLineFraction;

  double get laneWidth {
    final usableWidth = math.max(0.0, size.width - horizontalPadding * 2);
    return usableWidth / laneCount;
  }

  Rect laneRect(int laneIndex) {
    final left = horizontalPadding + laneIndex * laneWidth;
    return Rect.fromLTWH(left, 0, laneWidth, size.height);
  }

  Offset noteCenter({
    required int laneIndex,
    required double eventTimeMs,
    required double currentTimeMs,
    required double pixelsPerSecond,
  }) {
    final rect = laneRect(laneIndex);
    final pixelsPerMs = pixelsPerSecond / 1000.0;
    final y = hitLineY - (eventTimeMs - currentTimeMs) * pixelsPerMs;
    return Offset(rect.center.dx, y);
  }

  Offset feedbackCenter({required int laneIndex, required double deltaMs}) {
    final rect = laneRect(laneIndex);
    final clamped = (deltaMs / markerWindowMs).clamp(-1.0, 1.0);
    final xOffset = rect.width * markerMaxOffsetFraction * clamped;
    return Offset(rect.center.dx + xOffset, hitLineY);
  }
}

class NoteHighwayPainter extends CustomPainter {
  const NoteHighwayPainter({
    required this.lanes,
    required this.notes,
    required this.feedback,
    required this.currentTimeMs,
    required this.pixelsPerSecond,
    required this.pastWindowMs,
    required this.lookaheadMs,
    required this.colorScheme,
  });

  final List<NoteHighwayLane> lanes;
  final List<NoteHighwayNote> notes;
  final List<NoteHighwayFeedback> feedback;
  final double currentTimeMs;
  final double pixelsPerSecond;
  final double pastWindowMs;
  final double lookaheadMs;
  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    if (lanes.isEmpty) {
      _paintEmpty(canvas, size);
      return;
    }

    final geometry = NoteHighwayGeometry(size: size, laneCount: lanes.length);
    _paintLanes(canvas, size, geometry);
    _paintHitLine(canvas, size, geometry.hitLineY);
    _paintNotes(canvas, geometry);
    _paintFeedback(canvas, geometry);
    _paintLaneLabels(canvas, size, geometry);
  }

  void _paintEmpty(Canvas canvas, Size size) {
    final paint = Paint()..color = colorScheme.surfaceContainerHighest;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)),
      paint,
    );
  }

  void _paintLanes(Canvas canvas, Size size, NoteHighwayGeometry geometry) {
    final separatorPaint = Paint()
      ..color = colorScheme.outlineVariant.withValues(alpha: 0.4)
      ..strokeWidth = 1;

    for (var index = 0; index < lanes.length; index += 1) {
      final rect = geometry.laneRect(index);
      // Subtle top-to-bottom gradient per lane.
      final laneGradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.alphaBlend(
            lanes[index].color.withValues(alpha: 0.06),
            colorScheme.surface,
          ),
          Color.alphaBlend(
            lanes[index].color.withValues(alpha: 0.16),
            colorScheme.surface,
          ),
        ],
      );
      canvas.drawRect(
        rect,
        Paint()..shader = laneGradient.createShader(rect),
      );
      canvas.drawLine(rect.topRight, rect.bottomRight, separatorPaint);
    }

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = colorScheme.outlineVariant.withValues(alpha: 0.5),
    );
  }

  void _paintHitLine(Canvas canvas, Size size, double hitLineY) {
    // Soft glow behind the hit line.
    final glowRect = Rect.fromLTWH(0, hitLineY - 6, size.width, 12);
    final glowGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        colorScheme.secondary.withValues(alpha: 0.0),
        colorScheme.secondary.withValues(alpha: 0.22),
        colorScheme.secondary.withValues(alpha: 0.22),
        colorScheme.secondary.withValues(alpha: 0.0),
      ],
      stops: const [0.0, 0.35, 0.65, 1.0],
    );
    canvas.drawRect(
      glowRect,
      Paint()..shader = glowGradient.createShader(glowRect),
    );

    // Main hit line.
    final paint = Paint()
      ..color = colorScheme.secondary
      ..strokeWidth = 2.5;
    canvas.drawLine(Offset(0, hitLineY), Offset(size.width, hitLineY), paint);
  }

  void _paintNotes(Canvas canvas, NoteHighwayGeometry geometry) {
    for (final note in notes) {
      final laneIndex = lanes.indexWhere((lane) => lane.laneId == note.laneId);
      if (laneIndex < 0) {
        continue;
      }
      final relativeMs = note.tMs - currentTimeMs;
      if (relativeMs < -pastWindowMs || relativeMs > lookaheadMs) {
        continue;
      }
      final center = geometry.noteCenter(
        laneIndex: laneIndex,
        eventTimeMs: note.tMs,
        currentTimeMs: currentTimeMs,
        pixelsPerSecond: pixelsPerSecond,
      );
      final laneColor = lanes[laneIndex].color;

      // Approaching glow: notes brighten as they approach the hit line.
      // Proximity 0.0 = far away, 1.0 = at the hit line.
      final proximity = relativeMs > 0
          ? (1.0 - (relativeMs / lookaheadMs)).clamp(0.0, 1.0)
          : 0.0;
      final glowAlpha = 0.15 + 0.55 * proximity;

      // Past-window fade: notes fade out over ~300ms after passing.
      final fadeAlpha = relativeMs < 0
          ? (1.0 - (-relativeMs / pastWindowMs).clamp(0.0, 1.0))
          : 1.0;

      final noteAlpha = (glowAlpha * fadeAlpha).clamp(0.0, 1.0);
      final noteColor = laneColor.withValues(alpha: noteAlpha);

      // Note pill with rounded ends.
      final pillRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: 36, height: 16),
        const Radius.circular(8),
      );

      // Glow halo for approaching notes.
      if (proximity > 0.4) {
        final haloOpacity = (proximity - 0.4) * 1.2;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: center, width: 44, height: 24),
            const Radius.circular(12),
          ),
          Paint()..color = laneColor.withValues(alpha: 0.18 * haloOpacity),
        );
      }

      // Gradient fill on the note pill.
      final pillGradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          noteColor,
          Color.alphaBlend(
            Colors.black.withValues(alpha: 0.2),
            noteColor,
          ),
        ],
      );
      canvas.drawRRect(
        pillRect,
        Paint()..shader = pillGradient.createShader(pillRect.outerRect),
      );

      // Subtle outline.
      canvas.drawRRect(
        pillRect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = laneColor.withValues(alpha: 0.5 * fadeAlpha),
      );
    }
  }

  void _paintFeedback(Canvas canvas, NoteHighwayGeometry geometry) {
    for (final marker in feedback) {
      final laneIndex = lanes.indexWhere(
        (lane) => lane.laneId == marker.laneId,
      );
      if (laneIndex < 0) {
        continue;
      }
      final center = geometry.feedbackCenter(
        laneIndex: laneIndex,
        deltaMs: marker.deltaMs,
      );
      final color = gradeColor(marker.grade, colorScheme);

      switch (marker.grade) {
        case NoteHighwayGrade.perfect:
          // Perfect: bright core + expanding ring.
          canvas.drawCircle(center, 10, Paint()..color = color);
          canvas.drawCircle(
            center,
            16,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5
              ..color = color.withValues(alpha: 0.7),
          );
          canvas.drawCircle(
            center,
            22,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2
              ..color = color.withValues(alpha: 0.3),
          );

        case NoteHighwayGrade.good:
          // Good: solid core + single ring.
          canvas.drawCircle(center, 9, Paint()..color = color);
          canvas.drawCircle(
            center,
            14,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = color.withValues(alpha: 0.65),
          );

        case NoteHighwayGrade.early:
        case NoteHighwayGrade.late:
          // Early/Late: colored dot offset from center.
          canvas.drawCircle(center, 8, Paint()..color = color);
          canvas.drawCircle(
            center,
            12,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5
              ..color = color.withValues(alpha: 0.5),
          );

        case NoteHighwayGrade.miss:
          // Miss: dim hollow outline + faded cross.
          canvas.drawCircle(
            center,
            9,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.8
              ..color = color.withValues(alpha: 0.5),
          );
          final crossPaint = Paint()
            ..strokeWidth = 1.5
            ..color = color.withValues(alpha: 0.35);
          canvas.drawLine(
            Offset(center.dx - 5, center.dy - 5),
            Offset(center.dx + 5, center.dy + 5),
            crossPaint,
          );
          canvas.drawLine(
            Offset(center.dx + 5, center.dy - 5),
            Offset(center.dx - 5, center.dy + 5),
            crossPaint,
          );
      }
    }
  }

  void _paintLaneLabels(
    Canvas canvas,
    Size size,
    NoteHighwayGeometry geometry,
  ) {
    for (var index = 0; index < lanes.length; index += 1) {
      final rect = geometry.laneRect(index);
      final painter = TextPainter(
        text: TextSpan(
          text: lanes[index].label,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '',
      )..layout(maxWidth: rect.width - 8);
      painter.paint(
        canvas,
        Offset(rect.left + (rect.width - painter.width) / 2, size.height - 24),
      );
    }
  }

  @override
  bool shouldRepaint(covariant NoteHighwayPainter oldDelegate) {
    return oldDelegate.lanes != lanes ||
        oldDelegate.notes != notes ||
        oldDelegate.feedback != feedback ||
        oldDelegate.currentTimeMs != currentTimeMs ||
        oldDelegate.pixelsPerSecond != pixelsPerSecond ||
        oldDelegate.pastWindowMs != pastWindowMs ||
        oldDelegate.lookaheadMs != lookaheadMs ||
        oldDelegate.colorScheme != colorScheme;
  }
}

Color gradeColor(NoteHighwayGrade grade, ColorScheme scheme) {
  switch (grade) {
    case NoteHighwayGrade.perfect:
      return TaalColors.gradePerfect;
    case NoteHighwayGrade.good:
      return TaalColors.gradeGood;
    case NoteHighwayGrade.early:
      return TaalColors.gradeEarly;
    case NoteHighwayGrade.late:
      return TaalColors.gradeLate;
    case NoteHighwayGrade.miss:
      return TaalColors.gradeMiss;
  }
}
