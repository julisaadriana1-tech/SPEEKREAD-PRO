import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).valueOrNull;
    final dash = ref.watch(dashboardProvider);
    final lessons = ref.watch(lessonsProvider);
    final completed = ref.watch(completedLessonsProvider);
    final text = Theme.of(context).textTheme;

    Future<void> refresh() async {
      ref.invalidate(dashboardProvider);
      ref.invalidate(lessonsProvider);
      ref.invalidate(completedLessonsProvider);
    }

    if (dash.hasError) {
      return ErrorView(error: dash.error!, onRetry: refresh);
    }
    final d = dash.valueOrNull;
    final today = (profile != null && lessons.hasValue && completed.hasValue)
        ? pickTodayLesson(lessons.value!, completed.value!, profile)
        : null;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Row(children: [
              Expanded(
                child: Text('Hola, ${profile?.displayName ?? ''}',
                    style: text.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ),
              _Pill(
                  icon: Icons.local_fire_department,
                  color: AppColors.accent,
                  label: '${d?['current_streak'] ?? 0}'),
              const SizedBox(width: 8),
              _Pill(
                  icon: Icons.bolt,
                  color: AppColors.primary,
                  label: '${d?['xp_total'] ?? 0} XP'),
            ]),
            const SizedBox(height: 4),
            Text(
              d?['studied_today'] == true
                  ? '¡Ya estudiaste hoy! Tu racha está a salvo.'
                  : 'Tu meta de hoy: ${profile?.dailyGoalMin ?? 10} minutos.',
              style: text.bodyMedium,
            ),
            const SizedBox(height: 20),
            if (today == null && (lessons.isLoading || completed.isLoading))
              const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()))
            else if (today == null)
              const Card(
                  child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                          'Todavía no hay lecciones publicadas. Cargá seed.sql en Supabase.')))
            else
              _TodayCard(lesson: today),
            const SizedBox(height: 16),
            if (d?['challenge'] is Map)
              _ChallengeCard(
                  challenge: Map<String, dynamic>.from(d!['challenge'] as Map)),
            const SizedBox(height: 16),
            if (d != null)
              Row(children: [
                Expanded(
                    child: _StatTile(
                        label: 'Pronunciación',
                        value: d['avg_pron_30d'] == null
                            ? '–'
                            : '${d['avg_pron_30d']}')),
                const SizedBox(width: 12),
                Expanded(
                    child: _StatTile(
                        label: 'Palabras', value: '${d['words_learned']}')),
                const SizedBox(width: 12),
                Expanded(
                    child: _StatTile(
                        label: 'Nivel', value: '${d['cefr_level']}')),
              ]),
          ],
        ),
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  final Lesson lesson;
  const _TodayCard({required this.lesson});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card(
      color: AppColors.primary,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('LECCIÓN DE HOY',
                style: text.labelMedium?.copyWith(
                    color: Colors.white70, letterSpacing: 1.2)),
            const SizedBox(height: 8),
            Text(lesson.title,
                style: text.titleLarge?.copyWith(
                    color: Colors.white, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
                '${lesson.cefrLevel} · ${contextLabel(lesson.context)} · ${lesson.estMinutes} min',
                style: text.bodyMedium?.copyWith(color: Colors.white70)),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: scheme.onSecondary),
              onPressed: () => context.push('/lesson/${lesson.id}'),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Empezar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  final Map<String, dynamic> challenge;
  const _ChallengeCard({required this.challenge});

  @override
  Widget build(BuildContext context) {
    final target = (challenge['target'] as num?)?.toInt() ?? 1;
    final progress = (challenge['progress'] as num?)?.toInt() ?? 0;
    final done = challenge['completed'] == true;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Icon(done ? Icons.emoji_events : Icons.flag_outlined,
              color: AppColors.accent, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Desafío diario · +${challenge['xp_reward']} XP',
                    style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 2),
                Text('${challenge['title']}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: (progress / target).clamp(0.0, 1.0),
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(done ? '¡Listo!' : '$progress/$target'),
        ]),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _Pill({required this.icon, required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
      );
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(children: [
            Text(value,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ]),
        ),
      );
}
