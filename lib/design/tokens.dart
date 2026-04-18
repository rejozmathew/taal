/// Taal design tokens: spacing, radii, and elevation.
///
/// All spatial and elevation values used by the app are defined here.
abstract final class TaalTokens {
  // ── Spacing scale (4-base) ─────────────────────────────────────────────

  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;
  static const double space48 = 48.0;

  // ── Border radii ───────────────────────────────────────────────────────

  static const double radiusSmall = 4.0;
  static const double radiusMedium = 8.0;
  static const double radiusLarge = 12.0;
  static const double radiusXLarge = 16.0;
  static const double radiusFull = 999.0;

  // ── Elevation levels ───────────────────────────────────────────────────

  static const double elevationNone = 0.0;
  static const double elevationLow = 1.0;
  static const double elevationMedium = 2.0;
  static const double elevationHigh = 4.0;
  static const double elevationOverlay = 8.0;

  // ── Minimum touch target (Material guideline) ─────────────────────────

  static const double minTouchTarget = 48.0;
}
