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
              body: _BranchTransition(
                currentIndex: navigationShell.currentIndex,
                child: navigationShell,
              ),
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
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 14, 12, 7),
      child: SizedBox(
        height: 88,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(
            begin: shell.currentIndex.toDouble(),
            end: shell.currentIndex.toDouble(),
          ),
          duration: const Duration(milliseconds: 430),
          curve: Curves.easeInOutCubic,
          builder: (context, activePosition, _) => Stack(
            clipBehavior: Clip.none,
            children: [
              // WHY: The notch is part of the panel silhouette, not a button
              // floating over an unchanged capsule. It follows the active tab.
              Positioned.fill(
                child: CustomPaint(
                  painter: _FloatingNavigationShape(
                    activePosition: activePosition,
                    fill: colors.surface,
                    outline: colors.onSurface.withOpacity(dark ? 0.12 : 0.07),
                    shadow: colors.shadow.withOpacity(dark ? 0.30 : 0.13),
                    highlight: colors.onSurface.withOpacity(dark ? 0.07 : 0.045),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: List.generate(_items.length, (index) {
                    final item = _items[index];
                    final selected = shell.currentIndex == index;
                    return Expanded(
                      child: Semantics(
                        button: true,
                        selected: selected,
                        label: item.$3,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => shell.goBranch(
                            index,
                            initialLocation: index == shell.currentIndex,
                          ),
                          child: SizedBox(
                            height: 88,
                            child: Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.topCenter,
                              children: [
                                AnimatedPositioned(
                                  duration: const Duration(milliseconds: 430),
                                  curve: Curves.easeInOutCubic,
                                  top: selected ? 0 : 31,
                                  width: selected ? 58 : 48,
                                  height: selected ? 58 : 48,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 430),
                                    curve: Curves.easeInOutCubic,
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? colors.primary
                                          : Colors.transparent,
                                      shape: BoxShape.circle,
                                      boxShadow: selected
                                          ? [
                                              BoxShadow(
                                                color: colors.shadow.withOpacity(
                                                  dark ? 0.30 : 0.16,
                                                ),
                                                blurRadius: 13,
                                                offset: const Offset(0, 5),
                                              ),
                                              BoxShadow(
                                                color: colors.onPrimary.withOpacity(0.20),
                                                blurRadius: 2,
                                                offset: const Offset(0, -1),
                                              ),
                                            ]
                                          : const [],
                                    ),
                                    child: Center(
                                      child: AnimatedSwitcher(
                                        duration: const Duration(milliseconds: 300),
                                        switchInCurve: Curves.easeOutCubic,
                                        switchOutCurve: Curves.easeInCubic,
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
                                          size: selected ? 29 : 27,
                                          color: selected
                                              ? colors.onPrimary
                                              : colors.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              // WHY: A restrained inset mark anchors the floating panel visually
              // without imitating the operating system's gesture area.
              Positioned(
                left: 0,
                right: 0,
                bottom: 7,
                child: Center(
                  child: Container(
                    width: 30,
                    height: 3,
                    decoration: BoxDecoration(
                      color: colors.onSurface.withOpacity(dark ? 0.22 : 0.16),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FloatingNavigationShape extends CustomPainter {
  const _FloatingNavigationShape({
    required this.activePosition,
    required this.fill,
    required this.outline,
    required this.shadow,
    required this.highlight,
  });

  final double activePosition;
  final Color fill;
  final Color outline;
  final Color shadow;
  final Color highlight;

  @override
  void paint(Canvas canvas, Size size) {
    const top = 18.0;
    const radius = 35.0;
    const notchHalfWidth = 36.0;
    const notchDepth = 27.0;
    final centerX = (8.0 + (size.width - 16.0) *
            ((activePosition.clamp(0.0, 3.0) + 0.5) / 4.0))
        .toDouble();
    final notchStart =
        (centerX - notchHalfWidth).clamp(radius, size.width - radius).toDouble();
    final notchEnd =
        (centerX + notchHalfWidth).clamp(radius, size.width - radius).toDouble();
    final leftSpan = centerX - notchStart;
    final rightSpan = notchEnd - centerX;

    final path = Path()
      ..moveTo(radius, top)
      ..lineTo(notchStart, top)
      ..cubicTo(
        notchStart + leftSpan * 0.35, top,
        centerX - leftSpan * 0.65, top + notchDepth,
        centerX, top + notchDepth,
      )
      ..cubicTo(
        centerX + rightSpan * 0.65, top + notchDepth,
        notchEnd - rightSpan * 0.35, top,
        notchEnd, top,
      )
      ..lineTo(size.width - radius, top)
      ..quadraticBezierTo(size.width, top, size.width, top + radius)
      ..lineTo(size.width, size.height - radius)
      ..quadraticBezierTo(size.width, size.height, size.width - radius, size.height)
      ..lineTo(radius, size.height)
      ..quadraticBezierTo(0, size.height, 0, size.height - radius)
      ..lineTo(0, top + radius)
      ..quadraticBezierTo(0, top, radius, top)
      ..close();

    canvas.drawShadow(path, shadow, 18, true);
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = outline,
    );

    final topHighlight = Path()
      ..moveTo(radius + 8, top + 1)
      ..lineTo(notchStart - 5, top + 1);
    canvas.drawPath(
      topHighlight,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round
        ..color = highlight,
    );
  }

  @override
  bool shouldRepaint(covariant _FloatingNavigationShape oldDelegate) =>
      oldDelegate.activePosition != activePosition ||
      oldDelegate.fill != fill ||
      oldDelegate.outline != outline ||
      oldDelegate.shadow != shadow ||
      oldDelegate.highlight != highlight;
}

// WHY: Keep the indexed branch navigators alive while animating the visible
// content, so switching tabs does not reset each tab's scroll or route state.
class _BranchTransition extends StatefulWidget {
  const _BranchTransition({
    required this.currentIndex,
    required this.child,
  });

  final int currentIndex;
  final Widget child;

  @override
  State<_BranchTransition> createState() => _BranchTransitionState();
}

class _BranchTransitionState extends State<_BranchTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    // WHY: A slightly longer ease-in/ease-out gives the movement a natural
    // acceleration and deceleration instead of a mechanical snap.
    duration: const Duration(milliseconds: 430),
    value: 1,
  );

  late final Animation<double> _motion = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOutCubic,
  );

  late Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0.02, 0),
    end: Offset.zero,
  ).animate(_motion);

  @override
  void didUpdateWidget(covariant _BranchTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      // WHY: A restrained horizontal travel with symmetric easing feels like
      // one continuous gesture, while avoiding the floating-page effect.
      final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      if (reduceMotion) {
        _controller
          ..stop()
          ..value = 1;
        return;
      }
      final direction = widget.currentIndex > oldWidget.currentIndex ? 1.0 : -1.0;
      _slide = Tween<Offset>(
        begin: Offset(direction * 0.02, 0),
        end: Offset.zero,
      ).animate(_motion);
      _controller
        ..stop()
        ..value = 0
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SlideTransition(
        position: _slide,
        // WHY: Isolate the complex tab navigator from the moving parent.
        // Removing the opacity animation also avoids an unnecessary full-page
        // compositing pass on every frame, reducing visual stutter on phones.
        child: RepaintBoundary(child: widget.child),
      );
}
