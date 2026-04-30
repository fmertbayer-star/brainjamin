import 'package:flutter/material.dart';

/// Brand and semantic colors for Brainjamin (light theme).
///
/// PR-1: `#FF9F04` is BANNED everywhere — do not use that hex in UI, code,
/// comments, or docs. Brand orange is `#F97316` only.

/// Named color tokens for the Brainjamin light theme.
final class BrainjaminColors {
  BrainjaminColors._();

  /// Primary brand orange (`#F97316`).
  static const Color brandOrange = Color(0xFFF97316);

  /// Lighter orange for gradients and highlights (Tailwind orange-400 family).
  static const Color brandOrangeLight = Color(0xFFFB923C);

  /// Darker orange for pressed/active states (Tailwind orange-700).
  static const Color brandOrangeDark = Color(0xFFC2410C);

  /// App chrome background.
  static const Color surface = Color(0xFFFAFAFA);

  /// Cards and grouped surfaces on light background.
  static const Color surfaceVariant = Color(0xFFF5F5F5);

  /// Primary body text on light surfaces.
  static const Color onSurface = Color(0xFF1F1F1F);

  /// Secondary / helper text.
  static const Color onSurfaceMuted = Color(0xFF6B7280);

  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);
}
