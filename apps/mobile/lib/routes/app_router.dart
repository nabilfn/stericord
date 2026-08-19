import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:stericord_mobile/core/theme/app_theme.dart';
import 'package:stericord_mobile/features/auth/auth_controller.dart';
import 'package:stericord_mobile/features/auth/login_page.dart';
import 'package:stericord_mobile/features/dashboard/dashboard_page.dart';

GoRouter buildRouter(AuthController authController) {
  return GoRouter(
    refreshListenable: authController,
    initialLocation: '/dashboard',
    redirect: (context, state) {
      final authenticated = authController.status == AuthStatus.authenticated;
      final onLogin = state.matchedLocation == '/login';

      if (authController.status == AuthStatus.unknown) return null;
      if (!authenticated && !onLogin) return '/login';
      if (authenticated && onLogin) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(path: '/dashboard', builder: (context, state) => const DashboardPage()),
    ],
  );
}

class AppRouterScope extends StatefulWidget {
  const AppRouterScope({super.key});

  @override
  State<AppRouterScope> createState() => _AppRouterScopeState();
}

class _AppRouterScopeState extends State<AppRouterScope> {
  late final GoRouter _router = buildRouter(context.read<AuthController>());

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SteriCord',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: _router,
    );
  }
}
