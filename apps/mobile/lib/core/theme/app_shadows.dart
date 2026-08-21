import 'package:flutter/material.dart';

/// Subtle elevation (redesign prompt section 7: "very low opacity, soft
/// blur, minimal vertical displacement... use borders more often than
/// heavy shadows"). Cards should still pair this with an AppColors.border
/// outline rather than relying on shadow alone to read as a surface.
class AppShadows {
  AppShadows._();

  static const card = [
    BoxShadow(
      color: Color(0x0A0B1F33),
      blurRadius: 12,
      offset: Offset(0, 2),
    ),
  ];

  static const elevated = [
    BoxShadow(
      color: Color(0x140B1F33),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];
}
