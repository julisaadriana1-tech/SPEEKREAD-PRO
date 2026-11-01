import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers.dart';
import '../services/audio.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Paso 2: Leer y Repetir. Escuchar → grabar → feedback → repetir.
/// Se avanza con puntaje >= 70 o después de 3 intentos.
class ReadRepeatScreen extends ConsumerStatefulWidget {
  final String lessonId;
  const ReadRepeatScreen({super.key, required this.lessonId});
  @override
  ConsumerState<ReadRepeatScreen> createState() => _ReadRepeatScreenState();
}

class _ReadRepeatScreenState extends ConsumerState<ReadRepeatScreen> {
  static const passScore = 70;
  static const maxAttemptsBeforeSkip = 3;

  final VoiceRecorder _recorder = VoiceRecorder();
  late final Speaker _speaker;
  int _index = 0;
  int _attempts = 0;
  bool _recording = false;
  bool _evaluating = false;
  bool _showTranslation = false;
  PronunciationResult? _result;

  @override
  void initState() {
    super.initState();
    _speaker = ref.read(speakerProvider);
  }

  @override
  void dispose() {
    _recorder.dispose();
    _speaker.stop();
    super.dispose();
  }

  Future<void> _toggleRecord(LessonSentence s) async {
    final messenger = ScaffoldMessenger.of(context);
    if (_recording) {
      setState(() {
        _recording = false;
        _evaluating = true;
      });
      final wav = await _recorder.stop();
      if (wav == null) {
        setState(() => _evaluating = false);
        return;
      }
      final result = await ref.read(repoProvider).assessPronunciation(
            wav: wav,
            referenceText: s.textEn,
            lessonId: widget.lessonId,
            sentenceId: s.id,
          );
      if (!mounted) return;
      setState(() {
        _evaluating = false;
        if (result.ok) {
          _attempts++;
          _result = result;
          final session = sessionFor(ref, widget.lessonId);
          final prev = session.bestBySentence[s.id] ?? 0;
          if (result.overall > prev) {
            session.bestBySentence[s.id] = result.overall;
          }
        }
      });
      if (!result.ok) {
        messenger.showSnackBar(SnackBar(content: Text(result.message ?? '')));
      }
      return;
    }

    if (!await _recorder.hasPermission()) {
      messenger.showSnackBar(const SnackBar(
          content: Text(
              'Necesitamos el micrófono para escuchar tu lectura. Activalo en los ajustes del teléfono.')));
      return;
    }
    await _speaker.stop();
    await _recorder.start();
    if (mounted) setState(() => _recording = true);
  }

  void _next(int total) {
    if (_index + 1 >= total) {
      context.pushReplacement('/lesson/${widget.lessonId}/full');
      return;
    }
    setState(() {
      _index++;
      _attempts = 0;
      _result = null;
      _showTranslation = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(lessonDetailProvider(widget.lessonId));
    return Scaffold(
      appBar: AppBar(title: const Text('Leer y Repetir')),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(error: e),
        data: (d) {
          if (d.sentences.isEmpty) {
            return const Center(child: Text('Esta lección no tiene oraciones.'));
          }
          final s = d.sentences[_index];
          final total = d.sentences.length;
          final r = _result;
          final canAdvance = r != null &&
              (r.overall >= passScore || _attempts >= maxAttemptsBeforeSkip);

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: (_index + (canAdvance ? 1 : 0)) / total,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('${_index + 1} / $total'),
                  ]),
                  const SizedBox(height: 24),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r == null
                                ? '1. Escuchá  2. Leé en voz alta  3. Mirá tu resultado'
                                : 'Tocá una palabra para ver qué sonido mejorar',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 16),
                          if (r == null)
                            Text(s.textEn,
                                style: readingStyle(context, size: 24))
                          else
                            ScoredSentence(
                              words: r.words,
                              fontSize: 22,
                              onWordTap: (w) => showWordScoreSheet(context, w,
                                  onListen: () => _speaker.play(text: w.word)),
                            ),
                          const SizedBox(height: 12),
                          if (s.textEs != null)
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero),
                              onPressed: () => setState(
                                  () => _showTranslation = !_showTranslation),
                              icon: const Icon(Icons.translate, size: 18),
                              label: Text(_showTranslation
                                  ? s.textEs!
                                  : 'Ver traducción'),
                            ),
                          if (r != null) ...[
                            const SizedBox(height: 24),
                            Row(children: [
                              ScoreRing(score: r.overall, size: 84),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      Icon(scoreIcon(r.overall),
                                          color: scoreColor(r.overall)),
                                      const SizedBox(width: 6),
                                      Text(scoreLabel(r.overall),
                                          style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 18,
                                              color: scoreColor(r.overall))),
                                    ]),
                                    const SizedBox(height: 4),
                                    Text(r.overall >= passScore
                                        ? '¡Bien! Podés seguir o repetir para mejorar.'
                                        : (_attempts >= maxAttemptsBeforeSkip
                                            ? 'Podés seguir; esta oración volverá en tu repaso.'
                                            : 'Escuchá de nuevo y repetí. Intento $_attempts de $maxAttemptsBeforeSkip.')),
                                  ],
                                ),
                              ),
                            ]),
                            const SizedBox(height: 12),
                            Wrap(spacing: 8, runSpacing: 8, children: [
                              MetricChip(label: 'Precisión', value: r.accuracy),
                              MetricChip(label: 'Fluidez', value: r.fluency),
                              MetricChip(
                                  label: 'Completitud', value: r.completeness),
                              if (r.prosody != null)
                                MetricChip(label: 'Prosodia', value: r.prosody),
                            ]),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _RoundAction(
                        icon: Icons.volume_up_rounded,
                        label: 'Escuchar',
                        onTap: _recording
                            ? null
                            : () => _speaker.play(url: s.audioUrl, text: s.textEn),
                      ),
                      Column(children: [
                        MicButton(
                          recording: _recording,
                          busy: _evaluating,
                          onPressed: () => _toggleRecord(s),
                        ),
                        const SizedBox(height: 6),
                        Text(_recording
                            ? 'Tocá para terminar'
                            : (_evaluating ? 'Evaluando…' : 'Grabar')),
                      ]),
                      _RoundAction(
                        icon: Icons.arrow_forward_rounded,
                        label: _index + 1 >= total ? 'Finalizar' : 'Siguiente',
                        onTap: canAdvance ? () => _next(total) : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _RoundAction({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) => Column(children: [
        IconButton.filledTonal(
            iconSize: 28,
            padding: const EdgeInsets.all(14),
            onPressed: onTap,
            icon: Icon(icon)),
        const SizedBox(height: 6),
        Text(label),
      ]);
}
