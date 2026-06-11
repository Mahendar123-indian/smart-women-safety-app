// lib/core/theme/app_colors.dart

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Brand Colors ─────────────────────────────────────────────
  static const Color primary        = Color(0xFFE91E8C);
  static const Color primaryDark    = Color(0xFFC2185B);
  static const Color primaryLight   = Color(0xFFF48FB1);
  static const Color secondary      = Color(0xFF6C63FF);
  static const Color secondaryDark  = Color(0xFF4A44C6);
  static const Color accent         = Color(0xFFFF6B6B);

  // ── SOS Colors ───────────────────────────────────────────────
  static const Color sosRed         = Color(0xFFFF1744);
  static const Color sosRedDark     = Color(0xFFD50000);
  static const Color sosRedLight    = Color(0xFFFF5252);
  static const Color safeGreen      = Color(0xFF00C853);
  static const Color warningAmber   = Color(0xFFFFAB00);

  // ── Danger Score Colors ──────────────────────────────────────
  static const Color dangerLow      = Color(0xFF00C853);
  static const Color dangerMedium   = Color(0xFFFFAB00);
  static const Color dangerHigh     = Color(0xFFFF6D00);
  static const Color dangerCritical = Color(0xFFFF1744);

  // ── Light Theme ──────────────────────────────────────────────
  static const Color lightBackground    = Color(0xFFFAFAFA);
  static const Color lightSurface       = Color(0xFFFFFFFF);
  static const Color lightCard          = Color(0xFFFFFFFF);
  static const Color lightText          = Color(0xFF1A1A2E);
  static const Color lightTextSecondary = Color(0xFF6B7280);
  static const Color lightBorder        = Color(0xFFE5E7EB);
  static const Color lightDivider       = Color(0xFFF3F4F6);

  // ── Dark Theme ───────────────────────────────────────────────
  static const Color darkBackground    = Color(0xFF0D0D1A);
  static const Color darkSurface       = Color(0xFF1A1A2E);
  static const Color darkCard          = Color(0xFF16213E);
  static const Color darkText          = Color(0xFFF9FAFB);
  static const Color darkTextSecondary = Color(0xFF9CA3AF);
  static const Color darkBorder        = Color(0xFF374151);
  static const Color darkDivider       = Color(0xFF1F2937);

  // ── Gradients ────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFE91E8C), Color(0xFF6C63FF)],
    begin: Alignment.topLeft,
    end:   Alignment.bottomRight,
  );

  static const LinearGradient sosGradient = LinearGradient(
    colors: [Color(0xFFFF1744), Color(0xFFFF6B6B)],
    begin: Alignment.topCenter,
    end:   Alignment.bottomCenter,
  );

  static const LinearGradient safeGradient = LinearGradient(
    colors: [Color(0xFF00C853), Color(0xFF69F0AE)],
    begin: Alignment.topLeft,
    end:   Alignment.bottomRight,
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
    begin: Alignment.topLeft,
    end:   Alignment.bottomRight,
  );

  static const LinearGradient warningGradient = LinearGradient(
    colors: [Color(0xFFFFAB00), Color(0xFFFF6D00)],
    begin: Alignment.topLeft,
    end:   Alignment.bottomRight,
  );

  static const LinearGradient purpleGradient = LinearGradient(
    colors: [Color(0xFF6C63FF), Color(0xFF4A44C6)],
    begin: Alignment.topLeft,
    end:   Alignment.bottomRight,
  );

  // ── Shadows ──────────────────────────────────────────────────
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color:      Colors.black.withValues(alpha: 0.08),
      blurRadius: 20,
      offset:     const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get sosButtonShadow => [
    BoxShadow(
      color:        sosRed.withValues(alpha: 0.4),
      blurRadius:   30,
      spreadRadius: 5,
      offset:       const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> get primaryShadow => [
    BoxShadow(
      color:      primary.withValues(alpha: 0.3),
      blurRadius: 20,
      offset:     const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> get safeShadow => [
    BoxShadow(
      color:      safeGreen.withValues(alpha: 0.35),
      blurRadius: 20,
      offset:     const Offset(0, 6),
    ),
  ];

  // ── Adaptive helpers (use inside widgets with context) ───────
  static Color background(bool isDark) =>
      isDark ? darkBackground : lightBackground;

  static Color surface(bool isDark) =>
      isDark ? darkSurface : lightSurface;

  static Color card(bool isDark) =>
      isDark ? darkCard : lightCard;

  static Color textPrimary(bool isDark) =>
      isDark ? darkText : lightText;

  static Color textSecondary(bool isDark) =>
      isDark ? darkTextSecondary : lightTextSecondary;

  static Color border(bool isDark) =>
      isDark ? darkBorder : lightBorder;

  static Color divider(bool isDark) =>
      isDark ? darkDivider : lightDivider;

  // ── Danger level helpers ─────────────────────────────────────
  static Color dangerLevelColor(double score) {
    if (score < 0.25) return safeGreen;
    if (score < 0.50) return warningAmber;
    if (score < 0.75) return dangerHigh;
    return sosRed;
  }

  static Color dangerLevelBackground(double score) {
    if (score < 0.25) return safeGreen.withValues(alpha: 0.12);
    if (score < 0.50) return warningAmber.withValues(alpha: 0.10);
    if (score < 0.75) return dangerHigh.withValues(alpha: 0.12);
    return sosRed.withValues(alpha: 0.12);
  }
}