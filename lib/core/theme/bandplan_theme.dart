import 'package:flutter/material.dart';

enum AppSurfaceTone { neutral, cool, warm }

/// Shared dual-shadow tokens for raised, tactile BandPlan surfaces.
@immutable
class BandPlanClayDepth extends ThemeExtension<BandPlanClayDepth> {
  const BandPlanClayDepth({
    required this.surface,
    required this.highlight,
    required this.shadow,
    required this.intensity,
  });

  final Color surface;
  final Color highlight;
  final Color shadow;
  final double intensity;

  List<BoxShadow> get raisedShadows {
    if (intensity <= 0) return const <BoxShadow>[];
    final offset = 2.0 + intensity * 1.6;
    final blur = 5.0 + intensity * 4.0;
    return <BoxShadow>[
      BoxShadow(
        color: shadow,
        offset: Offset(offset, offset),
        blurRadius: blur,
      ),
      BoxShadow(
        color: highlight,
        offset: Offset(-offset, -offset),
        blurRadius: blur,
      ),
    ];
  }

  @override
  BandPlanClayDepth copyWith({
    Color? surface,
    Color? highlight,
    Color? shadow,
    double? intensity,
  }) =>
      BandPlanClayDepth(
        surface: surface ?? this.surface,
        highlight: highlight ?? this.highlight,
        shadow: shadow ?? this.shadow,
        intensity: intensity ?? this.intensity,
      );

  @override
  BandPlanClayDepth lerp(
    covariant ThemeExtension<BandPlanClayDepth>? other,
    double t,
  ) {
    if (other is! BandPlanClayDepth) return this;
    return BandPlanClayDepth(
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      highlight: Color.lerp(highlight, other.highlight, t) ?? highlight,
      shadow: Color.lerp(shadow, other.shadow, t) ?? shadow,
      intensity: intensity + (other.intensity - intensity) * t,
    );
  }
}

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

    // WHY: Two opposing shadows create the soft-clay lift while keeping the
    // same neutral surface color in light, dark, and AMOLED modes.
    final clayHighlight = isDark
        ? Colors.white.withValues(alpha: isAmoled ? 0.055 : 0.045)
        : Colors.white.withValues(alpha: 0.92);
    final clayShadow = isDark
        ? Colors.black.withValues(alpha: isAmoled ? 0.72 : 0.38)
        : const Color(0xFF9EA9BC).withValues(alpha: 0.42);

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
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 64,
        centerTitle: false,
        titleTextStyle: ThemeData(
          brightness: brightness,
          fontFamily: 'Manrope',
        ).textTheme.titleLarge?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.35,
            ),
      ),
      extensions: <ThemeExtension<dynamic>>[
        BandPlanClayDepth(
          surface: cardColor,
          highlight: clayHighlight,
          shadow: clayShadow,
          intensity: depthElevation,
        ),
      ],
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: depthElevation * 1.6,
        shadowColor: clayShadow,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
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
          elevation: depthElevation * 1.45,
          shadowColor: clayShadow,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonCornerRadius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: cardColor,
          foregroundColor: scheme.onSurface,
          elevation: depthElevation,
          shadowColor: clayShadow,
          side: BorderSide.none,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonCornerRadius),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
        elevation: depthElevation * 1.8,
        focusElevation: depthElevation * 2,
        hoverElevation: depthElevation * 2,
        highlightElevation: depthElevation * 0.55,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(buttonCornerRadius),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        elevation: depthElevation * 1.5,
        height: 72,
        indicatorColor: accentColor.withValues(alpha: isDark ? 0.24 : 0.12),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(buttonCornerRadius * 0.72),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) =>
          ThemeData(brightness: brightness, fontFamily: 'Manrope')
              .textTheme.labelSmall?.copyWith(
                fontWeight: states.contains(WidgetState.selected)
                    ? FontWeight.w800
                    : FontWeight.w600,
              )),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: cardColor,
        elevation: depthElevation,
        indicatorColor: accentColor.withValues(alpha: isDark ? 0.24 : 0.12),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(buttonCornerRadius * 0.72),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        elevation: depthElevation * 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardCornerRadius * 1.15),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        elevation: depthElevation * 2,
        showDragHandle: true,
        dragHandleColor: scheme.onSurfaceVariant.withValues(alpha: 0.35),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(cardCornerRadius * 1.2),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(buttonCornerRadius * 0.8),
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
