/// 8-point spacing scale (redesign prompt section 5). Use these instead of
/// ad-hoc `SizedBox(height: 14)` / `EdgeInsets.all(18)` values so every
/// screen's rhythm actually matches instead of merely looking similar.
class AppSpacing {
  AppSpacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;
  static const huge = 40.0;
  static const massive = 48.0;

  /// Standard screen edge padding (section 5: "Screen horizontal padding: 20px").
  static const screenPadding = 20.0;

  /// Standard card interior padding (section 5: "Card padding: 16-20px").
  static const cardPadding = 18.0;

  /// Gap between major sections on a screen (section 5: "Section gap: 24-32px").
  static const sectionGap = 28.0;

  /// Gap between small related elements (section 5: "Element gap: 8-12px").
  static const elementGap = 10.0;
}
