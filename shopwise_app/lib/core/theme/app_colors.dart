import 'package:flutter/material.dart';

/// ShopWise brand color palette.
///
/// Primary  — Deep Teal  #176369  (buttons, nav active, hero cards)
/// Accent   — Logo Orange #EA7D1C  (highlights, FAB, counts)
/// Background — Soft Off-white #F8F9FA
/// Surface  — Pure White #FFFFFF
/// Text primary #202B2C  |  Text secondary #687476
/// Border   #E5E9EA
/// Alert/Critical #D64545  |  Warning #D99A24  |  Success #2E8B68
class AppColors {
  AppColors._();

  // ── Core brand ────────────────────────────────────────────────────────────
  static const Color primary      = Color(0xFF176369); // Deep Teal
  static const Color primaryLight = Color(0xFF2A8A91);
  static const Color primaryDark  = Color(0xFF0E4347);

  static const Color accent      = Color(0xFFEA7D1C); // Logo Orange
  static const Color accentLight = Color(0xFFFF9D46);
  static const Color accentDark  = Color(0xFFC06012);

  // ── Backgrounds & surfaces ────────────────────────────────────────────────
  static const Color background     = Color(0xFFF8F9FA); // Soft off-white
  static const Color surface        = Color(0xFFFFFFFF); // Pure white
  static const Color surfaceVariant = Color(0xFFF1F4F4); // Subtle tint

  // ── Text ──────────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFF202B2C);
  static const Color textSecondary = Color(0xFF687476);
  static const Color textDisabled  = Color(0xFFADB8BA);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnAccent  = Color(0xFFFFFFFF);

  // ── Borders & dividers ────────────────────────────────────────────────────
  static const Color border  = Color(0xFFE5E9EA);
  static const Color divider = Color(0xFFE5E9EA);

  // ── Status ────────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF2E8B68); // Teal-green
  static const Color error   = Color(0xFFD64545); // Alert red
  static const Color warning = Color(0xFFD99A24); // Amber
  static const Color info    = Color(0xFF176369); // Same as primary

  // ── Risk levels (Smart Assistant) ─────────────────────────────────────────
  static const Color riskCritical = Color(0xFFD64545); // Red
  static const Color riskHigh     = Color(0xFFEA7D1C); // Orange (brand accent)
  static const Color riskMedium   = Color(0xFFD99A24); // Amber
  static const Color riskWarning  = Color(0xFFF0C060); // Light amber
  static const Color riskLow      = Color(0xFF2E8B68); // Success green
  static const Color riskNormal   = Color(0xFF2E8B68);

  // ── UI utilities ──────────────────────────────────────────────────────────
  static const Color disabled    = Color(0xFFE5E9EA);
  static const Color overlay     = Color(0x0A000000);
  static const Color cardShadow  = Color(0x14000000);

  // Legacy aliases kept so existing screens compile without changes.
  static const Color secondary       = Color(0xFF2A8A91); // = primaryLight
  static const Color secondaryLight  = Color(0xFF4DABB2);
  static const Color secondaryDark   = Color(0xFF0E4347); // = primaryDark
  static const Color cardBackground  = surface;
  static const Color surfaceVariantOld = surfaceVariant;

  // ── Gradients ─────────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryLight],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, accentLight],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [success, Color(0xFF3DAA84)],
  );

  static const LinearGradient warningGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [warning, Color(0xFFEFB84A)],
  );

  static const LinearGradient errorGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [error, Color(0xFFE87070)],
  );
}
