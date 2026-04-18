import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:taal/design/colors.dart';
import 'package:taal/features/player/note_highway/note_highway.dart';

class VisualDrumKitWidget extends StatelessWidget {
  const VisualDrumKitWidget({
    super.key,
    this.pads = standardFivePieceDrumKitPads,
    this.hits = const [],
  });

  final List<VisualDrumKitPad> pads;
  final List<VisualDrumKitHit> hits;

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
          painter: VisualDrumKitPainter(
            pads: pads,
            hits: hits,
            colorScheme: Theme.of(context).colorScheme,
          ),
        );
      },
    );
  }
}

class VisualDrumKitPad {
  const VisualDrumKitPad({
    required this.laneId,
    required this.slotId,
    required this.label,
    required this.center,
    required this.size,
    this.kind = VisualDrumKitPadKind.drum,
    this.rotationRadians = 0,
  });

  final String laneId;
  final String slotId;
  final String label;
  final Offset center;
  final Size size;
  final VisualDrumKitPadKind kind;
  final double rotationRadians;
}

enum VisualDrumKitPadKind { drum, cymbal, kick }

class VisualDrumKitHit {
  const VisualDrumKitHit({
    required this.laneId,
    required this.grade,
    this.progress = 0,
  });

  final String laneId;
  final NoteHighwayGrade grade;

  /// 0.0 means the flash has just arrived; 1.0 means it has faded out.
  final double progress;
}

const standardFivePieceDrumKitPads = <VisualDrumKitPad>[
  VisualDrumKitPad(
    laneId: 'crash',
    slotId: 'crash',
    label: 'Crash',
    center: Offset(0.25, 0.24),
    size: Size(0.28, 0.12),
    kind: VisualDrumKitPadKind.cymbal,
    rotationRadians: -0.18,
  ),
  VisualDrumKitPad(
    laneId: 'ride',
    slotId: 'ride',
    label: 'Ride',
    center: Offset(0.76, 0.29),
    size: Size(0.30, 0.13),
    kind: VisualDrumKitPadKind.cymbal,
    rotationRadians: 0.14,
  ),
  VisualDrumKitPad(
    laneId: 'hihat',
    slotId: 'hihat',
    label: 'Hi-Hat',
    center: Offset(0.17, 0.48),
    size: Size(0.25, 0.11),
    kind: VisualDrumKitPadKind.cymbal,
    rotationRadians: -0.08,
  ),
  VisualDrumKitPad(
    laneId: 'tom_high',
    slotId: 'tom_high',
    label: 'High Tom',
    center: Offset(0.43, 0.38),
    size: Size(0.20, 0.15),
  ),
  VisualDrumKitPad(
    laneId: 'tom_low',
    slotId: 'tom_low',
    label: 'Low Tom',
    center: Offset(0.58, 0.40),
    size: Size(0.21, 0.16),
  ),
  VisualDrumKitPad(
    laneId: 'snare',
    slotId: 'snare',
    label: 'Snare',
    center: Offset(0.37, 0.60),
    size: Size(0.22, 0.16),
  ),
  VisualDrumKitPad(
    laneId: 'tom_floor',
    slotId: 'tom_floor',
    label: 'Floor Tom',
    center: Offset(0.72, 0.62),
    size: Size(0.25, 0.19),
  ),
  VisualDrumKitPad(
    laneId: 'kick',
    slotId: 'kick',
    label: 'Kick',
    center: Offset(0.50, 0.74),
    size: Size(0.25, 0.27),
    kind: VisualDrumKitPadKind.kick,
  ),
];

class VisualDrumKitGeometry {
  const VisualDrumKitGeometry({
    required this.size,
    this.horizontalPadding = 28,
    this.verticalPadding = 20,
  });

  final Size size;
  final double horizontalPadding;
  final double verticalPadding;

  Rect get kitBounds {
    final width = math.max(1.0, size.width - horizontalPadding * 2);
    final height = math.max(1.0, size.height - verticalPadding * 2);
    return Rect.fromLTWH(horizontalPadding, verticalPadding, width, height);
  }

