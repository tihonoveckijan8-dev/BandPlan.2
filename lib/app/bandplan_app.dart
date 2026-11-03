import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/local/offline_cache_warmup.dart';
import '../core/local/offline_providers.dart';
import '../core/supabase/supabase_bootstrap.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    if (state == AppLifecycleState.resumed) _sync();
  }

  Future<void> _sync() async {
    if (!mounted || !SupabaseBootstrap.isInitialized) return;
    try {
      final engine = await ref.read(offlineSyncEngineProvider.future);
      await engine.syncPending();
      ref.invalidate(offlineQueueStatusProvider);
    } catch (_) {
      // WHY: network failure must never block startup, navigation, or resume.
    }
  }

  Future<void> _warmOfflineCache() async {
    if (!mounted || !SupabaseBootstrap.isInitialized) return;
    try {
      final store = await ref.read(offlineStoreProvider.future);
      await OfflineCacheWarmup.run(
        client: Supabase.instance.client,
        store: store,
      );
    } catch (_) {
      // WHY: Cache warmup is best-effort and must never delay or block the UI.
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'BandPlan',
        debugShowCheckedModeBanner: false,
        theme: BandPlanTheme.light(),
        darkTheme: BandPlanTheme.dark(),
        themeMode: ThemeMode.system,
        routerConfig: bandPlanRouter,
      );
}
