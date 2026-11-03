import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/bandplan_app.dart';
import 'core/supabase/supabase_bootstrap.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // WHY: Render a visible startup state before Supabase initializes. If its
  // local auth/session initialization fails, the app must not remain blank.
  runApp(const ProviderScope(child: _BandPlanBootstrap()));
}

class _BandPlanBootstrap extends StatefulWidget {
  const _BandPlanBootstrap();

  @override
  State<_BandPlanBootstrap> createState() => _BandPlanBootstrapState();
}

class _BandPlanBootstrapState extends State<_BandPlanBootstrap> {
  bool _isReady = false;
  bool _isInitializing = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    if (_isInitializing && !_hasError && !_isReady && mounted) {
      // Initial startup is already in progress.
    } else {
      setState(() {
        _isInitializing = true;
        _hasError = false;
      });
    }

    try {
      await SupabaseBootstrap.initialize();
      if (!mounted) return;
      setState(() {
        _isReady = true;
        _isInitializing = false;
        _hasError = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isReady) return const BandPlanApp();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF101426),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1554FF),
          brightness: Brightness.dark,
        ),
      ),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: _hasError
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.cloud_off_rounded,
                          size: 42,
                          color: Color(0xFF9AA7C7),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Не удалось запустить BandPlan',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Не удалось подготовить локальную сессию. '
                          'Проверьте подключение и попробуйте ещё раз.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFFB6BED2)),
                        ),
                        const SizedBox(height: 22),
                        FilledButton.icon(
                          onPressed: _isInitializing ? null : _initialize,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Повторить'),
                        ),
                      ],
                    )
                  : const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 30,
                          height: 30,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                        SizedBox(height: 18),
                        Text(
                          'Запускаем BandPlan…',
                          style: TextStyle(
                            color: Color(0xFFE8ECF8),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
