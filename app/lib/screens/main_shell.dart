import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers.dart';
import '../widgets/common.dart';
import 'onboarding_screen.dart';

/// Barra de navegación inferior. Si el perfil no completó el onboarding,
/// lo muestra antes que cualquier otra pantalla.
class MainShell extends ConsumerWidget {
  final String location;
  final Widget child;
  const MainShell({super.key, required this.location, required this.child});

  static const _tabs = ['/', '/learn', '/progress', '/profile'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    return profile.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
          body: ErrorView(
              error: e, onRetry: () => ref.invalidate(profileProvider))),
      data: (p) {
        if (p != null && !p.onboarded) return const OnboardingScreen();
        final index = _tabs.indexOf(location).clamp(0, _tabs.length - 1);
        return Scaffold(
          body: child,
          bottomNavigationBar: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (i) => context.go(_tabs[i]),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Inicio'),
              NavigationDestination(
                  icon: Icon(Icons.menu_book_outlined),
                  selectedIcon: Icon(Icons.menu_book),
                  label: 'Aprender'),
              NavigationDestination(
                  icon: Icon(Icons.insights_outlined),
                  selectedIcon: Icon(Icons.insights),
                  label: 'Progreso'),
              NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Perfil'),
            ],
          ),
        );
      },
    );
  }
}
