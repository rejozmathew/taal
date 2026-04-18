import 'package:flutter/material.dart';

/// Taal motion design tokens — shared animation constants and utilities.
///
/// All animation durations, curves, and reusable transition builders live here.
/// Feature code should reference these instead of ad-hoc Duration/Curve literals.
abstract final class TaalMotion {
  // ── Durations ──────────────────────────────────────────────────────────

  /// Micro-interaction (button press scale, icon swap): 100ms.
  static const Duration durationFast = Duration(milliseconds: 100);

  /// Standard feedback (card highlight, section crossfade): 200ms.
  static const Duration durationMedium = Duration(milliseconds: 200);

  /// Page/section transition: 300ms.
  static const Duration durationSlow = Duration(milliseconds: 300);

  /// Stagger delay between consecutive list items.
  static const Duration staggerInterval = Duration(milliseconds: 50);

  // ── Curves ─────────────────────────────────────────────────────────────

  /// Default ease for entrances and transitions.
  static const Curve curveStandard = Curves.easeOutCubic;

  /// Bounce-back for press feedback.
  static const Curve curvePress = Curves.easeInOut;

  /// Decelerate for fade-outs.
  static const Curve curveDecelerate = Curves.decelerate;

  // ── Button press scale ─────────────────────────────────────────────────

  /// Scale factor applied while a button is pressed (1.0 = no change).
  static const double pressScale = 0.96;

  // ── Card hover elevation boost ─────────────────────────────────────────

  /// Extra elevation added to a card on hover.
  static const double hoverElevationBoost = 2.0;
}

/// A crossfade + slide transition for switching shell sections.
///
/// Wraps [AnimatedSwitcher] with a combined fade + horizontal slide so that
/// navigating between Home, Practice, Library, etc. has a visible transition.
class SectionTransition extends StatelessWidget {
  const SectionTransition({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: TaalMotion.durationSlow,
      switchInCurve: TaalMotion.curveStandard,
      switchOutCurve: TaalMotion.curveDecelerate,
      transitionBuilder: (child, animation) {
        final slide = Tween<Offset>(
          begin: const Offset(0.03, 0),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: slide, child: child),
        );
      },
      child: child,
    );
  }
}

/// A wrapper that adds subtle scale feedback on press to any child widget.
///
/// On pointer-down the child scales to [TaalMotion.pressScale] and snaps back
/// on release.  Designed for buttons and interactive cards.
class PressableScale extends StatefulWidget {
  const PressableScale({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: TaalMotion.durationFast,
    );
    _scale = Tween<double>(begin: 1.0, end: TaalMotion.pressScale).animate(
      CurvedAnimation(parent: _controller, curve: TaalMotion.curvePress),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _controller.forward();
  void _onTapUp(TapUpDetails _) => _controller.reverse();
  void _onTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

/// A card wrapper that responds to hover (desktop) and press (mobile).
///
/// On hover the card's elevation increases and a subtle border highlight
/// appears.  On press it scales down slightly.
class InteractiveCard extends StatefulWidget {
  const InteractiveCard({
    super.key,
    required this.child,
    this.onTap,
    this.elevation,
    this.borderRadius,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double? elevation;
  final BorderRadius? borderRadius;

  @override
  State<InteractiveCard> createState() => _InteractiveCardState();
}

class _InteractiveCardState extends State<InteractiveCard>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  late final AnimationController _pressController;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: TaalMotion.durationFast,
    );
    _scale = Tween<double>(begin: 1.0, end: TaalMotion.pressScale).animate(
      CurvedAnimation(parent: _pressController, curve: TaalMotion.curvePress),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final baseElevation = widget.elevation ?? 1.0;
    final effectiveElevation = _hovered
        ? baseElevation + TaalMotion.hoverElevationBoost
        : baseElevation;
    final radius = widget.borderRadius ?? BorderRadius.circular(8.0);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => _pressController.forward(),
        onTapUp: (_) => _pressController.reverse(),
        onTapCancel: () => _pressController.reverse(),
        onTap: widget.onTap,
        child: ScaleTransition(
          scale: _scale,
          child: AnimatedContainer(
            duration: TaalMotion.durationMedium,
            curve: TaalMotion.curveStandard,
            child: Material(
              elevation: effectiveElevation,
              borderRadius: radius,
              color: scheme.surface,
              child: AnimatedContainer(
                duration: TaalMotion.durationMedium,
                curve: TaalMotion.curveStandard,
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(
                    color: _hovered
                        ? scheme.primary.withAlpha(100)
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Staggered fade-in for list/grid children.
///
/// Wrap a [Column] or [ListView] item with this, passing its index, to get a
/// cascading entrance animation when the list first appears.
class StaggeredFadeIn extends StatefulWidget {
  const StaggeredFadeIn({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<StaggeredFadeIn> createState() => _StaggeredFadeInState();
}

class _StaggeredFadeInState extends State<StaggeredFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: TaalMotion.durationSlow,
    );
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: TaalMotion.curveStandard,
    );
    _slide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _controller, curve: TaalMotion.curveStandard),
        );

    // Stagger: delay proportional to index.
    final delay = TaalMotion.staggerInterval * widget.index;
    Future.delayed(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
