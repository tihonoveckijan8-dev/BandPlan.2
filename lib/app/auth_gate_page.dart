import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/config/app_config.dart';
import '../features/auth/application/auth_providers.dart';
import '../features/auth/presentation/auth_page.dart';
import '../features/onboarding/application/onboarding_providers.dart';
import '../features/onboarding/presentation/onboarding_page.dart';

class AuthGatePage extends ConsumerWidget {
  const AuthGatePage({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(authRepositoryProvider);
    if (!AppConfig.hasSupabaseConfig || repository == null) {
      return const _ConfigurationRequiredPage();
    }

    ref.watch(authStateProvider);
    if (repository.currentSession == null) return const AuthPage();

    final onboarding = ref.watch(onboardingCompleteProvider);
    return onboarding.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Не удалось проверить профиль аккаунта.'),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => ref.invalidate(onboardingCompleteProvider),
                  child: const Text('Повторить'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (complete) => complete
          ? Scaffold(
              body: navigationShell,
              bottomNavigationBar: LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = MediaQuery.sizeOf(context).width < 700;
                  if (isMobile) {
                    return _TelegramStyleNavigationBar(shell: navigationShell);
                  }

                  return SafeArea(
                    top: false,
                    child: NavigationBar(
                      selectedIndex: navigationShell.currentIndex,
                      onDestinationSelected: (index) {
                        navigationShell.goBranch(
                          index,
                          initialLocation: index == navigationShell.currentIndex,
                        );
                      },
                      destinations: const [
                        NavigationDestination(
                          icon: Icon(Icons.calendar_month_outlined),
                          selectedIcon: Icon(Icons.calendar_month_rounded),
                          label: 'Календарь',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.library_music_outlined),
                          selectedIcon: Icon(Icons.library_music_rounded),
                          label: 'Песни',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.queue_music_outlined),
                          selectedIcon: Icon(Icons.queue_music_rounded),
                          label: 'Сет-листы',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.person_outline_rounded),
                          selectedIcon: Icon(Icons.person_rounded),
                          label: 'Профиль',
                        ),
                      ],
                    ),
                  );
                },
              ),
            )
          : const OnboardingPage(),
    );
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


class _TelegramStyleNavigationBar extends StatelessWidget {
  const _TelegramStyleNavigationBar({required this.shell});

  final StatefulNavigationShell shell;

  static const _items = [
    (Icons.calendar_month_outlined, Icons.calendar_month_rounded, 'Календарь'),
    (Icons.library_music_outlined, Icons.library_music_rounded, 'Песни'),
    (Icons.queue_music_outlined, Icons.queue_music_rounded, 'Сет-листы'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Профиль'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 5, 12, 9),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withOpacity(
                theme.brightness == Brightness.dark ? 0.24 : 0.10,
              ),
              blurRadius: 22,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: colors.onSurface.withOpacity(
                theme.brightness == Brightness.dark ? 0.06 : 0.035,
              ),
              blurRadius: 1,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        child: Row(
          children: List.generate(_items.length, (index) {
            final item = _items[index];
            final selected = shell.currentIndex == index;
            // WHY: the active destination uses the app's primary accent,
            // making the current section immediately recognizable on mobile.
            final foreground = selected
                ? colors.onPrimary
                : colors.onSurfaceVariant;

            return Expanded(
              child: Semantics(
                button: true,
                selected: selected,
                label: item.$3,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => shell.goBranch(
                      index,
                      initialLocation: index == shell.currentIndex,
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      constraints: const BoxConstraints(minHeight: 62),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 3,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: selected ? colors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            transitionBuilder: (child, animation) =>
                                ScaleTransition(
                              scale: animation,
                              child: FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                            ),
                            child: Icon(
                              selected ? item.$2 : item.$1,
                              key: ValueKey(selected),
                              size: selected ? 23 : 22,
                              color: foreground,
                            ),
                          ),
                          const SizedBox(height: 3),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOut,
                            style: theme.textTheme.labelSmall!.copyWith(
                              color: foreground,
                              fontSize: selected ? 11 : 10.5,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                            child: Text(
                              item.$3,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.fade,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