  Rect padRect(VisualDrumKitPad pad) {
    final bounds = kitBounds;
    final width = math.max(24.0, bounds.width * pad.size.width);
    final height = math.max(18.0, bounds.height * pad.size.height);
    return Rect.fromCenter(
      center: Offset(
        bounds.left + bounds.width * pad.center.dx,
        bounds.top + bounds.height * pad.center.dy,
      ),
      width: width,
      height: height,
    );
  }

  VisualDrumKitPad? padForLane(String laneId, List<VisualDrumKitPad> pads) {
    for (final pad in pads) {
      if (pad.laneId == laneId) {
        return pad;
      }
    }
    return null;
  }
}

class VisualDrumKitPainter extends CustomPainter {
  const VisualDrumKitPainter({
    required this.pads,
    required this.hits,
    required this.colorScheme,
  });

  final List<VisualDrumKitPad> pads;
  final List<VisualDrumKitHit> hits;
  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = VisualDrumKitGeometry(size: size);
    _paintKitShadow(canvas, geometry);

    for (final pad in pads) {
      final rect = geometry.padRect(pad);
      final hit = activeHitForLane(pad.laneId);
      _paintPad(canvas, rect, pad, hit);
      _paintLabel(canvas, rect, pad);
    }
  }

  VisualDrumKitHit? activeHitForLane(String laneId) {
    if (!pads.any((pad) => pad.laneId == laneId)) {
      return null;
    }
    for (var index = hits.length - 1; index >= 0; index -= 1) {
      final hit = hits[index];
      if (hit.laneId == laneId) {
        return hit;
      }
    }
    return null;
  }

  void _paintKitShadow(Canvas canvas, VisualDrumKitGeometry geometry) {
    final bounds = geometry.kitBounds;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(bounds.center.dx, bounds.bottom - bounds.height * 0.10),
        width: bounds.width * 0.72,
        height: bounds.height * 0.16,
      ),
      Paint()..color = colorScheme.shadow.withValues(alpha: 0.12),
    );
  }

  void _paintPad(
    Canvas canvas,
    Rect rect,
    VisualDrumKitPad pad,
    VisualDrumKitHit? hit,
  ) {
    final progress = (hit?.progress ?? 1).clamp(0.0, 1.0);
    final flash = 1 - progress;
    final flashColor = hit == null
        ? null
        : gradeColor(hit.grade, colorScheme).withValues(alpha: flash);

    canvas.save();
    canvas.translate(rect.center.dx, rect.center.dy);
    canvas.rotate(pad.rotationRadians);
    final localRect = Rect.fromCenter(
      center: Offset.zero,
      width: rect.width,
      height: rect.height,
    );

    // Expanding ring hit flash effect.
    if (flashColor != null && flash > 0) {
      final ringRadius = localRect.shortestSide / 2 + 12 * flash + 8;
      canvas.drawCircle(
        Offset.zero,
        ringRadius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0 * flash
          ..color = flashColor.withValues(alpha: 0.55 * flash),
      );
    }

    switch (pad.kind) {
      case VisualDrumKitPadKind.cymbal:
        _paintCymbal(canvas, localRect, pad, flashColor, flash);
      case VisualDrumKitPadKind.kick:
        _paintKick(canvas, localRect, flashColor, flash);
      case VisualDrumKitPadKind.drum:
        _paintDrum(canvas, localRect, flashColor, flash);
    }

    canvas.restore();
  }

  void _paintCymbal(
    Canvas canvas,
    Rect rect,
    VisualDrumKitPad pad,
    Color? flashColor,
    double flash,
  ) {
    // Cymbal body — wider ellipse with distinct metallic coloring.
    final baseColor = TaalColors.secondary.withValues(alpha: 0.25);
    final fill = flashColor == null
        ? baseColor
        : Color.alphaBlend(flashColor.withValues(alpha: 0.45), baseColor);
    final outlineColor = flashColor == null
        ? TaalColors.secondary.withValues(alpha: 0.50)
        : Color.alphaBlend(
            flashColor.withValues(alpha: 0.70),
            TaalColors.secondary.withValues(alpha: 0.50),
          );

    // Edge ring — thin outer stroke.
    canvas.drawOval(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = outlineColor,
    );
    canvas.drawOval(rect, Paint()..color = fill);

    // Inner grooves for realism.
    canvas.drawOval(
      rect.deflate(rect.shortestSide * 0.18),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..color = outlineColor.withValues(alpha: 0.35),
    );

    // Bell dot at center.
    final bellRadius = rect.shortestSide * 0.12;
    canvas.drawCircle(
      Offset.zero,
      bellRadius,
      Paint()..color = TaalColors.secondary.withValues(alpha: 0.45),
    );
    canvas.drawCircle(
      Offset.zero,
      bellRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = outlineColor.withValues(alpha: 0.60),
    );

    // Hi-hat pedal indicator.
    if (pad.laneId == 'hihat') {
      final pedalTop = Offset(0, rect.bottom + 2);
      final pedalBottom = Offset(0, rect.bottom + rect.height * 0.6);
      canvas.drawLine(
        pedalTop,
        pedalBottom,
        Paint()
          ..strokeWidth = 2.5
          ..color = colorScheme.outlineVariant,
      );
      // Pedal base.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: pedalBottom,
            width: rect.width * 0.25,
            height: rect.height * 0.22,
          ),
          const Radius.circular(2),
        ),
        Paint()..color = colorScheme.outlineVariant.withValues(alpha: 0.6),
      );
    }
  }

  void _paintKick(
    Canvas canvas,
    Rect rect,
    Color? flashColor,
    double flash,
  ) {
    // Kick drum — large circle with concentric rings for the drum head.
    final baseColor = colorScheme.surfaceContainerHighest;
    final fill = flashColor == null
        ? baseColor
        : Color.alphaBlend(flashColor.withValues(alpha: 0.42), baseColor);
    final outline = flashColor == null
        ? colorScheme.outlineVariant
        : Color.alphaBlend(
            flashColor.withValues(alpha: 0.75),
            colorScheme.outline,
          );

    // Use a circle (inscribed in the rect).
    final radius = rect.shortestSide / 2;
    canvas.drawCircle(Offset.zero, radius, Paint()..color = fill);
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = outline,
    );

    // Shell ring.
    canvas.drawCircle(
      Offset.zero,
      radius * 0.82,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = outline.withValues(alpha: 0.40),
    );

    // Beater patch (center).
    canvas.drawCircle(
      Offset.zero,
      radius * 0.22,
      Paint()..color = outline.withValues(alpha: 0.25),
    );
  }

  void _paintDrum(
    Canvas canvas,
    Rect rect,
    Color? flashColor,
    double flash,
  ) {
    // Drum (snare / toms) — oval with rim highlight and head tension lines.
    final baseColor = colorScheme.surfaceContainerHighest;
    final fill = flashColor == null
        ? baseColor
        : Color.alphaBlend(flashColor.withValues(alpha: 0.42), baseColor);
    final outline = flashColor == null
        ? colorScheme.outlineVariant
        : Color.alphaBlend(
            flashColor.withValues(alpha: 0.75),
            colorScheme.outline,
          );

    // Drum body.
    canvas.drawOval(rect, Paint()..color = fill);
    canvas.drawOval(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = outline,
    );

    // Drum rim — inner ring for the head edge.
    canvas.drawOval(
      rect.deflate(rect.shortestSide * 0.12),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..color = outline.withValues(alpha: 0.35),
    );

    // Subtle cross-hair tension lines on the head.
    final cx = rect.center.dx;
    final cy = rect.center.dy;
    final halfW = rect.width * 0.28;
    final halfH = rect.height * 0.28;
    final lineColor = outline.withValues(alpha: 0.15);
    final linePaint = Paint()
      ..strokeWidth = 0.6
      ..color = lineColor;
    canvas.drawLine(Offset(cx - halfW, cy), Offset(cx + halfW, cy), linePaint);
    canvas.drawLine(Offset(cx, cy - halfH), Offset(cx, cy + halfH), linePaint);
  }

  void _paintLabel(Canvas canvas, Rect rect, VisualDrumKitPad pad) {
    final painter = TextPainter(
      text: TextSpan(
        text: pad.label,
        style: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '',
    )..layout(maxWidth: rect.width + 24);

    painter.paint(
      canvas,
      Offset(rect.center.dx - painter.width / 2, rect.bottom + 4),
    );
  }

  @override
  bool shouldRepaint(covariant VisualDrumKitPainter oldDelegate) {
    return oldDelegate.pads != pads ||
        oldDelegate.hits != hits ||
        oldDelegate.colorScheme != colorScheme;
  }
}
