import 'package:flutter/material.dart';

class PayFlexColors {
  // Backgrounds & Surface Hierarchy
  static const Color background = Color(
    0xFFF8F9FA,
  ); // Clean off-white background
  static const Color surface = Color(
    0xFFFFFFFF,
  ); // Pure white cards & containers
  static const Color cardBg = Color(0xFFFFFFFF); // Elevates wallet cards

  // Brand & Accent Colors
  static const Color primary = Color(
    0xFF00C853,
  ); // Vibrant, energetic fintech green
  static const Color primaryLight = Color(
    0xFFE8F5E9,
  ); // Subtle green tint for chips/highlights
  static const Color primaryDark = Color(
    0xFF009624,
  ); // Darker green for pressed states

  // Typography Colors
  static const Color textPrimary = Color(
    0xFF0F172A,
  ); // Deep slate/navy for maximum contrast
  static const Color textSecondary = Color(
    0xFF64748B,
  ); // Cool grey for subtitles & labels
  static const Color textMuted = Color(
    0xFF94A3B8,
  ); // Muted grey for hints & timestamps

  // UI Component Extras
  static const Color iconBg = Color(
    0xFFF1F5F9,
  ); // Soft grey for icon backgrounds
  static const Color border = Color(0xFFE2E8F0); // Subtle border line color
  static const Color divider = Color(0xFFF1F5F9); // Light divider color
  static const Color error = Color(0xFFEF4444); // Bright red for debits/alerts
}
