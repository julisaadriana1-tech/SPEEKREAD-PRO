// Pruebas de la lógica que no depende de Supabase.
// Ejecutar con: flutter test
import 'package:flutter_test/flutter_test.dart';
import 'package:speakread/models/models.dart';
import 'package:speakread/providers.dart';

Lesson _lesson(String id, String level, String context, String topic,
        {int unit = 1, int order = 1}) =>
    Lesson(
      id: id,
      cefrLevel: level,
      unit: unit,
      orderIndex: order,
      title: id,
      context: context,
      topic: topic,
      bodyEn: 'text',
      estMinutes: 8,
    );

const _profile = Profile(
  id: 'u1',
  displayName: 'Ana',
  goals: ['meetings'],
  interests: ['risk'],
  dailyGoalMin: 10,
  cefrLevel: 'B1',
  onboarded: true,
  xpTotal: 0,
);

void main() {
  group('PlayerLevel', () {
    test('nivel 1 con poco XP', () {
      expect(PlayerLevel.fromXp(0).level, 1);
      expect(PlayerLevel.fromXp(399).level, 1);
    });
    test('nivel n requiere 100 × n² XP', () {
      expect(PlayerLevel.fromXp(400).level, 2);
      expect(PlayerLevel.fromXp(2500).level, 5);
      expect(PlayerLevel.fromXp(2500).name, 'Lead');
    });
  });

  group('pickTodayLesson', () {
    final lessons = [
      _lesson('b1-pm', 'B1', 'work', 'project-management'),
      _lesson('b1-risk', 'B1', 'work', 'risk', order: 2),
      _lesson('b1-life', 'B1', 'life', 'daily-life', order: 3),
      _lesson('a2-x', 'A2', 'work', 'risk'),
    ];

    test('prioriza el nivel actual y los intereses', () {
      expect(pickTodayLesson(lessons, {}, _profile)?.id, 'b1-risk');
    });
    test('no repite lecciones completadas', () {
      expect(pickTodayLesson(lessons, {'b1-risk'}, _profile)?.id, 'b1-pm');
    });
  });

  group('PronunciationResult', () {
    test('lee la respuesta de la Edge Function', () {
      final r = PronunciationResult.fromMap({
        'status': 'ok',
        'overall': 82,
        'accuracy': 80,
        'fluency': 90,
        'completeness': 100,
        'prosody': 70,
        'words': [
          {
            'word': 'project',
            'score': 55,
            'errorType': 'Mispronunciation',
            'phonemes': [
              {'phoneme': 'p', 'score': 95},
              {'phoneme': 'ɹ', 'score': 30},
            ],
          },
        ],
      });
      expect(r.ok, isTrue);
      expect(r.words.single.weakestPhoneme?.phoneme, 'ɹ');
    });
    test('maneja "no_speech"', () {
      final r = PronunciationResult.fromMap({'status': 'no_speech', 'message': 'x'});
      expect(r.ok, isFalse);
    });
  });
}
