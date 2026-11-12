import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/local/offline_cache_warmup.dart';
import '../core/local/offline_providers.dart';
import '../core/supabase/supabase_bootstrap.dart';
import '../core/theme/app_appearance.dart';
import '../core/theme/bandplan_theme.dart';
import 'router.dart';

class BandPlanApp extends ConsumerStatefulWidget {
  const BandPlanApp({super.key});

  @override
  ConsumerState<BandPlanApp> createState() => _BandPlanAppState();
}

class _BandPlanAppState extends ConsumerState<BandPlanApp>
    with WidgetsBindingObserver {
  Timer? _syncTimer;
  StreamSubscription<AuthState>? _authSubscription;
  final Set<String> _warmingUserIds = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (SupabaseBootstrap.isInitialized) {
      // WHY: The first warmup may run before a user signs in. Listen for the
      // initial restored session and later sign-ins so first-login data is
      // prefetched too, rather than waiting for the user to open each tab.
      _authSubscription =
          Supabase.instance.client.auth.onAuthStateChange.listen((state) {
        if (state.session != null) unawaited(_warmOfflineCache());
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sync();
      // WHY: Warm every accessible group and account snapshot before the user
      // needs it offline, including tabs that have not been opened this session.
      unawaited(_warmOfflineCache());
    });
    // WHY: catch network restoration while the app remains foregrounded.
    // The engine itself applies exponential backoff and serializes all runs.
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) => _sync());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _sync();
      unawaited(_warmOfflineCache());
    }
  }

  Future<void> _sync() async {
    if (!mounted || !SupabaseBootstrap.isInitialized) return;
    try {
      final engine = await ref.read(offlineSyncEngineProvider.future);
      // WHY: recover previously rejected transient writes after connectivity returns.
      await engine.syncPending(retryFailed: true);
      ref.invalidate(offlineQueueStatusProvider);
    } catch (_) {
      // WHY: network failure must never block startup, navigation, or resume.
    }
  }

  Future<void> _warmOfflineCache() async {
    if (!mounted || !SupabaseBootstrap.isInitialized) return;
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null || !_warmingUserIds.add(userId)) return;
    try {
      final store = await ref.read(offlineStoreProvider.future);
      // WHY: Auth can change while IndexedDB is opening; never warm data for
      // an account that is no longer the active signed-in user.
      if (!mounted || client.auth.currentUser?.id != userId) return;
      await OfflineCacheWarmup.run(client: client, store: store);
    } catch (_) {
      // WHY: Cache warmup is best-effort and must never delay or block the UI.
    } finally {
      _warmingUserIds.remove(userId);
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    unawaited(_authSubscription?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appearance =
        ref.watch(appAppearanceProvider).value ?? AppAppearance.defaults;

    return MaterialApp.router(
      title: 'BandPlan',
      debugShowCheckedModeBanner: false,
      theme: BandPlanTheme.light(
        accentColor: appearance.accentColor,
        cornerRadius: appearance.cornerRadius,
        cardCornerRadius: appearance.cardCornerRadius,
        buttonCornerRadius: appearance.buttonCornerRadius,
        fieldCornerRadius: appearance.fieldCornerRadius,
        visualDensity: appearance.visualDensity,
        depthElevation: appearance.depthElevation,
        fontSizeFactor: appearance.textSizeFactor,
        contrastLevel: appearance.contrastLevel,
        surfaceTone: appearance.surfaceTone,
      ),
      darkTheme: appearance.useAmoled
          ? BandPlanTheme.amoled(
              accentColor: appearance.accentColor,
              cornerRadius: appearance.cornerRadius,
              cardCornerRadius: appearance.cardCornerRadius,
              buttonCornerRadius: appearance.buttonCornerRadius,
              fieldCornerRadius: appearance.fieldCornerRadius,
              visualDensity: appearance.visualDensity,
              depthElevation: appearance.depthElevation,
              fontSizeFactor: appearance.textSizeFactor,
              contrastLevel: appearance.contrastLevel,
              surfaceTone: appearance.surfaceTone,
            )
          : BandPlanTheme.dark(
              accentColor: appearance.accentColor,
              cornerRadius: appearance.cornerRadius,
              cardCornerRadius: appearance.cardCornerRadius,
              buttonCornerRadius: appearance.buttonCornerRadius,
              fieldCornerRadius: appearance.fieldCornerRadius,
              visualDensity: appearance.visualDensity,
              depthElevation: appearance.depthElevation,
              fontSizeFactor: appearance.textSizeFactor,
              contrastLevel: appearance.contrastLevel,
              surfaceTone: appearance.surfaceTone,
            ),
      themeMode: appearance.materialThemeMode,
      routerConfig: bandPlanRouter,
    );
  }
}
