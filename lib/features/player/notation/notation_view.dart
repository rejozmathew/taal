import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:taal/features/player/note_highway/note_highway.dart';

class NotationViewWidget extends StatelessWidget {
  const NotationViewWidget({
    super.key,
    required this.notes,
    required this.currentTimeMs,
    this.feedback = const [],
    this.pixelsPerSecond = 180,
    this.pastWindowMs = 1200,
    this.lookaheadMs = 4200,
    this.displayMode = NotationDisplayMode.scrolling,
    this.pageStartMs = 0,
    this.pageDurationMs = 8000,
    this.measureMs = 2000,
    this.placements = defaultDrumPlacements,
  });

  final List<NotationNote> notes;
  final List<NotationFeedback> feedback;
  final double currentTimeMs;
  final double pixelsPerSecond;
  final double pastWindowMs;
  final double lookaheadMs;
  final NotationDisplayMode displayMode;
  final double pageStartMs;
  final double pageDurationMs;
  final double measureMs;
  final Map<String, NotationLanePlacement> placements;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 720.0;
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 360.0;
        return CustomPaint(
          size: Size(width, height),
          painter: NotationViewPainter(
            notes: notes,
            feedback: feedback,
            currentTimeMs: currentTimeMs,
            pixelsPerSecond: pixelsPerSecond,
            pastWindowMs: pastWindowMs,
            lookaheadMs: lookaheadMs,
            displayMode: displayMode,
            pageStartMs: pageStartMs,
            pageDurationMs: pageDurationMs,
            measureMs: measureMs,
            placements: placements,
            colorScheme: Theme.of(context).colorScheme,
          ),
        );
      },
    );
  }
}

enum NotationDisplayMode { scrolling, page }

class NotationNote {
  const NotationNote({
    required this.expectedId,
    required this.laneId,
    required this.tMs,
    this.articulation = 'normal',
  });

  final String expectedId;
  final String laneId;
  final double tMs;
  final String articulation;
}

class NotationFeedback {
  const NotationFeedback({
    required this.expectedId,
    required this.laneId,
    required this.tMs,
    required this.grade,
    this.deltaMs = 0,
  });

  final String expectedId;
  final String laneId;
  final double tMs;
  final NoteHighwayGrade grade;
  final double deltaMs;
}

class NotationLanePlacement {
  const NotationLanePlacement({
    required this.laneId,
    required this.label,
    required this.staffPosition,
    this.cross = false,
    this.stemUp = true,
  });

  final String laneId;
  final String label;
  final double staffPosition;
  final bool cross;
  final bool stemUp;
}

const defaultDrumPlacements = <String, NotationLanePlacement>{
  'crash': NotationLanePlacement(
    laneId: 'crash',
    label: 'Crash',
    staffPosition: -2,
    cross: true,
    stemUp: false,
  ),
  'ride': NotationLanePlacement(
    laneId: 'ride',
    label: 'Ride',
    staffPosition: -1,
    cross: true,
    stemUp: false,
  ),
  'hihat_closed': NotationLanePlacement(
    laneId: 'hihat_closed',
    label: 'Hi-hat',
    staffPosition: -1,
    cross: true,
    stemUp: false,
  ),
  'hihat_open': NotationLanePlacement(
    laneId: 'hihat_open',
    label: 'Open hat',
    staffPosition: -1,
    cross: true,
    stemUp: false,
  ),
  'hihat': NotationLanePlacement(
    laneId: 'hihat',
    label: 'Hi-hat',
    staffPosition: -1,
    cross: true,
    stemUp: false,
  ),
  'snare': NotationLanePlacement(
    laneId: 'snare',
    label: 'Snare',
    staffPosition: 4,
  ),
  'tom_high': NotationLanePlacement(
    laneId: 'tom_high',
    label: 'High tom',
    staffPosition: 3,
  ),
  'tom_low': NotationLanePlacement(
    laneId: 'tom_low',
    label: 'Low tom',
    staffPosition: 5,
  ),
  'tom_floor': NotationLanePlacement(
    laneId: 'tom_floor',
    label: 'Floor tom',
    staffPosition: 6,
  ),
  'kick': NotationLanePlacement(
    laneId: 'kick',
    label: 'Kick',
    staffPosition: 9,
    stemUp: false,
  ),
};

class NotationGeometry {
  const NotationGeometry({
    required this.size,
    this.leftPadding = 56,
    this.rightPadding = 24,
    this.staffTopFraction = 0.28,
    this.staffLineGap = 18,
    this.playheadFraction = 0.28,
  });

  final Size size;
  final double leftPadding;
  final double rightPadding;
  final double staffTopFraction;
  final double staffLineGap;
  final double playheadFraction;

  double get contentLeft => leftPadding;

  double get contentRight => size.width - rightPadding;

  double get contentWidth => math.max(1, contentRight - contentLeft);

  double get staffTopY => size.height * staffTopFraction;

  double get staffBottomY => staffLineY(4);

