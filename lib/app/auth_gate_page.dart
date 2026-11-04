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


class _TelegramStyleNavigationBar extends StatefulWidget {
  const _TelegramStyleNavigationBar({required this.shell});

  final StatefulNavigationShell shell;

  @override
  State<_TelegramStyleNavigationBar> createState() =>
      _TelegramStyleNavigationBarState();
}

class _TelegramStyleNavigationBarState
    extends State<_TelegramStyleNavigationBar>
    with SingleTickerProviderStateMixin {
  static const _items = [
    (Icons.calendar_month_outlined, Icons.calendar_month_rounded, 'Календарь'),
    (Icons.library_music_outlined, Icons.library_music_rounded, 'Песни'),
    (Icons.queue_music_outlined, Icons.queue_music_rounded, 'Сет-листы'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Профиль'),
  ];

  late int _activeIndex = widget.shell.currentIndex;
  late final AnimationController _notchController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    value: 1,
  );
  late Animation<double> _notchPosition = AlwaysStoppedAnimation(
    _activeIndex.toDouble(),
  );

  @override
  void didUpdateWidget(covariant _TelegramStyleNavigationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextIndex = widget.shell.currentIndex;
    if (nextIndex == _activeIndex) return;

    final currentPosition = _notchPosition.value;
    _activeIndex = nextIndex;
    _notchPosition = Tween<double>(
      begin: currentPosition,
      end: nextIndex.toDouble(),
    ).animate(CurvedAnimation(
      parent: _notchController,
      curve: Curves.easeInOutCubicEmphasized,
    ));
    _notchController
      ..stop()
      ..value = 0
      ..forward();
  }

  @override
  void dispose() {
    _notchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 14, 12, 7),
      child: SizedBox(
        height: 88,
        child: AnimatedBuilder(
          animation: _notchPosition,
          builder: (context, _) => Stack(
            clipBehavior: Clip.none,
            children: [
              // WHY: The active-tab recess is carved into the panel outline;
              // a wider, deeper shoulder makes the shape visible around the
              // raised button instead of letting the button hide the whole cut.
              Positioned.fill(
                child: CustomPaint(
                  painter: _FloatingNavigationShape(
                    activePosition: _notchPosition.value,
                    fill: colors.surface,
                    outline: colors.onSurface.withOpacity(dark ? 0.16 : 0.09),
                    shadow: colors.shadow.withOpacity(dark ? 0.30 : 0.15),
                    highlight: colors.onSurface.withOpacity(dark ? 0.09 : 0.06),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 26),
                child: Row(
                  children: List.generate(_items.length, (index) {
                    final item = _items[index];
                    final selected = widget.shell.currentIndex == index;
                    return Expanded(
                      child: Semantics(
                        button: true,
                        selected: selected,
                        label: item.$3,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => widget.shell.goBranch(
                            index,
                            initialLocation: index == widget.shell.currentIndex,
                          ),
                          child: SizedBox(
                            height: 88,
                            child: Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.topCenter,
                              children: [
                                AnimatedPositioned(
                                  duration: const Duration(milliseconds: 420),
                                  curve: Curves.easeInOutCubicEmphasized,
                                  top: selected ? 0 : 31,
                                  width: selected ? 58 : 48,
                                  height: selected ? 58 : 48,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 420),
                                    curve: Curves.easeInOutCubicEmphasized,
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? colors.primary
                                          : Colors.transparent,
                                      shape: BoxShape.circle,
                                      boxShadow: selected
                                          ? [
                                              BoxShadow(
                                                color: colors.shadow.withOpacity(
                                                  dark ? 0.32 : 0.18,
                                                ),
                                                blurRadius: 16,
                                                spreadRadius: 1,
                                                offset: const Offset(0, 6),
                                              ),
                                              BoxShadow(
                                                color: colors.onPrimary.withOpacity(0.22),
                                                blurRadius: 3,
                                                offset: const Offset(0, -1),
                                              ),
                                            ]
                                          : const [],
                                    ),
                                    child: Center(
                                      child: AnimatedSwitcher(
                                        duration: const Duration(milliseconds: 260),
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
    const radius = 18.0;
    const notchHalfWidth = 38.0;
    const notchDepth = 38.0;
    final centerX = (26.0 + (size.width - 52.0) *
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
        notchStart + leftSpan * 0.55, top,
        centerX, top + notchDepth * 0.45,
        centerX, top + notchDepth,
      )
      ..cubicTo(
        centerX, top + notchDepth * 0.55,
        notchEnd - rightSpan * 0.55, top,
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
    // WHY: Keep the page movement short and subtle; the expensive tab subtree
    // is isolated so navigation does not animate a large composited surface.
    duration: const Duration(milliseconds: 260),
    value: 1,
  );

  late final Animation<double> _motion = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  late Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0.008, 0),
    end: Offset.zero,
  ).animate(_motion);

  @override
  void didUpdateWidget(covariant _BranchTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      // WHY: A very short, subtle movement avoids the heavy feel of sliding
      // the entire page while still making the tab change perceptible.
      final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      if (reduceMotion) {
        _controller
          ..stop()
          ..value = 1;
        return;
      }
      final direction = widget.currentIndex > oldWidget.currentIndex ? 1.0 : -1.0;
      _slide = Tween<Offset>(
        begin: Offset(direction * 0.008, 0),
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
