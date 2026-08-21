import 'package:flutter/material.dart';

/// SteriCord's design tokens (SteriCord_Mobile_UI_UX_Redesign_Prompt.md
/// sections 2-3). Kept as one flat const class, not a ThemeExtension: this
/// app has no dark mode yet (section 38 says not to prioritize it), so a
/// themeable extension would add indirection with nothing to switch between
/// -- every screen just reaches for `AppColors.pass` etc. directly.
///
/// Field names `navy`, `teal`, `scBlue`, `scBlueLight`, `pass`, `warning`,
/// `fail` are load-bearing across ~20 existing screens -- kept stable
/// deliberately so this redesign changes *values* (the actual visual
/// language) without becoming a rename-everywhere refactor of files this
/// pass doesn't otherwise touch.
class AppColors {
  AppColors._();

  // --- Brand ---------------------------------------------------------------
  static const navy = Color(0xFF0B1F33);
  static const navyLight = Color(0xFF132C52);
  static const teal = Color(0xFF14B8A6); // Clinical Teal -- primary accent/CTA
  static const tealDark = Color(0xFF0F766E); // pressed/hover state for teal
  static const scBlue = Color(0xFF2F80ED); // Medical Blue -- secondary accent
  static const medicalBlue = scBlue;
  static const scBlueLight = Color(0xFFEFF6FF);

  // --- Surfaces --------------------------------------------------------------
  static const appBackground = Color(0xFFF6F8FB);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE4E9F0);

  // --- Text ------------------------------------------------------------------
  static const textPrimary = Color(0xFF122033);
  static const textSecondary = Color(0xFF667085);
  static const textOnDark = Colors.white;
  static const textOnDarkMuted = Color(0xFFB8C4D9);

  // --- Status: PASS / SAFE -----------------------------------------------
  static const pass = Color(0xFF16A34A);
  static const passSoft = Color(0xFFECFDF3);

  // --- Status: WARNING ---------------------------------------------------
  static const warning = Color(0xFFD97706);
  static const warningSoft = Color(0xFFFFF7E6);

  // --- Status: FAIL / CRITICAL ---------------------------------------------
  static const fail = Color(0xFFDC2626);
  static const failSoft = Color(0xFFFEF2F2);

  // --- Status: INFORMATION -------------------------------------------------
  static const info = Color(0xFF2563EB);
  static const infoSoft = Color(0xFFEFF6FF);

  // --- Status: NEUTRAL / PENDING -------------------------------------------
  static const neutral = Color(0xFF64748B);
  static const neutralSoft = Color(0xFFF1F5F9);
}
