import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:taal/features/player/drum_kit/drum_kit.dart';

class TapPadSurface extends StatefulWidget {
  const TapPadSurface({
    super.key,
    required this.onPadHit,
    this.pads = standardFivePieceDrumKitPads,
    this.enabledLaneIds,
    this.velocity = 96,
    this.guidanceText = 'Connect your kit for the best experience.',
    this.minTouchTarget = 64,
  });

  final List<VisualDrumKitPad> pads;
  final Set<String>? enabledLaneIds;
  final int velocity;
  final String guidanceText;
  final double minTouchTarget;
  final ValueChanged<TapPadHit> onPadHit;

  @override
  State<TapPadSurface> createState() => _TapPadSurfaceState();
}

class _TapPadSurfaceState extends State<TapPadSurface> {
  final Map<String, Timer> _releaseTimers = {};
  final Set<String> _activeLaneIds = {};

  @override
  void dispose() {
    for (final timer in _releaseTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      label: 'On-screen drum pads',
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
          color: scheme.surface,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Text(
                widget.guidanceText,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
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
                          _TapPadButton(
                            key: ValueKey('tap-pad-${pad.laneId}'),
                            pad: pad,
                            rect: _touchRectForPad(
                              geometry.padRect(pad),
                              geometry.kitBounds,
                            ),
                            active: _activeLaneIds.contains(pad.laneId),
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
    widget.onPadHit(TapPadHit(laneId: pad.laneId, velocity: widget.velocity));
    _releaseTimers.remove(pad.laneId)?.cancel();
    setState(() {
      _activeLaneIds.add(pad.laneId);
    });
    _releaseTimers[pad.laneId] = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) {
        return;
      }
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

class _TapPadButton extends StatelessWidget {
  const _TapPadButton({
    super.key,
    required this.pad,
    required this.rect,
    required this.active,
    required this.onPressed,
  });

  final VisualDrumKitPad pad;
  final Rect rect;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final baseColor = pad.kind == VisualDrumKitPadKind.cymbal
        ? scheme.tertiaryContainer
        : scheme.surfaceContainerHighest;
    final activeColor = Color.alphaBlend(
      scheme.primary.withValues(alpha: active ? 0.46 : 0.18),
      baseColor,
    );

    return Positioned.fromRect(
      rect: rect,
      child: Semantics(
        button: true,
        label: pad.label,
        child: Material(
          color: active ? activeColor : baseColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: active ? scheme.primary : scheme.outlineVariant,
              width: active ? 2.5 : 1.2,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTapDown: (_) => onPressed(),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Text(
                  pad.label,
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
    );
  }
}
