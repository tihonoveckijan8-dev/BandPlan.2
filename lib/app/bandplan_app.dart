import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
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
    } catch (_) {
      // WHY: network failure must never block startup, navigation, or resume.
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
