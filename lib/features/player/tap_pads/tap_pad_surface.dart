import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:taal/design/colors.dart';
import 'package:taal/design/tokens.dart';
import 'package:taal/features/player/drum_kit/drum_kit.dart';
import 'package:taal/features/player/note_highway/note_highway.dart';

class TapPadSurface extends StatefulWidget {
  const TapPadSurface({
    super.key,
    required this.onPadHit,
    this.pads = standardFivePieceDrumKitPads,
    this.enabledLaneIds,
    this.velocity = 96,
    this.guidanceText = 'Connect your kit for the best experience.',
    this.minTouchTarget = 64,
    this.recentHits = const [],
    this.onDismissGuidance,
  });

  final List<VisualDrumKitPad> pads;
  final Set<String>? enabledLaneIds;
  final int velocity;
  final String guidanceText;
  final double minTouchTarget;
  final ValueChanged<TapPadHit> onPadHit;

  /// Recent graded hits from the engine, used to flash pads with grade colors.
  final List<VisualDrumKitHit> recentHits;

  /// If provided, shows a dismiss button on the guidance banner.
  final VoidCallback? onDismissGuidance;

  @override
  State<TapPadSurface> createState() => _TapPadSurfaceState();
}

class _TapPadSurfaceState extends State<TapPadSurface> {
  final Map<String, Timer> _releaseTimers = {};
  final Set<String> _activeLaneIds = {};
  bool _guidanceDismissed = false;

