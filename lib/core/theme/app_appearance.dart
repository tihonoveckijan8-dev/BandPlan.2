import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../local/offline_providers.dart';

enum AppThemeChoice { system, light, dark, amoled }
enum AppCornerStyle { soft, balanced, sharp }
enum AppElementDensity { compact, standard, comfortable }

class AppAppearance {
  const AppAppearance({
    this.themeChoice = AppThemeChoice.system,
    this.accentColorValue = 0xFF1554FF,
    this.cornerStyle = AppCornerStyle.soft,
    this.elementDensity = AppElementDensity.standard,
  });
  static const defaults = AppAppearance();
  final AppThemeChoice themeChoice;
  final int accentColorValue;
  final AppCornerStyle cornerStyle;
  final AppElementDensity elementDensity;
  Color get accentColor => Color(accentColorValue);
  double get cornerRadius => switch (cornerStyle) {
    AppCornerStyle.soft => 24, AppCornerStyle.balanced => 18, AppCornerStyle.sharp => 12,
  };
  VisualDensity get visualDensity => switch (elementDensity) {
    AppElementDensity.compact => VisualDensity.compact,
    AppElementDensity.standard => VisualDensity.standard,
    AppElementDensity.comfortable => VisualDensity.comfortable,
  };
  ThemeMode get materialThemeMode => switch (themeChoice) {
    AppThemeChoice.system => ThemeMode.system,
    AppThemeChoice.light => ThemeMode.light,
    AppThemeChoice.dark || AppThemeChoice.amoled => ThemeMode.dark,
  };
  bool get useAmoled => themeChoice == AppThemeChoice.amoled;
  AppAppearance copyWith({AppThemeChoice? themeChoice, int? accentColorValue,
    AppCornerStyle? cornerStyle, AppElementDensity? elementDensity}) => AppAppearance(
      themeChoice: themeChoice ?? this.themeChoice,
      accentColorValue: accentColorValue ?? this.accentColorValue,
      cornerStyle: cornerStyle ?? this.cornerStyle,
      elementDensity: elementDensity ?? this.elementDensity,
    );
  Map<String, Object?> toMap() => {
    'themeChoice': themeChoice.name, 'accentColorValue': accentColorValue,
    'cornerStyle': cornerStyle.name, 'elementDensity': elementDensity.name,
  };
  factory AppAppearance.fromMap(Map<String, Object?> values) => AppAppearance(
    themeChoice: _enumValue(AppThemeChoice.values, values['themeChoice'], AppThemeChoice.system),
    accentColorValue: values['accentColorValue'] is num
      ? (values['accentColorValue'] as num).toInt() : defaults.accentColorValue,
    cornerStyle: _enumValue(AppCornerStyle.values, values['cornerStyle'], AppCornerStyle.soft),
    // WHY: Existing saved preferences without density retain the standard layout.
    elementDensity: _enumValue(AppElementDensity.values, values['elementDensity'], AppElementDensity.standard),
  );
  static T _enumValue<T extends Enum>(List<T> values, Object? rawValue, T fallback) {
    for (final value in values) { if (value.name == rawValue?.toString()) return value; }
    return fallback;
  }
}
final appAppearanceProvider = AsyncNotifierProvider<AppAppearanceController, AppAppearance>(AppAppearanceController.new);
class AppAppearanceController extends AsyncNotifier<AppAppearance> {
  @override
  Future<AppAppearance> build() async {
    final store = await ref.watch(offlineStoreProvider.future);
    return AppAppearance.fromMap(await store.readAppPreferences());
  }
  Future<void> saveAppearance(AppAppearance appearance) async {
    final store = await ref.read(offlineStoreProvider.future);
    // WHY: Keep preferences durable and editable while offline.
    await store.saveAppPreferences(appearance.toMap());
    state = AsyncData(appearance);
  }
  Future<void> reset() => saveAppearance(AppAppearance.defaults);
}
