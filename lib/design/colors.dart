import 'package:flutter/material.dart';

/// Taal semantic color tokens.
///
/// All colors used by the app are defined here. Feature code must reference
/// these tokens instead of raw `Color(0xFF...)` literals.
///
/// Token naming follows the visual-language spec (docs/specs/visual-language.md).
abstract final class TaalColors {
  // ── Brand ──────────────────────────────────────────────────────────────

  /// Primary brand teal — buttons, active states, accents.
  static const Color primary = Color(0xFF16A085);

  /// Secondary warm gold accent — highlights, badges.
  static const Color secondary = Color(0xFFE0B44C);

  /// Tertiary cool blue — informational, links.
  static const Color tertiary = Color(0xFF5DADE2);

  // ── Grade feedback (frozen — matches engine-api.md Grade enum) ─────────

  /// Perfect timing — teal-green.
  static const Color gradePerfect = Color(0xFF20C997);

  /// Good timing — lighter green.
  static const Color gradeGood = Color(0xFF8CE99A);

  /// Early hit — blue.
  static const Color gradeEarly = Color(0xFF4DABF7);

  /// Late hit — amber.
  static const Color gradeLate = Color(0xFFFFC857);

  /// Missed note — muted gray.
  static const Color gradeMiss = Color(0xFF6C757D);

  // ── Combo / encouragement ──────────────────────────────────────────────

  /// Active combo streak accent.
  static const Color comboActive = secondary;

  // ── Lane palette (cycled for note highway / practice runtime lanes) ────

  static const Color lanePurple = Color(0xFFD78AD7);
  static const Color laneGray = Color(0xFF95A5A6);
  static const Color laneGreen = Color(0xFF2ECC71);
  static const Color laneYellow = Color(0xFFF4D03F);
  static const Color laneLightTeal = Color(0xFF76D7C4);

  static const List<Color> lanePalette = [
    primary,      // teal
    secondary,    // gold
    tertiary,     // blue
    lanePurple,   // purple
    laneGray,     // gray
    laneGreen,    // green
    laneYellow,   // yellow
    laneLightTeal, // light teal
  ];

  // ── Layout compatibility ───────────────────────────────────────────────

  /// Full-compatibility indicator green.
  static const Color compatFull = gradePerfect;

  /// Optional-missing indicator amber.
  static const Color compatOptionalMissing = gradeLate;

  // ── Dark theme surfaces ────────────────────────────────────────────────

  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkSurfaceVariant = Color(0xFF2A2A2A);
  static const Color darkOnBackground = Color(0xFFE0E0E0);
  static const Color darkOnSurface = Color(0xFFE0E0E0);
  static const Color darkOnSurfaceVariant = Color(0xFFA0A0A0);
  static const Color darkOutline = Color(0xFF444444);

  // ── Light theme surfaces ───────────────────────────────────────────────

  static const Color lightBackground = Color(0xFFF5F5F5);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFEEEEEE);
  static const Color lightOnBackground = Color(0xFF1A1A1A);
  static const Color lightOnSurface = Color(0xFF1A1A1A);
  static const Color lightOnSurfaceVariant = Color(0xFF666666);
  static const Color lightOutline = Color(0xFFCCCCCC);

  // ── Shared semantic ────────────────────────────────────────────────────

  static const Color error = Color(0xFFCF6679);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onSecondary = Color(0xFF1A1A1A);
  static const Color onError = Color(0xFF1A1A1A);
}
