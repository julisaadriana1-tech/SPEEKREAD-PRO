import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';

/// Anillo con el puntaje 0–100.
class ScoreRing extends StatelessWidget {
  final num score;
  final double size;
  final String? label;
  const ScoreRing({super.key, required this.score, this.size = 88, this.label});

  @override
  Widget build(BuildContext context) {
    final color = scoreColor(score);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: (score / 100).clamp(0.0, 1.0).toDouble(),
              strokeWidth: size / 11,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${score.round()}',
                style: TextStyle(
                    fontSize: size * 0.3,
                    fontWeight: FontWeight.w700,
                    color: color)),
            if (label != null)
              Text(label!, style: Theme.of(context).textTheme.labelSmall),
          ]),
        ],
      ),
    );
  }
}

/// Indicador pequeño (precisión, fluidez...).
class MetricChip extends StatelessWidget {
  final String label;
  final num? value;
  const MetricChip({super.key, required this.label, this.value});

  @override
  Widget build(BuildContext context) {
    final v = value;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: [
        Text(v == null ? '–' : '${v.round()}',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: v == null ? null : scoreColor(v))),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ]),
    );
  }
}

/// Oración evaluada: cada palabra con color + icono según su puntaje.
/// Tocar una palabra abre el detalle de fonemas.
class ScoredSentence extends StatelessWidget {
  final List<WordScore> words;
  final void Function(WordScore) onWordTap;
  final double fontSize;
  const ScoredSentence(
      {super.key,
      required this.words,
      required this.onWordTap,
      this.fontSize = 20});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 8,
      children: [
        for (final w in words)
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => onWordTap(w),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (w.omitted ? Colors.grey : scoreColor(w.score))
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border(
                  bottom: BorderSide(
                      color: w.omitted ? Colors.grey : scoreColor(w.score),
                      width: 2.5),
                ),
              ),
              child: Text(
                w.word,
                style: readingStyle(context, size: fontSize).copyWith(
                  decoration: w.omitted ? TextDecoration.lineThrough : null,
                  fontStyle: w.inserted ? FontStyle.italic : null,
                  color: w.omitted ? Colors.grey : null,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Hoja inferior con el detalle de una palabra evaluada.
Future<void> showWordScoreSheet(BuildContext context, WordScore w,
    {required VoidCallback onListen}) {
  final weakest = w.weakestPhoneme;
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(w.word,
                  style: Theme.of(ctx)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
            Icon(scoreIcon(w.score), color: scoreColor(w.score)),
            const SizedBox(width: 6),
            Text('${w.score} · ${scoreLabel(w.score)}',
                style: TextStyle(
                    color: scoreColor(w.score), fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 8),
          if (w.omitted)
            const Text('No se escuchó esta palabra. Intentá no saltearla.')
          else if (w.inserted)
            const Text('Esta palabra no está en el texto.')
          else if (weakest != null && weakest.score < 80)
            Text('Sonido a mejorar: /${weakest.phoneme}/',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          if (w.phonemes.isNotEmpty)
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final p in w.phonemes)
                Chip(
                  avatar: Icon(scoreIcon(p.score),
                      size: 16, color: scoreColor(p.score)),
                  label: Text('/${p.phoneme}/  ${p.score}'),
                  side: BorderSide(color: scoreColor(p.score)),
                ),
            ]),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onListen,
            icon: const Icon(Icons.volume_up),
            label: const Text('Escuchar pronunciación correcta'),
          ),
        ],
      ),
    ),
  );
}

/// Botón de micrófono grande. Cambia de color mientras graba.
class MicButton extends StatelessWidget {
  final bool recording;
  final bool busy;
  final VoidCallback? onPressed;
  const MicButton(
      {super.key, required this.recording, this.busy = false, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = recording ? AppColors.bad : scheme.primary;
    return Semantics(
      button: true,
      label: recording ? 'Detener grabación' : 'Grabar',
      child: GestureDetector(
        onTap: busy ? null : onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: color.withValues(alpha: recording ? 0.45 : 0.25),
                  blurRadius: recording ? 24 : 12,
                  spreadRadius: recording ? 6 : 0),
            ],
          ),
          child: busy
              ? const Padding(
                  padding: EdgeInsets.all(28),
                  child: CircularProgressIndicator(
                      strokeWidth: 3, color: Colors.white))
              : Icon(recording ? Icons.stop_rounded : Icons.mic_rounded,
                  size: 40, color: Colors.white),
        ),
      ),
    );
  }
}

/// Muestra un mensaje de error simple.
class ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;
  const ErrorView({super.key, required this.error, this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off, size: 48),
            const SizedBox(height: 12),
            Text('Algo salió mal.\n$error', textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
            ],
          ]),
        ),
      );
}

String contextLabel(String context) => context == 'work' ? 'Trabajo' : 'Vida';
