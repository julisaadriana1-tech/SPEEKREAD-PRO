import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Paso 4: test de comprensión con explicación inmediata.
/// La corrección definitiva se hace en el servidor (complete_lesson).
class QuizScreen extends ConsumerStatefulWidget {
  final String lessonId;
  const QuizScreen({super.key, required this.lessonId});
  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  int _index = 0;
  String? _selected;
  bool _checked = false;
  bool _submitting = false;
  final Map<String, String> _answers = {};

  Future<void> _finish() async {
    setState(() => _submitting = true);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final session = sessionFor(ref, widget.lessonId);
      final result = await ref.read(repoProvider).completeLesson(
            lessonId: widget.lessonId,
            answers: _answers,
            startedAt: session.startedAt,
          );
      ref.read(lessonSessionsProvider).remove(widget.lessonId);
      ref.invalidate(profileProvider);
      router.pushReplacement('/lesson/${widget.lessonId}/result',
          extra: result);
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('No se pudo guardar el resultado: $e')));
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(lessonDetailProvider(widget.lessonId));
    return Scaffold(
      appBar: AppBar(title: const Text('Comprensión')),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(error: e),
        data: (d) {
          if (d.quiz.isEmpty) {
            return Center(
              child: FilledButton(
                  onPressed: _submitting ? null : _finish,
                  child: const Text('Terminar lección')),
            );
          }
          final q = d.quiz[_index];
          final last = _index == d.quiz.length - 1;
          final correctSoFar = _answers.entries.where((e) {
            final qq = d.quiz.firstWhere((x) => x.id == e.key);
            return qq.answer.toLowerCase() == e.value.toLowerCase();
          }).length;

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: (_index + (_checked ? 1 : 0)) / d.quiz.length,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('$correctSoFar ✓'),
                  ]),
                  const SizedBox(height: 20),
                  Text(q.typeLabel.toUpperCase(),
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(letterSpacing: 1.1)),
                  const SizedBox(height: 8),
                  Text(q.prompt,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView(children: [
                      for (final option in q.options)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _OptionTile(
                            text: option,
                            state: _optionState(q, option),
                            onTap: _checked
                                ? null
                                : () => setState(() => _selected = option),
                          ),
                        ),
                      if (_checked) _Explanation(question: q, selected: _selected!),
                    ]),
                  ),
                  FilledButton(
                    onPressed: _selected == null || _submitting
                        ? null
                        : () {
                            if (!_checked) {
                              setState(() {
                                _checked = true;
                                _answers[q.id] = _selected!;
                              });
                            } else if (last) {
                              _finish();
                            } else {
                              setState(() {
                                _index++;
                                _selected = null;
                                _checked = false;
                              });
                            }
                          },
                    child: _submitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(!_checked
                            ? 'Comprobar'
                            : (last ? 'Ver resultado' : 'Siguiente')),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  _OptionState _optionState(QuizQuestion q, String option) {
    final isAnswer = option.toLowerCase() == q.answer.toLowerCase();
    if (!_checked) {
      return option == _selected ? _OptionState.selected : _OptionState.idle;
    }
    if (isAnswer) return _OptionState.correct;
    if (option == _selected) return _OptionState.wrong;
    return _OptionState.idle;
  }
}

enum _OptionState { idle, selected, correct, wrong }

class _OptionTile extends StatelessWidget {
  final String text;
  final _OptionState state;
  final VoidCallback? onTap;
  const _OptionTile({required this.text, required this.state, this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (Color border, IconData? icon) = switch (state) {
      _OptionState.idle => (scheme.outlineVariant, null),
      _OptionState.selected => (scheme.primary, Icons.radio_button_checked),
      _OptionState.correct => (AppColors.good, Icons.check_circle),
      _OptionState.wrong => (AppColors.bad, Icons.cancel),
    };
    return Material(
      color: state == _OptionState.idle
          ? scheme.surface
          : border.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: border, width: state == _OptionState.idle ? 1 : 2),
          ),
          child: Row(children: [
            Expanded(child: Text(text, style: const TextStyle(fontSize: 16))),
            if (icon != null) Icon(icon, color: border),
          ]),
        ),
      ),
    );
  }
}

class _Explanation extends StatelessWidget {
  final QuizQuestion question;
  final String selected;
  const _Explanation({required this.question, required this.selected});

  @override
  Widget build(BuildContext context) {
    final correct = selected.toLowerCase() == question.answer.toLowerCase();
    final color = correct ? AppColors.good : AppColors.bad;
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(correct ? '¡Correcto!' : 'Respuesta correcta: ${question.answer}',
            style: TextStyle(fontWeight: FontWeight.w700, color: color)),
        if (question.explanation != null) ...[
          const SizedBox(height: 6),
          Text(question.explanation!),
        ],
      ]),
    );
  }
}
