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

    test('restores and serializes typography size preference', () {
      final appearance = AppAppearance.fromMap({'textSize': 'extraLarge'});

      expect(appearance.textSize, AppTextSize.extraLarge);
      expect(appearance.textSizeFactor, 1.16);
      expect(
        AppAppearance.fromMap(appearance.toMap()).textSize,
        AppTextSize.extraLarge,
      );
    });

    test('uses standard typography for older preference maps', () {
      final appearance = AppAppearance.fromMap({'themeChoice': 'dark'});

      expect(appearance.textSize, AppTextSize.standard);
      expect(appearance.textSizeFactor, 1.0);
    });

    test('restores and serializes contrast preference', () {
      final appearance = AppAppearance.fromMap({'contrast': 'high'});

      expect(appearance.contrast, AppContrast.high);
      expect(appearance.contrastLevel, 0.5);
      expect(
        AppAppearance.fromMap(appearance.toMap()).contrast,
        AppContrast.high,
      );
    });

    test('uses standard contrast for older preference maps', () {
      final appearance = AppAppearance.fromMap({'themeChoice': 'dark'});

      expect(appearance.contrast, AppContrast.standard);
      expect(appearance.contrastLevel, 0.0);
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
