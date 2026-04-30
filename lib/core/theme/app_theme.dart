import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Material 3 light theme for Brainjamin using token colors (exact brand orange).
final class BrainjaminTheme {
  BrainjaminTheme._();

  /// Light theme only; dark theme is out of scope for V1.
  static ThemeData get light {
    final base = ColorScheme.fromSeed(
      seedColor: BrainjaminColors.brandOrange,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: base.copyWith(
        primary: BrainjaminColors.brandOrange,
        surface: BrainjaminColors.surface,
        surfaceContainerHighest: BrainjaminColors.surfaceVariant,
        onSurface: BrainjaminColors.onSurface,
        error: BrainjaminColors.error,
        surfaceTint: BrainjaminColors.brandOrange,
        primaryContainer: BrainjaminColors.brandOrangeLight.withValues(alpha: 0.35),
      ),
      scaffoldBackgroundColor: BrainjaminColors.surface,
    );
  }
}
