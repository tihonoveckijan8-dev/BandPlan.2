import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../features/auth/application/auth_providers.dart';
import '../features/auth/presentation/auth_page.dart';
import '../features/groups/presentation/group_workspace_page.dart';

class AuthGatePage extends ConsumerWidget {
  const AuthGatePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(authRepositoryProvider);
    if (!AppConfig.hasSupabaseConfig || repository == null) {
      return const _ConfigurationRequiredPage();
    }

    ref.watch(authStateProvider);
    if (repository.currentSession == null) return const AuthPage();
    return const GroupWorkspacePage();
  }
}

class _ConfigurationRequiredPage extends StatelessWidget {
  const _ConfigurationRequiredPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.settings_rounded, size: 42),
                  const SizedBox(height: 16),
                  Text(
                    'Нужна настройка Supabase',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Перед запуском передайте SUPABASE_URL и '
                    'SUPABASE_PUBLISHABLE_KEY через --dart-define. '
                    'Секретный service-role ключ здесь не используется.',
                    textAlign: TextAlign.center,
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
