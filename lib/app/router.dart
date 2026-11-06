import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/profile/presentation/profile_page.dart';
import '../features/songs/presentation/song_library_page.dart';
import '../features/setlists/presentation/setlists_page.dart';
import '../features/events/presentation/calendar_page.dart';
import '../features/tools/presentation/tools_page.dart';
import 'auth_gate_page.dart';

final GoRouter bandPlanRouter = GoRouter(
  initialLocation: '/calendar',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AuthGatePage(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/calendar',
            name: 'calendar',
            builder: (context, state) => const CalendarPage(),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/songs',
            name: 'songs',
            builder: (context, state) => const SongLibraryPage(),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/setlists',
            name: 'setlists',
            builder: (context, state) => const SetlistsPage(),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/tools',
            name: 'tools',
            builder: (context, state) => const ToolsPage(),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/profile',
            name: 'profile',
            builder: (context, state) => const ProfilePage(),
          ),
        ]),
      ],
    ),
  ],
  errorBuilder: (context, state) => _RouteErrorPage(
    message: state.error?.toString() ?? 'Не удалось открыть страницу.',
  ),
);

class _RouteErrorPage extends StatelessWidget {
  const _RouteErrorPage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(message, textAlign: TextAlign.center),
          ),
        ),
      );
}
