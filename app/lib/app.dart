import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/auth_screen.dart';
import 'screens/full_read_screen.dart';
import 'screens/home_screen.dart';
import 'screens/learn_screen.dart';
import 'screens/main_shell.dart';
import 'screens/profile_screen.dart';
import 'screens/progress_screen.dart';
import 'screens/quiz_screen.dart';
import 'screens/read_repeat_screen.dart';
import 'screens/reading_screen.dart';
import 'screens/result_screen.dart';
import 'theme/app_theme.dart';

/// Hace que el router reevalúe la redirección cuando cambia la sesión.
class _AuthRefresh extends ChangeNotifier {
  late final StreamSubscription<AuthState> _sub;
  _AuthRefresh() {
    _sub = Supabase.instance.client.auth.onAuthStateChange
        .listen((_) => notifyListeners());
  }
  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final _routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh();
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loggedIn = Supabase.instance.client.auth.currentSession != null;
      final atLogin = state.matchedLocation == '/login';
      if (!loggedIn) return atLogin ? null : '/login';
      if (atLogin) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const AuthScreen()),
      ShellRoute(
        builder: (_, state, child) =>
            MainShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
          GoRoute(path: '/learn', builder: (_, __) => const LearnScreen()),
          GoRoute(
              path: '/progress', builder: (_, __) => const ProgressScreen()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
        ],
      ),
      GoRoute(
        path: '/lesson/:id',
        builder: (_, s) => ReadingScreen(lessonId: s.pathParameters['id']!),
        routes: [
          GoRoute(
              path: 'practice',
              builder: (_, s) =>
                  ReadRepeatScreen(lessonId: s.pathParameters['id']!)),
          GoRoute(
              path: 'full',
              builder: (_, s) =>
                  FullReadScreen(lessonId: s.pathParameters['id']!)),
          GoRoute(
              path: 'quiz',
              builder: (_, s) =>
                  QuizScreen(lessonId: s.pathParameters['id']!)),
          GoRoute(
              path: 'result',
              builder: (_, s) => ResultScreen(
                  result: (s.extra as Map<String, dynamic>?) ?? const {})),
        ],
      ),
    ],
  );
});

class SpeakReadApp extends ConsumerWidget {
  const SpeakReadApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'SpeakRead Pro',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      routerConfig: ref.watch(_routerProvider),
    );
  }
}