  double get playheadX =>
      leftPadding +
      (size.width - leftPadding - rightPadding) * playheadFraction;

  double staffLineY(int lineIndex) => staffTopY + lineIndex * staffLineGap;

  double clampedPlayheadX({
    required double currentTimeMs,
    required NotationDisplayMode displayMode,
    required double pageStartMs,
    required double pageDurationMs,
  }) {
    if (displayMode == NotationDisplayMode.scrolling) {
      return playheadX;
    }
    return xForTime(
      eventTimeMs: currentTimeMs,
      currentTimeMs: currentTimeMs,
      pixelsPerSecond: 0,
      displayMode: displayMode,
      pageStartMs: pageStartMs,
      pageDurationMs: pageDurationMs,
    ).clamp(contentLeft, contentRight).toDouble();
  }

  double yForPlacement(NotationLanePlacement placement) {
    return staffTopY + placement.staffPosition * (staffLineGap / 2);
  }

  double xForTime({
    required double eventTimeMs,
    required double currentTimeMs,
    required double pixelsPerSecond,
    NotationDisplayMode displayMode = NotationDisplayMode.scrolling,
    double pageStartMs = 0,
    double pageDurationMs = 8000,
  }) {
    if (displayMode == NotationDisplayMode.page) {
      final duration = math.max(1.0, pageDurationMs);
      return contentLeft +
          ((eventTimeMs - pageStartMs) / duration) * contentWidth;
    }
    return playheadX + (eventTimeMs - currentTimeMs) * pixelsPerSecond / 1000.0;
  }

  Offset feedbackCenter({
    required NotationLanePlacement placement,
    required double eventTimeMs,
    required double currentTimeMs,
    required double pixelsPerSecond,
    required double deltaMs,
    required NotationDisplayMode displayMode,
    required double pageStartMs,
    required double pageDurationMs,
    double markerWindowMs = 120,
    double markerMaxOffset = 24,
  }) {
    final clamped = (deltaMs / markerWindowMs).clamp(-1.0, 1.0);
    return Offset(
      xForTime(
            eventTimeMs: eventTimeMs,
            currentTimeMs: currentTimeMs,
            pixelsPerSecond: pixelsPerSecond,
            displayMode: displayMode,
            pageStartMs: pageStartMs,
            pageDurationMs: pageDurationMs,
          ) +
          markerMaxOffset * clamped,
      yForPlacement(placement),
    );
  }
}

class NotationViewPainter extends CustomPainter {
  const NotationViewPainter({
    required this.notes,
    required this.feedback,
    required this.currentTimeMs,
    required this.pixelsPerSecond,
    required this.pastWindowMs,
    required this.lookaheadMs,
    required this.displayMode,
    required this.pageStartMs,
    required this.pageDurationMs,
    required this.measureMs,
    required this.placements,
    required this.colorScheme,
  });

