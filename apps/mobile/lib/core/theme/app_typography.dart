import 'package:flutter/material.dart';
import 'package:stericord_mobile/core/theme/app_colors.dart';

/// Type scale (redesign prompt section 8). Uses the platform system font
/// (SF Pro on iOS, Roboto on Android) rather than pulling in `google_fonts`
/// for Inter -- that package fetches font files over the network at first
/// use by default, which cuts directly against this app's offline-first
/// design (Phase 8's encrypted sync queue exists specifically for
/// unreliable-connectivity OT/CSSD use). The system fonts are already
/// clean, modern sans-serifs; tuned weight/spacing here gets the same
/// crisp feel without a runtime dependency on connectivity.
class AppTypography {
  AppTypography._();

  static const _base = TextStyle(color: AppColors.textPrimary, height: 1.3);

  static final heroHeader = _base.copyWith(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -0.4);
  static final sectionHeader = _base.copyWith(fontSize: 21, fontWeight: FontWeight.w700, letterSpacing: -0.2);
  static final cardTitle = _base.copyWith(fontSize: 17, fontWeight: FontWeight.w600);
  static final body = _base.copyWith(fontSize: 15, fontWeight: FontWeight.w400, height: 1.4);
  static final bodyStrong = _base.copyWith(fontSize: 15, fontWeight: FontWeight.w600, height: 1.4);
  static final metadata = _base.copyWith(fontSize: 12.5, fontWeight: FontWeight.w500, color: AppColors.textSecondary);

  static final metricValue = _base.copyWith(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -0.5);
  static final metricLabel =
      _base.copyWith(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary);

  static TextTheme textTheme() {
    return TextTheme(
      headlineMedium: heroHeader,
      titleLarge: sectionHeader,
      titleMedium: cardTitle,
      bodyLarge: body,
      bodyMedium: body,
      labelLarge: bodyStrong,
      labelMedium: metadata,
    );
  }
}
