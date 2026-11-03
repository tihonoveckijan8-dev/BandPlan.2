import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bandplan/core/theme/app_appearance.dart';

void main() {
  group('AppAppearance', () {
    test('restores selected theme, accent and corner style', () {
      final appearance = AppAppearance.fromMap({
        'themeChoice': 'amoled',
        'accentColorValue': 0xFF7657FF,
        'cornerStyle': 'sharp',
      });

      expect(appearance.themeChoice, AppThemeChoice.amoled);
      expect(appearance.accentColor, const Color(0xFF7657FF));
      expect(appearance.cornerStyle, AppCornerStyle.sharp);
      expect(appearance.materialThemeMode, ThemeMode.dark);
      expect(appearance.useAmoled, isTrue);
    });

    test('falls back safely when saved values are unknown', () {
      final appearance = AppAppearance.fromMap({
        'themeChoice': 'not-a-theme',
        'accentColorValue': 'blue',
        'cornerStyle': 'not-a-shape',
      });

      expect(appearance.themeChoice, AppThemeChoice.system);
      expect(appearance.accentColorValue, 0xFF1554FF);
      expect(appearance.cornerStyle, AppCornerStyle.soft);
    });

    test('restores independent element shapes and depth preference', () {
      final appearance = AppAppearance.fromMap({
        'cardCornerStyle': 'sharp',
        'buttonCornerStyle': 'balanced',
        'fieldCornerStyle': 'soft',
        'depthStyle': 'flat',
      });

      expect(appearance.cardCornerRadius, 12);
      expect(appearance.buttonCornerRadius, 18);
      expect(appearance.fieldCornerRadius, 24);
      expect(appearance.depthElevation, 0);
    });

    test('keeps older preference maps compatible with soft defaults', () {
      final appearance = AppAppearance.fromMap({
        'themeChoice': 'dark',
        'cornerStyle': 'balanced',
      });

      expect(appearance.cardCornerStyle, AppCornerStyle.balanced);
      expect(appearance.buttonCornerStyle, AppCornerStyle.balanced);
      expect(appearance.fieldCornerStyle, AppCornerStyle.balanced);
      expect(appearance.depthStyle, AppDepthStyle.soft);
    });

    test('maps each theme choice to the expected Material theme mode', () {
      expect(
        AppAppearance(themeChoice: AppThemeChoice.system).materialThemeMode,
        ThemeMode.system,
      );
      expect(
        AppAppearance(themeChoice: AppThemeChoice.light).materialThemeMode,
        ThemeMode.light,
      );
      expect(
        AppAppearance(themeChoice: AppThemeChoice.dark).materialThemeMode,
        ThemeMode.dark,
      );
      expect(
        AppAppearance(themeChoice: AppThemeChoice.amoled).materialThemeMode,
        ThemeMode.dark,
      );
    });

    test('serializes preferences for durable storage', () {
      const appearance = AppAppearance(
        themeChoice: AppThemeChoice.dark,
        accentColorValue: 0xFFE05D83,
        cornerStyle: AppCornerStyle.balanced,
      );

      expect(
        AppAppearance.fromMap(appearance.toMap()).toMap(),
        appearance.toMap(),
      );
    });
  });
}
