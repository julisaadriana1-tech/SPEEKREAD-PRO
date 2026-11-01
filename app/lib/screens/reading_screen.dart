import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers.dart';
import '../services/audio.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Paso 1: lectura con audio nativo, vocabulario resaltado y traducción.
class ReadingScreen extends ConsumerStatefulWidget {
  final String lessonId;
  const ReadingScreen({super.key, required this.lessonId});
  @override
  ConsumerState<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends ConsumerState<ReadingScreen> {
  final List<TapGestureRecognizer> _recognizers = [];
  late final Speaker _speaker;
  bool _showTranslation = false;
  bool _playing = false;
  double _speed = 1.0;
  double _fontSize = 18;

  @override
  void initState() {
    super.initState();
    _speaker = ref.read(speakerProvider);
    startSession(ref, widget.lessonId);
  }

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _speaker.stop();
    super.dispose();
  }

  Future<void> _togglePlay(Lesson lesson) async {
    final speaker = _speaker;
    if (_playing) {
      await speaker.stop();
      if (mounted) setState(() => _playing = false);
      return;
    }
    setState(() => _playing = true);
    try {
      await speaker.play(
          url: lesson.audioUrl, text: lesson.bodyEn, speed: _speed);
    } finally {
      if (mounted) setState(() => _playing = false);
    }
  }

  /// Arma el texto con las palabras del vocabulario resaltadas y tocables.
  TextSpan _buildText(BuildContext context, LessonDetail d) {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
    final base = readingStyle(context, size: _fontSize);
    final vocab = [...d.vocabulary]
      ..sort((a, b) => b.word.length.compareTo(a.word.length));
    if (vocab.isEmpty) return TextSpan(text: d.lesson.bodyEn, style: base);

    final pattern = RegExp(
        r'\b(' + vocab.map((v) => RegExp.escape(v.word)).join('|') + r')\b',
        caseSensitive: false);
    final spans = <InlineSpan>[];
    d.lesson.bodyEn.splitMapJoin(pattern, onMatch: (m) {
      final word = m.group(0)!;
      final item =
          vocab.firstWhere((v) => v.word.toLowerCase() == word.toLowerCase());
      final rec = TapGestureRecognizer()
        ..onTap = () => _showVocab(context, item);
      _recognizers.add(rec);
      spans.add(TextSpan(
        text: word,
        recognizer: rec,
        style: base.copyWith(
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
          backgroundColor: AppColors.accent.withValues(alpha: 0.18),
        ),
      ));
      return '';
    }, onNonMatch: (s) {
      spans.add(TextSpan(text: s, style: base));
      return '';
    });
    return TextSpan(children: spans);
  }

  void _showVocab(BuildContext context, VocabItem v) {
    final speaker = _speaker;
    showModalBottomSheet(
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
                child: Text(v.word,
                    style: Theme.of(ctx)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              IconButton.filledTonal(
                tooltip: 'Escuchar',
                onPressed: () => speaker.play(text: v.word),
                icon: const Icon(Icons.volume_up),
              ),
            ]),
            if (v.ipa != null) Text(v.ipa!, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            if (v.definitionEn != null) Text(v.definitionEn!),
            if (v.translationEs != null) ...[
              const SizedBox(height: 6),
              Text('Español: ${v.translationEs}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
            if (v.exampleEn != null) ...[
              const SizedBox(height: 12),
              Text('"${v.exampleEn}"',
                  style: const TextStyle(fontStyle: FontStyle.italic)),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(lessonDetailProvider(widget.lessonId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lectura'),
        actions: [
          IconButton(
            tooltip: 'Tamaño de texto',
            icon: const Icon(Icons.text_fields),
            onPressed: () => setState(
                () => _fontSize = _fontSize >= 24 ? 16 : _fontSize + 2),
          ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
            error: e,
            onRetry: () =>
                ref.invalidate(lessonDetailProvider(widget.lessonId))),
        data: (d) => Column(children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Wrap(spacing: 8, children: [
                  Chip(label: Text(d.lesson.cefrLevel)),
                  Chip(label: Text(contextLabel(d.lesson.context))),
                  Chip(label: Text('${d.lesson.estMinutes} min')),
                ]),
                const SizedBox(height: 8),
                Text(d.lesson.title,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    child: Row(children: [
                      IconButton.filled(
                        iconSize: 30,
                        onPressed: () => _togglePlay(d.lesson),
                        icon: Icon(_playing
                            ? Icons.stop_rounded
                            : Icons.play_arrow_rounded),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('Audio nativo')),
                      SegmentedButton<double>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(value: 0.75, label: Text('0.75x')),
                          ButtonSegment(value: 1.0, label: Text('1x')),
                          ButtonSegment(value: 1.25, label: Text('1.25x')),
                        ],
                        selected: {_speed},
                        onSelectionChanged: (s) =>
                            setState(() => _speed = s.first),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 20),
                Text.rich(_buildText(context, d)),
                const SizedBox(height: 8),
                Text('Tocá las palabras resaltadas para ver su significado.',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 16),
                if (d.lesson.bodyEs != null)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Mostrar traducción'),
                    value: _showTranslation,
                    onChanged: (v) => setState(() => _showTranslation = v),
                  ),
                if (_showTranslation && d.lesson.bodyEs != null)
                  Text(d.lesson.bodyEs!,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant)),
              ],
            ),
          ),
          SafeArea(
            minimum: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: () =>
                  context.push('/lesson/${widget.lessonId}/practice'),
              icon: const Icon(Icons.mic),
              label: const Text('Practicar: Leer y Repetir'),
            ),
          ),
        ]),
      ),
    );
  }
}
