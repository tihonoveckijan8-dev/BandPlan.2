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
          ? _AdaptiveAppShell(navigationShell: navigationShell)
          : const OnboardingPage(),
    );
  }
}

/// WHY: Large screens need persistent navigation and a wider working
/// canvas; keeping the same branch navigator preserves tab state on every size.
class _AdaptiveAppShell extends StatelessWidget {
  const _AdaptiveAppShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _destinations = <NavigationRailDestination>[
    NavigationRailDestination(
      icon: Icon(Icons.calendar_month_outlined),
      selectedIcon: Icon(Icons.calendar_month_rounded),
      label: Text('Календарь'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.library_music_outlined),
      selectedIcon: Icon(Icons.library_music_rounded),
      label: Text('Песни'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.queue_music_outlined),
      selectedIcon: Icon(Icons.queue_music_rounded),
      label: Text('Сет-листы'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.build_outlined),
      selectedIcon: Icon(Icons.build_rounded),
      label: Text('Инструменты'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.person_outline_rounded),
      selectedIcon: Icon(Icons.person_rounded),
      label: Text('Профиль'),
    ),
  ];

  void _select(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final isMobile = width < 700;
        // WHY: A tablet in landscape should keep the familiar phone-style
        // bottom panel; the side rail consumes too much of its shorter canvas.
        final isTabletLandscape =
            width >= 700 && width < 1100 && width > height;
        final useBottomNavigation = isMobile || isTabletLandscape;
        // WHY: Keep the tablet-landscape bottom bar as the winning layout.
        // A 900–1099px tablet must not also match the desktop-sidebar branch.
        final isDesktop = width >= 1100;
        final colors = Theme.of(context).colorScheme;

        return Scaffold(
          body: Row(
            children: [
              if (isDesktop)
                _DesktopSidebar(
                  selectedIndex: navigationShell.currentIndex,
                  onSelect: _select,
                )
              else if (!useBottomNavigation && !isDesktop)
                SafeArea(
                  right: false,
                  child: Container(
                    width: 88,
                    color: colors.surface,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 16,
                    ),
                    child: NavigationRail(
                      backgroundColor: Colors.transparent,
                      selectedIndex: navigationShell.currentIndex,
                      onDestinationSelected: _select,
                      minWidth: 76,
                      groupAlignment: -0.72,
                      labelType: NavigationRailLabelType.selected,
                      useIndicator: true,
                      destinations: _destinations,
                    ),
                  ),
                ),
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1680),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 20 : (useBottomNavigation ? 0 : 10),
                      ),
                      child: RepaintBoundary(child: navigationShell),
                    ),
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: useBottomNavigation
              ? _TelegramStyleNavigationBar(shell: navigationShell)
              : null,
        );
      },
    );
  }
}

