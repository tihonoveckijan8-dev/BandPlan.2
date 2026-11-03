import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../local/offline_providers.dart';

enum AppThemeChoice { system, light, dark, amoled }

enum AppCornerStyle { soft, balanced, sharp }

class AppAppearance {
  const AppAppearance({
    this.themeChoice = AppThemeChoice.system,
    this.accentColorValue = 0xFF1554FF,
    this.cornerStyle = AppCornerStyle.soft,
  });

  static const defaults = AppAppearance();

  final AppThemeChoice themeChoice;
  final int accentColorValue;
  final AppCornerStyle cornerStyle;

  Color get accentColor => Color(accentColorValue);

  double get cornerRadius => switch (cornerStyle) {
        AppCornerStyle.soft => 24,
        AppCornerStyle.balanced => 18,
        AppCornerStyle.sharp => 12,
      };

  ThemeMode get materialThemeMode => switch (themeChoice) {
        AppThemeChoice.system => ThemeMode.system,
        AppThemeChoice.light => ThemeMode.light,
        AppThemeChoice.dark || AppThemeChoice.amoled => ThemeMode.dark,
      };

  bool get useAmoled => themeChoice == AppThemeChoice.amoled;

  AppAppearance copyWith({
    AppThemeChoice? themeChoice,
    int? accentColorValue,
    AppCornerStyle? cornerStyle,
  }) =>
      AppAppearance(
        themeChoice: themeChoice ?? this.themeChoice,
        accentColorValue: accentColorValue ?? this.accentColorValue,
        cornerStyle: cornerStyle ?? this.cornerStyle,
      );

  Map<String, Object?> toMap() => {
        'themeChoice': themeChoice.name,
        'accentColorValue': accentColorValue,
        'cornerStyle': cornerStyle.name,
      };

  factory AppAppearance.fromMap(Map<String, Object?> values) {
    return AppAppearance(
      themeChoice: _enumValue(
        AppThemeChoice.values,
        values['themeChoice'],
        AppThemeChoice.system,
      ),
      accentColorValue: values['accentColorValue'] is num
          ? (values['accentColorValue'] as num).toInt()
          : defaults.accentColorValue,
      cornerStyle: _enumValue(
        AppCornerStyle.values,
        values['cornerStyle'],
        AppCornerStyle.soft,
      ),
    );
  }

  static T _enumValue<T extends Enum>(
    List<T> values,
    Object? rawValue,
    T fallback,
  ) {
    for (final value in values) {
      if (value.name == rawValue?.toString()) return value;
    }
    return fallback;
  }
}

final appAppearanceProvider =
    AsyncNotifierProvider<AppAppearanceController, AppAppearance>(
  AppAppearanceController.new,
);

class AppAppearanceController extends AsyncNotifier<AppAppearance> {
  @override
  Future<AppAppearance> build() async {
    final store = await ref.watch(offlineStoreProvider.future);
    final saved = await store.readAppPreferences();
    return AppAppearance.fromMap(saved);
  }

  Future<void> update(AppAppearance appearance) async {
    final store = await ref.read(offlineStoreProvider.future);
    // WHY: Save preferences in the same durable IndexedDB database so the
    // user's appearance survives a browser restart and remains editable offline.
    await store.saveAppPreferences(appearance.toMap());
    state = AsyncData(appearance);
  }

  Future<void> reset() => update(AppAppearance.defaults);
}
