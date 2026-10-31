import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'auth_gate_page.dart';

final GoRouter bandPlanRouter = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const AuthGatePage(),
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
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