/// WHY: Desktop gets a true fixed-width sidebar (not a floating rail),
/// keeping every destination visible and easy to target with a mouse.
class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({
    required this.selectedIndex,
    required this.onSelect,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  static const _items = <(IconData, IconData, String)>[
    (Icons.calendar_month_outlined, Icons.calendar_month_rounded, 'Календарь'),
    (Icons.library_music_outlined, Icons.library_music_rounded, 'Песни'),
    (Icons.queue_music_outlined, Icons.queue_music_rounded, 'Сет-листы'),
    (Icons.build_outlined, Icons.build_rounded, 'Инструменты'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Профиль'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SafeArea(
      right: false,
      child: Container(
        width: 264,
        height: double.infinity,
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          border: Border(
            right: BorderSide(color: colors.outlineVariant.withOpacity(0.28)),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 34),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      Icons.graphic_eq_rounded,
                      color: colors.onPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'BandPlan',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
              child: Text(
                'РАБОЧЕЕ ПРОСТРАНСТВО',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  letterSpacing: 1.15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (var i = 0; i < _items.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _DesktopSidebarItem(
                  icon: _items[i].$1,
                  selectedIcon: _items[i].$2,
                  label: _items[i].$3,
                  selected: selectedIndex == i,
                  onTap: () => onSelect(i),
                ),
              ),
            const Spacer(),
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surfaceContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.music_note_rounded,
                      color: colors.onSurfaceVariant, size: 20),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Music Group OS',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopSidebarItem extends StatelessWidget {
  const _DesktopSidebarItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Material(
      color: selected ? colors.primary.withOpacity(0.16) : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        hoverColor: colors.primary.withOpacity(0.07),
        child: SizedBox(
          height: 48,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13),
            child: Row(
              children: [
                Icon(
                  selected ? selectedIcon : icon,
                  size: 21,
                  color: selected
                      ? colors.primary
                      : colors.onSurfaceVariant,
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: selected
                          ? colors.primary
                          : colors.onSurface,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (selected)
                  Icon(
                    Icons.circle,
                    size: 7,
                    color: colors.primary,
                  ),
              ],
            ),
          ),
        ),
      ),
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
    (Icons.build_outlined, Icons.build_rounded, 'Инструменты'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Профиль'),
  ];

  late int _activeIndex = widget.shell.currentIndex;
  late final AnimationController _notchController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
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
      curve: Curves.easeInOutCubic,
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
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: List.generate(_items.length, (index) {
                    final item = _items[index];
                    final semanticallySelected =
                        widget.shell.currentIndex == index;
                    // WHY: Derive every button's motion from the same animated
                    // position as the recess. This prevents the icon, button,
                    // and carved panel from drifting out of sync.
                    final distance = (_notchPosition.value - index).abs();
                    final rawProgress =
                        (1.0 - distance).clamp(0.0, 1.0).toDouble();
                    final progress =
                        Curves.easeInOutCubic.transform(rawProgress);
                    final diameter = 48.0 + 10.0 * progress;
                    final top = 31.0 * (1.0 - progress);
                    final iconSize = 27.0 + 2.0 * progress;
                    final buttonColor =
                        Color.lerp(Colors.transparent, colors.primary, progress)!;
                    final inactiveIconColor = Color.lerp(
                      colors.onSurfaceVariant,
                      colors.onPrimary,
                      progress,
                    )!;
                    return Expanded(
                      child: Semantics(
                        button: true,
                        selected: semanticallySelected,
                        label: item.$3,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => widget.shell.goBranch(
                            index,
                            initialLocation:
                                index == widget.shell.currentIndex,
                          ),
                          child: SizedBox(
                            height: 88,
                            child: Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.topCenter,
                              children: [
                                Positioned(
                                  top: top,
                                  width: diameter,
                                  height: diameter,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: buttonColor,
                                      shape: BoxShape.circle,
                                      boxShadow: progress > 0.01
                                          ? [
                                              BoxShadow(
                                                color: colors.shadow.withOpacity(
                                                  (dark ? 0.32 : 0.18) * progress,
                                                ),
                                                blurRadius: 16 * progress,
                                                spreadRadius: progress,
                                                offset: Offset(0, 6 * progress),
                                              ),
                                              BoxShadow(
                                                color: colors.onPrimary.withOpacity(
                                                  0.22 * progress,
                                                ),
                                                blurRadius: 3 * progress,
                                                offset: Offset(0, -progress),
                                              ),
                                            ]
                                          : const [],
                                    ),
                                    child: Center(
                                      child: SizedBox(
                                        width: iconSize,
                                        height: iconSize,
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            Opacity(
                                              opacity: 1.0 - progress,
                                              child: Icon(
                                                item.$1,
                                                size: iconSize,
                                                color: inactiveIconColor,
                                              ),
                                            ),
                                            Opacity(
                                              opacity: progress,
                                              child: Icon(
                                                item.$2,
                                                size: iconSize,
                                                color: colors.onPrimary,
                                              ),
                                            ),
                                          ],
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
    const notchHalfWidth = 40.0;
    const notchDepth = 40.0;
    final centerX = (18.0 + (size.width - 36.0) *
            ((activePosition.clamp(0.0, 4.0) + 0.5) / 5.0))
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
        notchStart + leftSpan * 0.42, top,
        centerX - leftSpan * 0.42, top + notchDepth,
        centerX, top + notchDepth,
      )
      ..cubicTo(
        centerX + rightSpan * 0.42, top + notchDepth,
        notchEnd - rightSpan * 0.42, top,
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

// WHY: Keep branch navigators alive without translating the entire page.
// The tab indicator and notch carry the motion; avoiding a full-screen slide
// prevents an unnecessary compositing pass on lower-powered phones.
class _BranchTransition extends StatelessWidget {
  const _BranchTransition({
    required this.currentIndex,
    required this.child,
  });

  final int currentIndex;
  final Widget child;

  @override
  Widget build(BuildContext context) => RepaintBoundary(child: child);
}
