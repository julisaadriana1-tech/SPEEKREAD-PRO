import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Paso 5: resultado de la lección (XP, puntajes, racha, insignias).
class ResultScreen extends ConsumerWidget {
  final Map<String, dynamic> result;
  const ResultScreen({super.key, required this.result});

  static const _badgeNames = {
    'first_words': 'First Words',
    'on_track': 'On Track',
    'quarter_close': 'Quarter Close',
    'perfect_read': 'Perfect Read',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final xp = result['xp_earned'] ?? 0;
    final pron = result['pron_score'] as num?;
    final quiz = result['quiz_score'] as num?;
    final streak = result['streak'] ?? 0;
    final badges = ((result['new_badges'] as List?) ?? const []).cast<String>();

    void goHome() {
      ref.invalidate(dashboardProvider);
      ref.invalidate(completedLessonsProvider);
      ref.invalidate(lessonsProvider);
      context.go('/');
    }

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 24),
            const Icon(Icons.emoji_events, size: 72, color: AppColors.accent),
            const SizedBox(height: 12),
            Text('¡Lección completada!',
                textAlign: TextAlign.center,
                style:
                    text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('+$xp XP',
                textAlign: TextAlign.center,
                style: text.headlineMedium?.copyWith(
                    color: AppColors.accent, fontWeight: FontWeight.w800)),
            const SizedBox(height: 28),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              Column(children: [
                pron == null
                    ? const SizedBox(
                        height: 88, child: Center(child: Text('–')))
                    : ScoreRing(score: pron),
                const SizedBox(height: 8),
                const Text('Pronunciación'),
              ]),
              Column(children: [
                quiz == null
                    ? const SizedBox(
                        height: 88, child: Center(child: Text('–')))
                    : ScoreRing(score: quiz),
                const SizedBox(height: 8),
                Text(
                    'Comprensión ${result['quiz_correct'] ?? 0}/${result['quiz_total'] ?? 0}'),
              ]),
            ]),
            const SizedBox(height: 28),
            Card(
              child: ListTile(
                leading: const Icon(Icons.local_fire_department,
                    color: AppColors.accent),
                title: Text('Racha: $streak ${streak == 1 ? 'día' : 'días'}'),
                subtitle: const Text('Volvé mañana para mantenerla.'),
              ),
            ),
            if (result['challenge_completed'] == true) ...[
              const SizedBox(height: 10),
              const Card(
                child: ListTile(
                  leading: Icon(Icons.flag, color: AppColors.good),
                  title: Text('¡Desafío diario cumplido!'),
                ),
              ),
            ],
            for (final b in badges) ...[
              const SizedBox(height: 10),
              Card(
                child: ListTile(
                  leading:
                      const Icon(Icons.military_tech, color: AppColors.accent),
                  title: Text('Nueva insignia: ${_badgeNames[b] ?? b}'),
                ),
              ),
            ],
            const SizedBox(height: 32),
            FilledButton(onPressed: goHome, child: const Text('Volver al inicio')),
          ],
        ),
      ),
    );
  }
}
