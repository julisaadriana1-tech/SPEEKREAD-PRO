import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Dashboard personal: nivel, avance, palabras, pronunciación, tiempo,
/// racha, insignias e historial.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dash = ref.watch(dashboardProvider);
    final text = Theme.of(context).textTheme;

    return SafeArea(
      child: dash.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            ErrorView(error: e, onRetry: () => ref.invalidate(dashboardProvider)),
        data: (d) {
          final total = (d['lessons_total_in_level'] as num?)?.toInt() ?? 0;
          final done = (d['lessons_done_in_level'] as num?)?.toInt() ?? 0;
          final pct = total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0);
          final player = PlayerLevel.fromXp((d['xp_total'] as num?)?.toInt() ?? 0);
          final recent = ((d['recent'] as List?) ?? const [])
              .cast<Map<String, dynamic>>();
          final badges = ((d['badges'] as List?) ?? const [])
              .cast<Map<String, dynamic>>();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(dashboardProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Tu progreso',
                    style: text.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text('Nivel ${d['cefr_level']}',
                              style: text.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                          const Spacer(),
                          Text('${(pct * 100).round()}%',
                              style: text.titleLarge?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800)),
                        ]),
                        const SizedBox(height: 10),
                        LinearProgressIndicator(
                            value: pct,
                            minHeight: 10,
                            borderRadius: BorderRadius.circular(6)),
                        const SizedBox(height: 8),
                        Text('$done de $total lecciones del nivel'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(children: [
                      const Icon(Icons.bolt, color: AppColors.accent, size: 36),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Nivel ${player.level} · ${player.name}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 16)),
                            const SizedBox(height: 6),
                            LinearProgressIndicator(
                                value: player.progress,
                                color: AppColors.accent,
                                borderRadius: BorderRadius.circular(4)),
                            const SizedBox(height: 4),
                            Text('${player.xp} / ${player.nextThreshold} XP'),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.6,
                  children: [
                    _Metric(
                        icon: Icons.record_voice_over,
                        label: 'Pronunciación promedio',
                        value: d['avg_pron_30d'] == null
                            ? '–'
                            : '${d['avg_pron_30d']}',
                        color: d['avg_pron_30d'] == null
                            ? null
                            : scoreColor(d['avg_pron_30d'] as num)),
                    _Metric(
                        icon: Icons.menu_book,
                        label: 'Palabras aprendidas',
                        value: '${d['words_learned']}',
                        hint: '${d['words_mastered']} dominadas'),
                    _Metric(
                        icon: Icons.schedule,
                        label: 'Tiempo de estudio',
                        value: '${d['minutes_total']} min'),
                    _Metric(
                        icon: Icons.local_fire_department,
                        label: 'Racha',
                        value: '${d['current_streak']} días',
                        hint: 'Récord: ${d['longest_streak']}',
                        color: AppColors.accent),
                  ],
                ),
                const SizedBox(height: 24),
                Text('Insignias',
                    style: text.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final b in badges)
                    Tooltip(
                      message: '${b['description']}',
                      child: Chip(
                        avatar: Icon(
                            b['earned'] == true
                                ? Icons.military_tech
                                : Icons.lock_outline,
                            size: 18,
                            color: b['earned'] == true
                                ? AppColors.accent
                                : Colors.grey),
                        label: Text('${b['name']}'),
                      ),
                    ),
                ]),
                const SizedBox(height: 24),
                Text('Historial',
                    style: text.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                if (recent.isEmpty)
                  const Text('Todavía no completaste lecciones.')
                else
                  for (final r in recent)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text('${r['title']}'),
                        subtitle: Text(
                            '${r['cefr_level']} · ${_date(r['completed_at'])} · +${r['xp_earned']} XP'),
                        trailing: r['pron_score'] == null
                            ? null
                            : ScoreRing(
                                score: r['pron_score'] as num, size: 40),
                        onTap: () => context.push('/lesson/${r['lesson_id']}'),
                      ),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }

  static String _date(dynamic iso) {
    final d = DateTime.tryParse('$iso')?.toLocal();
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
  }
}

class _Metric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? hint;
  final Color? color;
  const _Metric(
      {required this.icon,
      required this.label,
      required this.value,
      this.hint,
      this.color});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 6),
              Text(value,
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800, color: color)),
              Text(hint ?? label,
                  style: Theme.of(context).textTheme.labelSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      );
}
