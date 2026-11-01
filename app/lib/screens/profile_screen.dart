import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static const levels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).valueOrNull;
    final text = Theme.of(context).textTheme;
    if (profile == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Perfil',
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Card(
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.person),
                title: Text(profile.displayName),
                subtitle: Text(profile.jobRole ?? ''),
              ),
              ListTile(
                leading: const Icon(Icons.flag),
                title: const Text('Meta diaria'),
                trailing: Text('${profile.dailyGoalMin} min'),
              ),
              ListTile(
                leading: const Icon(Icons.school),
                title: const Text('Nivel actual'),
                trailing: DropdownButton<String>(
                  value: profile.cefrLevel,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final l in levels)
                      DropdownMenuItem(value: l, child: Text(l)),
                  ],
                  onChanged: (v) async {
                    if (v == null) return;
                    await ref.read(repoProvider).updateLevel(v);
                    ref.invalidate(profileProvider);
                    ref.invalidate(dashboardProvider);
                  },
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => ref.read(repoProvider).signOut(),
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesión'),
          ),
          const SizedBox(height: 24),
          Text(
            'Tus grabaciones de voz se evalúan y se descartan: solo guardamos los puntajes.',
            style: text.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
