import 'package:flutter/material.dart';

/// Corner radius scale (redesign prompt section 6: "modern but restrained
/// rounding"). Deliberately no pill-shaped (999px) radius here -- section 44
/// explicitly calls out "oversized rounded pills" as a thing to avoid.
class AppRadius {
  AppRadius._();

  static const small = 8.0; // small controls
  static const input = 11.0; // text fields, dropdowns
  static const card = 15.0; // cards
  static const panel = 19.0; // large panels
  static const sheet = 24.0; // bottom sheets

  static const smallRadius = BorderRadius.all(Radius.circular(small));
  static const inputRadius = BorderRadius.all(Radius.circular(input));
  static const cardRadius = BorderRadius.all(Radius.circular(card));
  static const panelRadius = BorderRadius.all(Radius.circular(panel));
  static const sheetRadius = BorderRadius.vertical(top: Radius.circular(sheet));
}
