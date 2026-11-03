import 'package:flutter/material.dart';

enum AppSurfaceTone { neutral, cool, warm }

/// Shared visual foundation for the BandPlan Flutter client.
abstract final class BandPlanTheme {
  static const accent = Color(0xFF1554FF);
  static const lightCanvas = Color(0xFFF3F5FA);
  static const darkCanvas = Color(0xFF171A22);
  static const amoledCanvas = Color(0xFF000000);

  static ThemeData light({
    Color accentColor = accent,
    double cornerRadius = 24,
    double? cardCornerRadius,
    double? buttonCornerRadius,
    double? fieldCornerRadius,
    VisualDensity visualDensity = VisualDensity.standard,
    double depthElevation = 2.0,
    double fontSizeFactor = 1.0,
    double contrastLevel = 0.0,
    AppSurfaceTone surfaceTone = AppSurfaceTone.neutral,
  }) =>
      _build(
        Brightness.light,
        lightCanvas,
        accentColor: accentColor,
        cardCornerRadius: cardCornerRadius ?? cornerRadius,
        buttonCornerRadius: buttonCornerRadius ?? cornerRadius,
        fieldCornerRadius: fieldCornerRadius ?? cornerRadius,
        visualDensity: visualDensity,
        depthElevation: depthElevation,
        fontSizeFactor: fontSizeFactor,
        contrastLevel: contrastLevel,
        surfaceTone: surfaceTone,
      );

  static ThemeData dark({
    Color accentColor = accent,
    double cornerRadius = 24,
    double? cardCornerRadius,
    double? buttonCornerRadius,
    double? fieldCornerRadius,
    VisualDensity visualDensity = VisualDensity.standard,
    double depthElevation = 2.0,
    double fontSizeFactor = 1.0,
    double contrastLevel = 0.0,
    AppSurfaceTone surfaceTone = AppSurfaceTone.neutral,
  }) =>
      _build(
        Brightness.dark,
        darkCanvas,
        accentColor: accentColor,
        cardCornerRadius: cardCornerRadius ?? cornerRadius,
        buttonCornerRadius: buttonCornerRadius ?? cornerRadius,
        fieldCornerRadius: fieldCornerRadius ?? cornerRadius,
        visualDensity: visualDensity,
        depthElevation: depthElevation,
        fontSizeFactor: fontSizeFactor,
        contrastLevel: contrastLevel,
        surfaceTone: surfaceTone,
      );

  static ThemeData amoled({
    Color accentColor = accent,
    double cornerRadius = 24,
    double? cardCornerRadius,
    double? buttonCornerRadius,
    double? fieldCornerRadius,
    VisualDensity visualDensity = VisualDensity.standard,
    double depthElevation = 2.0,
    double fontSizeFactor = 1.0,
    double contrastLevel = 0.0,
    AppSurfaceTone surfaceTone = AppSurfaceTone.neutral,
  }) =>
      _build(
        Brightness.dark,
        amoledCanvas,
        accentColor: accentColor,
        cardCornerRadius: cardCornerRadius ?? cornerRadius,
        buttonCornerRadius: buttonCornerRadius ?? cornerRadius,
        fieldCornerRadius: fieldCornerRadius ?? cornerRadius,
        visualDensity: visualDensity,
        depthElevation: depthElevation,
        fontSizeFactor: fontSizeFactor,
        contrastLevel: contrastLevel,
        surfaceTone: surfaceTone,
        isAmoled: true,
      );

  static ThemeData _build(
    Brightness brightness,
    Color canvas, {
    required Color accentColor,
    required double cardCornerRadius,
    required double buttonCornerRadius,
    required double fieldCornerRadius,
    required VisualDensity visualDensity,
    required double depthElevation,
    required double fontSizeFactor,
    required double contrastLevel,
    required AppSurfaceTone surfaceTone,
    bool isAmoled = false,
  }) {
    final isDark = brightness == Brightness.dark;
    // WHY: Surface tone personalizes neutral UI surfaces without changing accent colors or semantic states.
    final tonedCanvas = isAmoled ? canvas : switch ((brightness, surfaceTone)) {
      (Brightness.light, AppSurfaceTone.cool) => const Color(0xFFEEF3FA),
      (Brightness.light, AppSurfaceTone.warm) => const Color(0xFFF7F2EC),
      (Brightness.dark, AppSurfaceTone.cool) => const Color(0xFF151C27),
      (Brightness.dark, AppSurfaceTone.warm) => const Color(0xFF211C1A),
      _ => canvas,
    };
    final scheme = ColorScheme.fromSeed(
      seedColor: accentColor,
      brightness: brightness,
      surface: tonedCanvas,
      contrastLevel: contrastLevel,
    );
    final cardColor = isAmoled
        ? const Color(0xFF090909)
        : switch ((brightness, surfaceTone)) {
            (Brightness.light, AppSurfaceTone.cool) => const Color(0xFFF5F8FD),
            (Brightness.light, AppSurfaceTone.warm) => const Color(0xFFFCF7F1),
            (Brightness.dark, AppSurfaceTone.cool) => const Color(0xFF202A37),
            (Brightness.dark, AppSurfaceTone.warm) => const Color(0xFF2B2522),
            _ => isDark ? const Color(0xFF222631) : const Color(0xFFF8F9FD),
          };
    final inputColor = isAmoled
        ? const Color(0xFF111111)
        : switch ((brightness, surfaceTone)) {
            (Brightness.light, AppSurfaceTone.cool) => const Color(0xFFE5ECF6),
            (Brightness.light, AppSurfaceTone.warm) => const Color(0xFFF0E8DE),
            (Brightness.dark, AppSurfaceTone.cool) => const Color(0xFF202A37),
            (Brightness.dark, AppSurfaceTone.warm) => const Color(0xFF2B2522),
            _ => isDark ? const Color(0xFF222631) : const Color(0xFFE9EDF5),
          };

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: tonedCanvas,
      fontFamily: 'Manrope',
      // WHY: Scale theme typography consistently without replacing MediaQuery accessibility scaling.
      textTheme: ThemeData(brightness: brightness, fontFamily: 'Manrope').textTheme.apply(fontSizeFactor: fontSizeFactor),
      primaryTextTheme: ThemeData(brightness: brightness, fontFamily: 'Manrope').primaryTextTheme.apply(fontSizeFactor: fontSizeFactor),
      visualDensity: visualDensity,
      appBarTheme: AppBarTheme(
        backgroundColor: tonedCanvas,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: depthElevation,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardCornerRadius),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(fieldCornerRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(fieldCornerRadius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(fieldCornerRadius),
          borderSide: BorderSide(color: accentColor, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accentColor,
          elevation: depthElevation * 0.45,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonCornerRadius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonCornerRadius),
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
