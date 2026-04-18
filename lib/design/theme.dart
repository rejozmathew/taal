import 'package:flutter/material.dart';

import 'colors.dart';
import 'motion.dart';
import 'tokens.dart';
import 'typography.dart';

/// Taal theme builder.
///
/// Provides two complete [ThemeData] objects (dark and light) built entirely
/// from design tokens. Neither uses `ColorScheme.fromSeed()`.
abstract final class TaalTheme {
  static const double _radius = TaalTokens.radiusMedium;

  // ── Dark Theme ─────────────────────────────────────────────────────────

  static final ThemeData dark = _build(
    brightness: Brightness.dark,
    background: TaalColors.darkBackground,
    surface: TaalColors.darkSurface,
    surfaceVariant: TaalColors.darkSurfaceVariant,
    onBackground: TaalColors.darkOnBackground,
    onSurface: TaalColors.darkOnSurface,
    onSurfaceVariant: TaalColors.darkOnSurfaceVariant,
    outline: TaalColors.darkOutline,
  );

  // ── Light Theme ────────────────────────────────────────────────────────

  static final ThemeData light = _build(
    brightness: Brightness.light,
    background: TaalColors.lightBackground,
    surface: TaalColors.lightSurface,
    surfaceVariant: TaalColors.lightSurfaceVariant,
    onBackground: TaalColors.lightOnBackground,
    onSurface: TaalColors.lightOnSurface,
    onSurfaceVariant: TaalColors.lightOnSurfaceVariant,
    outline: TaalColors.lightOutline,
  );

  // ── Builder ────────────────────────────────────────────────────────────

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color surfaceVariant,
    required Color onBackground,
    required Color onSurface,
    required Color onSurfaceVariant,
    required Color outline,
  }) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: TaalColors.primary,
      onPrimary: TaalColors.onPrimary,
      secondary: TaalColors.secondary,
      onSecondary: TaalColors.onSecondary,
      tertiary: TaalColors.tertiary,
      onTertiary: TaalColors.onPrimary,
      error: TaalColors.error,
      onError: TaalColors.onError,
      surface: surface,
      onSurface: onSurface,
      surfaceContainerHighest: surfaceVariant,
      onSurfaceVariant: onSurfaceVariant,
      outline: outline,
    );

    final textTheme = TaalTypography.textTheme.apply(
      bodyColor: onSurface,
      displayColor: onSurface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: background,
      cardTheme: const CardThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(_radius)),
        ),
      ),
      chipTheme: const ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(_radius)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(_radius)),
          ),
          animationDuration: TaalMotion.durationFast,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(_radius)),
          ),
          animationDuration: TaalMotion.durationFast,
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(_radius)),
        ),
      ),
      dividerTheme: DividerThemeData(color: outline),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.windows: _TaalPageTransitionsBuilder(),
          TargetPlatform.android: _TaalPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: _TaalPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(_radius)),
        ),
      ),
    );
  }
}

/// Slide + fade page transition for Navigator-pushed routes (non-iOS).
class _TaalPageTransitionsBuilder extends PageTransitionsBuilder {
  const _TaalPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final slide = Tween<Offset>(
      begin: const Offset(0.05, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: TaalMotion.curveStandard,
    ));
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: TaalMotion.curveStandard,
      ),
      child: SlideTransition(position: slide, child: child),
    );
  }
}
