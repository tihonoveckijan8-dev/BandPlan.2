import 'package:flutter/material.dart';

/// Shared visual foundation for the BandPlan Flutter client.
abstract final class BandPlanTheme {
  static const accent = Color(0xFF1554FF);
  static const lightCanvas = Color(0xFFF3F5FA);
  static const darkCanvas = Color(0xFF171A22);
  static const amoledCanvas = Color(0xFF000000);

  static ThemeData light({
    Color accentColor = accent,
    double cornerRadius = 24,
    VisualDensity visualDensity = visualDensity,
  }) =>
      _build(
        Brightness.light,
        lightCanvas,
        accentColor: accentColor,
        cornerRadius: cornerRadius,
      );

  static ThemeData dark({
    Color accentColor = accent,
    double cornerRadius = 24,
  }) =>
      _build(
        Brightness.dark,
        darkCanvas,
        accentColor: accentColor,
        cornerRadius: cornerRadius,
      );

  static ThemeData amoled({
    Color accentColor = accent,
    double cornerRadius = 24,
  }) =>
      _build(
        Brightness.dark,
        amoledCanvas,
        accentColor: accentColor,
        cornerRadius: cornerRadius,
        isAmoled: true,
      );

  static ThemeData _build(
    Brightness brightness,
    Color canvas, {
    required Color accentColor,
    required double cornerRadius,
    required VisualDensity visualDensity,
    bool isAmoled = false,
  }) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: accentColor,
      brightness: brightness,
      surface: canvas,
    );
    final cardColor = isAmoled
        ? const Color(0xFF090909)
        : isDark
            ? const Color(0xFF222631)
            : const Color(0xFFF8F9FD);
    final inputColor = isAmoled
        ? const Color(0xFF111111)
        : isDark
            ? const Color(0xFF222631)
            : const Color(0xFFE9EDF5);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      fontFamily: 'Manrope',
      visualDensity: visualDensity,
      appBarTheme: AppBarTheme(
        backgroundColor: canvas,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cornerRadius),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(cornerRadius * 0.72),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(cornerRadius * 0.72),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(cornerRadius * 0.72),
          borderSide: BorderSide(color: accentColor, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(cornerRadius * 0.72),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(cornerRadius * 0.72),
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.35),
        space: 1,
        thickness: 1,
      ),
    );
  }
}