  final List<NotationNote> notes;
  final List<NotationFeedback> feedback;
  final double currentTimeMs;
  final double pixelsPerSecond;
  final double pastWindowMs;
  final double lookaheadMs;
  final NotationDisplayMode displayMode;
  final double pageStartMs;
  final double pageDurationMs;
  final double measureMs;
  final Map<String, NotationLanePlacement> placements;
  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = NotationGeometry(size: size);
    _paintStaff(canvas, size, geometry);
    _paintMeasureGrid(canvas, geometry);
    _paintPlayhead(canvas, geometry);
    _paintNotes(canvas, geometry);
    _paintFeedback(canvas, geometry);
  }

  void _paintStaff(Canvas canvas, Size size, NotationGeometry geometry) {
    final staffPaint = Paint()
      ..color = colorScheme.outline
      ..strokeWidth = 1.4;
    for (var line = 0; line < 5; line += 1) {
      final y = geometry.staffLineY(line);
      canvas.drawLine(
        Offset(geometry.leftPadding, y),
        Offset(size.width - geometry.rightPadding, y),
        staffPaint,
      );
    }

    final labelPainter = TextPainter(
      text: TextSpan(
        text: 'Drums',
        style: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    labelPainter.paint(
      canvas,
      Offset(8, geometry.staffTopY + geometry.staffLineGap),
    );
  }

  void _paintPlayhead(Canvas canvas, NotationGeometry geometry) {
    final paint = Paint()
      ..color = colorScheme.secondary
      ..strokeWidth = 3;
    final x = geometry.clampedPlayheadX(
      currentTimeMs: currentTimeMs,
      displayMode: displayMode,
      pageStartMs: pageStartMs,
      pageDurationMs: pageDurationMs,
    );
    canvas.drawLine(
      Offset(x, geometry.staffTopY - 24),
      Offset(x, geometry.staffBottomY + 30),
      paint,
    );
  }

  void _paintMeasureGrid(Canvas canvas, NotationGeometry geometry) {
    if (measureMs <= 0) {
      return;
    }

    final visibleStart = displayMode == NotationDisplayMode.page
        ? pageStartMs
        : currentTimeMs - pastWindowMs;
    final visibleEnd = displayMode == NotationDisplayMode.page
        ? pageStartMs + pageDurationMs
        : currentTimeMs + lookaheadMs;
    final firstMeasure = (visibleStart / measureMs).floor();
    final lastMeasure = (visibleEnd / measureMs).ceil();
    final barPaint = Paint()
      ..color = colorScheme.outlineVariant
      ..strokeWidth = 1.2;

    for (var measure = firstMeasure; measure <= lastMeasure; measure += 1) {
      final tMs = measure * measureMs;
      final x = geometry.xForTime(
        eventTimeMs: tMs.toDouble(),
        currentTimeMs: currentTimeMs,
        pixelsPerSecond: pixelsPerSecond,
        displayMode: displayMode,
        pageStartMs: pageStartMs,
        pageDurationMs: pageDurationMs,
      );
      if (x < geometry.contentLeft || x > geometry.contentRight) {
        continue;
      }
      canvas.drawLine(
        Offset(x, geometry.staffTopY - 8),
        Offset(x, geometry.staffBottomY + 8),
        barPaint,
      );
    }
  }

  void _paintNotes(Canvas canvas, NotationGeometry geometry) {
    for (final note in notes) {
      if (!_isVisible(note.tMs)) {
        continue;
      }
      final placement = placements[note.laneId];
      if (placement == null) {
        continue;
      }
      final center = Offset(
        geometry.xForTime(
          eventTimeMs: note.tMs,
          currentTimeMs: currentTimeMs,
          pixelsPerSecond: pixelsPerSecond,
          displayMode: displayMode,
          pageStartMs: pageStartMs,
          pageDurationMs: pageDurationMs,
        ),
        geometry.yForPlacement(placement),
      );
      _paintNoteHead(canvas, center, placement, note.articulation);
      _paintStem(canvas, center, placement);
    }
  }

  void _paintFeedback(Canvas canvas, NotationGeometry geometry) {
    for (final marker in feedback) {
      final placement = placements[marker.laneId];
      if (placement == null) {
        continue;
      }
      if (!_isVisible(marker.tMs)) {
        continue;
      }
      final center = geometry.feedbackCenter(
        placement: placement,
        eventTimeMs: marker.tMs,
        currentTimeMs: currentTimeMs,
        pixelsPerSecond: pixelsPerSecond,
        deltaMs: marker.deltaMs,
        displayMode: displayMode,
        pageStartMs: pageStartMs,
        pageDurationMs: pageDurationMs,
      );
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = gradeColor(marker.grade, colorScheme);
      canvas.drawCircle(center, 12, paint);
    }
  }

  void _paintNoteHead(
    Canvas canvas,
    Offset center,
    NotationLanePlacement placement,
    String articulation,
  ) {
    final paint = Paint()
      ..color = colorScheme.onSurface
      ..strokeWidth = 2;
    if (placement.cross) {
      canvas.drawLine(center.translate(-7, -7), center.translate(7, 7), paint);
      canvas.drawLine(center.translate(7, -7), center.translate(-7, 7), paint);
      if (articulation == 'open') {
        canvas.drawCircle(center.translate(0, -15), 4, paint);
      }
      return;
    }
    canvas.drawOval(
      Rect.fromCenter(center: center, width: 16, height: 11),
      paint,
    );
  }

  void _paintStem(
    Canvas canvas,
    Offset center,
    NotationLanePlacement placement,
  ) {
    final stemPaint = Paint()
      ..color = colorScheme.onSurface
      ..strokeWidth = 1.5;
    final stemStart = placement.stemUp
        ? center.translate(7, 0)
        : center.translate(-7, 0);
    final stemEnd = placement.stemUp
        ? stemStart.translate(0, -42)
        : stemStart.translate(0, 42);
    canvas.drawLine(stemStart, stemEnd, stemPaint);
  }

  bool _isVisible(double tMs) {
    if (displayMode == NotationDisplayMode.page) {
      return tMs >= pageStartMs && tMs <= pageStartMs + pageDurationMs;
    }
    final relativeMs = tMs - currentTimeMs;
    return relativeMs >= -pastWindowMs && relativeMs <= lookaheadMs;
  }

  @override
  bool shouldRepaint(covariant NotationViewPainter oldDelegate) {
    return oldDelegate.notes != notes ||
        oldDelegate.feedback != feedback ||
        oldDelegate.currentTimeMs != currentTimeMs ||
        oldDelegate.pixelsPerSecond != pixelsPerSecond ||
        oldDelegate.pastWindowMs != pastWindowMs ||
        oldDelegate.lookaheadMs != lookaheadMs ||
        oldDelegate.displayMode != displayMode ||
        oldDelegate.pageStartMs != pageStartMs ||
        oldDelegate.pageDurationMs != pageDurationMs ||
        oldDelegate.measureMs != measureMs ||
        oldDelegate.placements != placements ||
        oldDelegate.colorScheme != colorScheme;
  }
}