  @override
  void dispose() {
    for (final timer in _releaseTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  VisualDrumKitHit? _gradeHitForLane(String laneId) {
    for (var i = widget.recentHits.length - 1; i >= 0; i--) {
      final hit = widget.recentHits[i];
      if (hit.laneId == laneId && hit.progress < 1.0) {
        return hit;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final showBanner = !_guidanceDismissed && widget.guidanceText.isNotEmpty;

    return Semantics(
      label: 'On-screen drum pads',
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(TaalTokens.radiusMedium),
          color: scheme.surface,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showBanner)
              _GuidanceBanner(
                text: widget.guidanceText,
                dismissible: widget.onDismissGuidance != null,
                onDismiss: () {
                  setState(() => _guidanceDismissed = true);
                  widget.onDismissGuidance?.call();
                },
              ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = Size(
                    constraints.maxWidth.isFinite
                        ? constraints.maxWidth
                        : 640.0,
                    constraints.maxHeight.isFinite
                        ? constraints.maxHeight
                        : 260.0,
                  );
                  final geometry = VisualDrumKitGeometry(size: size);
                  return Stack(
                    children: [
                      for (final pad in widget.pads)
                        if (_isEnabled(pad.laneId))
                          _AnimatedTapPad(
                            key: ValueKey('tap-pad-${pad.laneId}'),
                            pad: pad,
                            rect: _touchRectForPad(
                              geometry.padRect(pad),
                              geometry.kitBounds,
                            ),
                            active: _activeLaneIds.contains(pad.laneId),
                            gradeHit: _gradeHitForLane(pad.laneId),
                            onPressed: () => _handlePadHit(pad),
                          ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isEnabled(String laneId) {
    return widget.enabledLaneIds?.contains(laneId) ?? true;
  }

  Rect _touchRectForPad(Rect padRect, Rect bounds) {
    final width = math.max(widget.minTouchTarget, padRect.width);
    final height = math.max(widget.minTouchTarget, padRect.height);
    final left = (padRect.center.dx - width / 2).clamp(
      bounds.left,
      math.max(bounds.left, bounds.right - width),
    );
    final top = (padRect.center.dy - height / 2).clamp(
      bounds.top,
      math.max(bounds.top, bounds.bottom - height),
    );
    return Rect.fromLTWH(left.toDouble(), top.toDouble(), width, height);
  }

  void _handlePadHit(VisualDrumKitPad pad) {
    HapticFeedback.mediumImpact();
    widget.onPadHit(TapPadHit(laneId: pad.laneId, velocity: widget.velocity));
    _releaseTimers.remove(pad.laneId)?.cancel();
    setState(() {
      _activeLaneIds.add(pad.laneId);
    });
    _releaseTimers[pad.laneId] = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      setState(() {
        _activeLaneIds.remove(pad.laneId);
      });
    });
  }
}

class TapPadHit {
  const TapPadHit({required this.laneId, required this.velocity});

  final String laneId;
  final int velocity;
}

// ── Guidance Banner ──────────────────────────────────────────────────────

class _GuidanceBanner extends StatelessWidget {
  const _GuidanceBanner({
    required this.text,
    required this.dismissible,
    required this.onDismiss,
  });

  final String text;
  final bool dismissible;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TaalTokens.space12,
        TaalTokens.space8,
        TaalTokens.space12,
        TaalTokens.space4,
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: TaalTokens.space8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          if (dismissible)
            Semantics(
              button: true,
              label: 'Dismiss guidance banner',
              child: InkWell(
                borderRadius: BorderRadius.circular(TaalTokens.radiusFull),
                onTap: onDismiss,
                child: Padding(
                  padding: const EdgeInsets.all(TaalTokens.space4),
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Animated Tap Pad ─────────────────────────────────────────────────────

class _AnimatedTapPad extends StatefulWidget {
  const _AnimatedTapPad({
    super.key,
    required this.pad,
    required this.rect,
    required this.active,
    required this.onPressed,
    this.gradeHit,
  });

  final VisualDrumKitPad pad;
  final Rect rect;
  final bool active;
  final VisualDrumKitHit? gradeHit;
  final VoidCallback onPressed;

  @override
  State<_AnimatedTapPad> createState() => _AnimatedTapPadState();
}

class _AnimatedTapPadState extends State<_AnimatedTapPad>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hitController;

  @override
  void initState() {
    super.initState();
    _hitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void didUpdateWidget(covariant _AnimatedTapPad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _hitController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _hitController.dispose();
    super.dispose();
  }

  ShapeBorder _shapeForPad(
    VisualDrumKitPad pad,
    bool active,
    ColorScheme scheme,
  ) {
    final borderColor = active ? TaalColors.primary : scheme.outlineVariant;
    final borderWidth = active ? 2.5 : 1.2;
    final side = BorderSide(color: borderColor, width: borderWidth);

    switch (pad.kind) {
      case VisualDrumKitPadKind.kick:
        return CircleBorder(side: side);
      case VisualDrumKitPadKind.cymbal:
        return StadiumBorder(side: side);
      case VisualDrumKitPadKind.drum:
        return RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TaalTokens.radiusLarge),
          side: side,
        );
    }
  }

  Color _baseColorForPad(VisualDrumKitPad pad, ColorScheme scheme) {
    switch (pad.kind) {
      case VisualDrumKitPadKind.cymbal:
        return Color.alphaBlend(
          TaalColors.secondary.withValues(alpha: 0.10),
          scheme.surfaceContainerHighest,
        );
      case VisualDrumKitPadKind.kick:
        return scheme.surfaceContainerHighest;
      case VisualDrumKitPadKind.drum:
        return scheme.surfaceContainerHighest;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final baseColor = _baseColorForPad(widget.pad, scheme);
    final gradeHit = widget.gradeHit;

    // Determine the flash color: grade color if available, else primary.
    final flashColor = gradeHit != null
        ? gradeColor(gradeHit.grade, scheme)
        : TaalColors.primary;

    final fillColor = widget.active
        ? Color.alphaBlend(flashColor.withValues(alpha: 0.40), baseColor)
        : baseColor;

    final shape = _shapeForPad(widget.pad, widget.active, scheme);

    return Positioned.fromRect(
      rect: widget.rect,
      child: AnimatedBuilder(
        animation: _hitController,
        builder: (context, child) {
          final ringProgress = _hitController.value;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Expanding ring on hit.
              if (ringProgress > 0 && ringProgress < 1)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ExpandingRingPainter(
                      progress: ringProgress,
                      color: flashColor,
                      padKind: widget.pad.kind,
                    ),
                  ),
                ),
              child!,
            ],
          );
        },
        child: Semantics(
          button: true,
          label: widget.pad.label,
          child: Material(
            color: fillColor,
            shape: shape,
            child: InkWell(
              customBorder: shape,
              onTapDown: (_) => widget.onPressed(),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(TaalTokens.space4),
                  child: Text(
                    widget.pad.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Expanding Ring Painter ───────────────────────────────────────────────

class _ExpandingRingPainter extends CustomPainter {
  const _ExpandingRingPainter({
    required this.progress,
    required this.color,
    required this.padKind,
  });

  final double progress;
  final Color color;
  final VisualDrumKitPadKind padKind;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = math.min(size.width, size.height) / 2;
    final ringRadius = baseRadius + 14 * progress;
    final opacity = (1.0 - progress).clamp(0.0, 0.55);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0 * (1.0 - progress)
      ..color = color.withValues(alpha: opacity);

    if (padKind == VisualDrumKitPadKind.cymbal) {
      // Oval ring for cymbals.
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: size.width + 28 * progress,
          height: size.height + 14 * progress,
        ),
        paint,
      );
    } else {
      canvas.drawCircle(center, ringRadius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ExpandingRingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
