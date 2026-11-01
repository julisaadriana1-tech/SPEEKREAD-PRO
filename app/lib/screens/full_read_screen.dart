import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers.dart';
import '../services/audio.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Paso 3: lectura completa en voz alta (hasta 55 segundos).
class FullReadScreen extends ConsumerStatefulWidget {
  final String lessonId;
  const FullReadScreen({super.key, required this.lessonId});
  @override
  ConsumerState<FullReadScreen> createState() => _FullReadScreenState();
}

class _FullReadScreenState extends ConsumerState<FullReadScreen> {
  static const maxSeconds = 55;

  final VoiceRecorder _recorder = VoiceRecorder();
  late final Speaker _speaker;
  Timer? _timer;
  int _seconds = 0;
  bool _recording = false;
  bool _evaluating = false;
  PronunciationResult? _result;

  @override
  void initState() {
    super.initState();
    _speaker = ref.read(speakerProvider);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final messenger = ScaffoldMessenger.of(context);
    if (!await _recorder.hasPermission()) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Activá el permiso de micrófono para continuar.')));
      return;
    }
    await _speaker.stop();
    await _recorder.start();
    setState(() {
      _recording = true;
      _seconds = 0;
      _result = null;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _seconds++);
      if (_seconds >= maxSeconds) _stop();
    });
  }

  Future<void> _stop() async {
    if (!_recording) return;
    _timer?.cancel();
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _recording = false;
      _evaluating = true;
    });
    final wav = await _recorder.stop();
    final detail = ref.read(lessonDetailProvider(widget.lessonId)).value;
    if (wav == null || detail == null) {
      setState(() => _evaluating = false);
      return;
    }
    final result = await ref.read(repoProvider).assessPronunciation(
        wav: wav, referenceText: detail.lesson.bodyEn, lessonId: widget.lessonId);
    if (!mounted) return;
    setState(() {
      _evaluating = false;
      if (result.ok) {
        _result = result;
        sessionFor(ref, widget.lessonId).fullRead = result;
      }
    });
    if (!result.ok) {
      messenger.showSnackBar(SnackBar(content: Text(result.message ?? '')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(lessonDetailProvider(widget.lessonId));
    return Scaffold(
      appBar: AppBar(title: const Text('Lectura completa')),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(error: e),
        data: (d) {
          final r = _result;
          return SafeArea(
            child: Column(children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  children: [
                    Text(
                      r == null
                          ? 'Leé el texto completo de corrido, con calma y sin detenerte.'
                          : 'Tu resultado. Tocá una palabra para ver el detalle.',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 16),
                    if (r == null)
                      Text(d.lesson.bodyEn, style: readingStyle(context))
                    else ...[
                      Row(children: [
                        ScoreRing(score: r.overall, size: 96, label: 'global'),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Wrap(spacing: 8, runSpacing: 8, children: [
                            MetricChip(label: 'Precisión', value: r.accuracy),
                            MetricChip(label: 'Fluidez', value: r.fluency),
                            MetricChip(
                                label: 'Completitud', value: r.completeness),
                            MetricChip(label: 'Prosodia', value: r.prosody),
                          ]),
                        ),
                      ]),
                      const SizedBox(height: 20),
                      ScoredSentence(
                        words: r.words,
                        fontSize: 18,
                        onWordTap: (w) => showWordScoreSheet(context, w,
                            onListen: () => _speaker.play(text: w.word)),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(children: [
                  if (_recording)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('Grabando… $_seconds s / $maxSeconds s',
                          style: const TextStyle(
                              color: AppColors.bad,
                              fontWeight: FontWeight.w600)),
                    ),
                  MicButton(
                    recording: _recording,
                    busy: _evaluating,
                    onPressed: _recording ? _stop : _start,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _recording || _evaluating
                        ? null
                        : () => context
                            .pushReplacement('/lesson/${widget.lessonId}/quiz'),
                    child: Text(r == null ? 'Saltar al quiz' : 'Continuar al quiz'),
                  ),
                ]),
              ),
            ]),
          );
        },
      ),
    );
  }
}
