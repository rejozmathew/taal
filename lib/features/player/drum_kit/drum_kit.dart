import 'dart:math' as math;

import 'package:flutter/material.dart';
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
        center: Offset(bounds.center.dx, bounds.bottom - bounds.height * 0.14),
        width: bounds.width * 0.68,
        height: bounds.height * 0.18,
      ),
      Paint()..color = colorScheme.shadow.withValues(alpha: 0.18),
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

    if (flashColor != null) {
      canvas.drawOval(
        localRect.inflate(10 + 10 * flash),
        Paint()..color = flashColor.withValues(alpha: 0.22 * flash),
      );
    }

    final baseColor = pad.kind == VisualDrumKitPadKind.cymbal
        ? colorScheme.tertiaryContainer
        : colorScheme.surfaceContainerHighest;
    final fill = flashColor == null
        ? baseColor
        : Color.alphaBlend(flashColor.withValues(alpha: 0.42), baseColor);
    final outline = flashColor == null
        ? colorScheme.outlineVariant
        : Color.alphaBlend(
            flashColor.withValues(alpha: 0.75),
            colorScheme.outline,
          );

    canvas.drawOval(localRect, Paint()..color = fill);
    canvas.drawOval(
      localRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = hit == null ? 1.4 : 3
        ..color = outline,
    );

    if (pad.kind == VisualDrumKitPadKind.kick) {
      canvas.drawOval(
        localRect.deflate(8),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = colorScheme.outlineVariant,
      );
    }

    canvas.restore();
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
