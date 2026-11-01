import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Camino de aprendizaje: lecciones por nivel CEFR.
class LearnScreen extends ConsumerWidget {
  const LearnScreen({super.key});

  static const levels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessons = ref.watch(lessonsProvider);
    final completed = ref.watch(completedLessonsProvider).valueOrNull ?? {};
    final current = ref.watch(profileProvider).valueOrNull?.cefrLevel ?? 'A1';

    return DefaultTabController(
      length: levels.length,
      initialIndex: levels.indexOf(current).clamp(0, levels.length - 1),
      child: SafeArea(
        child: Column(children: [
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [for (final l in levels) Tab(text: l)],
          ),
          Expanded(
            child: lessons.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorView(
                  error: e, onRetry: () => ref.invalidate(lessonsProvider)),
              data: (all) => TabBarView(children: [
                for (final level in levels)
                  Builder(builder: (context) {
                    final items =
                        all.where((l) => l.cefrLevel == level).toList();
                    if (items.isEmpty) {
                      return const Center(
                          child: Text('Próximamente: lecciones de este nivel.'));
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final l = items[i];
                        final done = completed.contains(l.id);
                        return Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            leading: CircleAvatar(
                              backgroundColor: done
                                  ? AppColors.good.withValues(alpha: 0.15)
                                  : Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                              child: Icon(
                                  done
                                      ? Icons.check
                                      : (l.isWork
                                          ? Icons.work_outline
                                          : Icons.home_outlined),
                                  color: done ? AppColors.good : null),
                            ),
                            title: Text(l.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(
                                'Unidad ${l.unit} · ${contextLabel(l.context)} · ${l.estMinutes} min'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.push('/lesson/${l.id}'),
                          ),
                        );
                      },
                    );
                  }),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
