import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../local/offline_providers.dart';
import '../local/user_state_repository.dart';
import '../supabase/supabase_bootstrap.dart';
import 'bandplan_theme.dart';

enum AppThemeChoice { system, light, dark, amoled }
enum AppCornerStyle { soft, balanced, sharp }
enum AppElementDensity { compact, standard, comfortable }
enum AppDepthStyle { soft, balanced, flat }
enum AppTextSize { standard, large, extraLarge }
enum AppContrast { standard, high }

class AppAppearance {
  const AppAppearance({
    this.themeChoice = AppThemeChoice.system,
    this.accentColorValue = 0xFF1554FF,
    this.cornerStyle = AppCornerStyle.soft,
    this.cardCornerStyle = AppCornerStyle.soft,
    this.buttonCornerStyle = AppCornerStyle.soft,
    this.fieldCornerStyle = AppCornerStyle.soft,
    this.elementDensity = AppElementDensity.standard,
    this.depthStyle = AppDepthStyle.soft,
    this.textSize = AppTextSize.standard,
    this.contrast = AppContrast.standard,
    this.surfaceTone = AppSurfaceTone.neutral,
  });
  static const defaults = AppAppearance();
  final AppThemeChoice themeChoice;
  final int accentColorValue;
  final AppCornerStyle cornerStyle;
  final AppCornerStyle cardCornerStyle;
  final AppCornerStyle buttonCornerStyle;
  final AppCornerStyle fieldCornerStyle;
  final AppElementDensity elementDensity;
  final AppDepthStyle depthStyle;
  final AppTextSize textSize;
  final AppContrast contrast;
  final AppSurfaceTone surfaceTone;
  // WHY: A stronger Material color scheme improves distinction without changing the chosen accent.
  double get contrastLevel => contrast == AppContrast.high ? 0.5 : 0.0;
  // WHY: Typography presets tune the app's baseline while retaining platform accessibility scaling.
  double get textSizeFactor => switch (textSize) {
    AppTextSize.standard => 1.0,
    AppTextSize.large => 1.08,
    AppTextSize.extraLarge => 1.16,
  };
  Color get accentColor => Color(accentColorValue);
  // WHY: Component-specific radii let users tune cards, controls and fields independently.
  double get cornerRadius => _radiusFor(cornerStyle);
  double get cardCornerRadius => _radiusFor(cardCornerStyle);
  double get buttonCornerRadius => _radiusFor(buttonCornerStyle);
  double get fieldCornerRadius => _radiusFor(fieldCornerStyle);
  static double _radiusFor(AppCornerStyle style) => switch (style) {
    AppCornerStyle.soft => 24, AppCornerStyle.balanced => 18, AppCornerStyle.sharp => 12,
  };
  // WHY: A single depth preference keeps card and primary-control elevation consistent.
  double get depthElevation => switch (depthStyle) {
    AppDepthStyle.soft => 2.0,
    AppDepthStyle.balanced => 0.8,
    AppDepthStyle.flat => 0.0,
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
    AppCornerStyle? cornerStyle, AppCornerStyle? cardCornerStyle,
    AppCornerStyle? buttonCornerStyle, AppCornerStyle? fieldCornerStyle,
    AppElementDensity? elementDensity, AppDepthStyle? depthStyle,
    AppTextSize? textSize, AppContrast? contrast,
    AppSurfaceTone? surfaceTone}) => AppAppearance(
      themeChoice: themeChoice ?? this.themeChoice,
      accentColorValue: accentColorValue ?? this.accentColorValue,
      cornerStyle: cornerStyle ?? this.cornerStyle,
      cardCornerStyle: cardCornerStyle ?? (cornerStyle ?? this.cardCornerStyle),
      buttonCornerStyle: buttonCornerStyle ?? (cornerStyle ?? this.buttonCornerStyle),
      fieldCornerStyle: fieldCornerStyle ?? (cornerStyle ?? this.fieldCornerStyle),
      elementDensity: elementDensity ?? this.elementDensity,
      depthStyle: depthStyle ?? this.depthStyle,
      textSize: textSize ?? this.textSize,
      contrast: contrast ?? this.contrast,
      surfaceTone: surfaceTone ?? this.surfaceTone,
    );
  Map<String, Object?> toMap() => {
    'themeChoice': themeChoice.name, 'accentColorValue': accentColorValue,
    'cornerStyle': cornerStyle.name,
    'cardCornerStyle': cardCornerStyle.name,
    'buttonCornerStyle': buttonCornerStyle.name,
    'fieldCornerStyle': fieldCornerStyle.name,
    'elementDensity': elementDensity.name,
    'depthStyle': depthStyle.name,
    'textSize': textSize.name,
    'contrast': contrast.name,
    'surfaceTone': surfaceTone.name,
  };
  factory AppAppearance.fromMap(Map<String, Object?> values) => AppAppearance(
    themeChoice: _enumValue(AppThemeChoice.values, values['themeChoice'], AppThemeChoice.system),
    accentColorValue: values['accentColorValue'] is num
      ? (values['accentColorValue'] as num).toInt() : defaults.accentColorValue,
    cornerStyle: _enumValue(AppCornerStyle.values, values['cornerStyle'], AppCornerStyle.soft),
    // WHY: Older profiles inherit their previous global shape preference for each component.
    cardCornerStyle: _enumValue(AppCornerStyle.values, values['cardCornerStyle'],
      _enumValue(AppCornerStyle.values, values['cornerStyle'], AppCornerStyle.soft)),
    buttonCornerStyle: _enumValue(AppCornerStyle.values, values['buttonCornerStyle'],
      _enumValue(AppCornerStyle.values, values['cornerStyle'], AppCornerStyle.soft)),
    fieldCornerStyle: _enumValue(AppCornerStyle.values, values['fieldCornerStyle'],
      _enumValue(AppCornerStyle.values, values['cornerStyle'], AppCornerStyle.soft)),
    // WHY: Existing saved preferences without density retain the standard layout.
    elementDensity: _enumValue(AppElementDensity.values, values['elementDensity'], AppElementDensity.standard),
    // WHY: Profiles saved before depth controls keep the soft-clay default.
    depthStyle: _enumValue(AppDepthStyle.values, values['depthStyle'], AppDepthStyle.soft),
    // WHY: Existing installations keep the current typography until a user changes it.
    textSize: _enumValue(AppTextSize.values, values['textSize'], AppTextSize.standard),
    // WHY: Legacy preferences retain the existing standard contrast.
    contrast: _enumValue(AppContrast.values, values['contrast'], AppContrast.standard),
    // WHY: Profiles created before surface tones keep the established neutral palette.
    surfaceTone: _enumValue(AppSurfaceTone.values, values['surfaceTone'], AppSurfaceTone.neutral),
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
    final localPreferences = await store.readAppPreferences();
    if (!SupabaseBootstrap.isInitialized) {
      return AppAppearance.fromMap(localPreferences);
    }
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return AppAppearance.fromMap(localPreferences);

    final syncEngine = await ref.watch(offlineSyncEngineProvider.future);
    final repository = UserStateRepository(
      client: Supabase.instance.client,
      store: store,
      syncEngine: syncEngine,
    );
    final userState = await repository.readState();
    final rawSettings = userState['settings'];
    final settings = rawSettings is Map
        ? Map<String, Object?>.from(rawSettings)
        : <String, Object?>{};
    final rawAppearance = settings['bandplanAppearance'];
    if (rawAppearance is Map) {
      final preferences = Map<String, Object?>.from(rawAppearance);
      // WHY: Mirror the confirmed account settings locally for fast startup
      // and offline rendering, while Supabase remains the source of truth.
      await store.saveAppPreferences(preferences);
      return AppAppearance.fromMap(preferences);
    }
    return AppAppearance.fromMap(localPreferences);
  }

  Future<void> saveAppearance(AppAppearance appearance) async {
    final store = await ref.read(offlineStoreProvider.future);
    // WHY: Apply immediately and keep a durable local copy before network sync.
    await store.saveAppPreferences(appearance.toMap());
    // WHY: Theme changes should take effect immediately; a later server
    // rejection remains visible in the profile sync/conflict controls.
    state = AsyncData(appearance);

    final user = SupabaseBootstrap.isInitialized
        ? Supabase.instance.client.auth.currentUser
        : null;
    if (user != null) {
      final syncEngine = await ref.read(offlineSyncEngineProvider.future);
      final repository = UserStateRepository(
        client: Supabase.instance.client,
        store: store,
        syncEngine: syncEngine,
      );
      final userState = await repository.readState();
      final rawSettings = userState['settings'];
      final settings = rawSettings is Map
          ? Map<String, Object?>.from(rawSettings)
          : <String, Object?>{};
      // WHY: Namespace new preferences so legacy settings and unknown keys
      // remain intact for older clients and future migrations.
      settings['bandplanAppearance'] = appearance.toMap();
      userState['settings'] = settings;
      final report = await repository.saveState(userState);
      if (report.hasPermanentFailure || report.conflictCount > 0) {
        throw StateError(report.lastError ?? 'Не удалось синхронизировать настройки профиля.');
      }
    }
    state = AsyncData(appearance);
  }

  Future<void> reset() => saveAppearance(AppAppearance.defaults);
}
