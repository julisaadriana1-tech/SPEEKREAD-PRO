// Modelos de datos. Reflejan las tablas de supabase/migrations/0001_init.sql.

num _num(dynamic v) => v is num ? v : num.tryParse('${v ?? ''}') ?? 0;
num? _numOrNull(dynamic v) => v == null ? null : _num(v);
List<String> _strings(dynamic v) =>
    v is List ? v.map((e) => '$e').toList() : const <String>[];

class Profile {
  final String id;
  final String displayName;
  final String? jobRole;
  final List<String> goals;
  final List<String> interests;
  final int dailyGoalMin;
  final String cefrLevel;
  final bool onboarded;
  final int xpTotal;

  const Profile({
    required this.id,
    required this.displayName,
    this.jobRole,
    required this.goals,
    required this.interests,
    required this.dailyGoalMin,
    required this.cefrLevel,
    required this.onboarded,
    required this.xpTotal,
  });

  factory Profile.fromMap(Map<String, dynamic> m) => Profile(
        id: m['id'] as String,
        displayName: (m['display_name'] as String?) ?? '',
        jobRole: m['job_role'] as String?,
        goals: _strings(m['goals']),
        interests: _strings(m['interests']),
        dailyGoalMin: _num(m['daily_goal_min']).toInt(),
        cefrLevel: (m['cefr_level'] as String?) ?? 'A1',
        onboarded: (m['onboarded'] as bool?) ?? false,
        xpTotal: _num(m['xp_total']).toInt(),
      );
}

class Lesson {
  final String id;
  final String cefrLevel;
  final int unit;
  final int orderIndex;
  final String title;
  final String context; // work | life
  final String topic;
  final String bodyEn;
  final String? bodyEs;
  final String? audioUrl;
  final int estMinutes;

  const Lesson({
    required this.id,
    required this.cefrLevel,
    required this.unit,
    required this.orderIndex,
    required this.title,
    required this.context,
    required this.topic,
    required this.bodyEn,
    this.bodyEs,
    this.audioUrl,
    required this.estMinutes,
  });

  bool get isWork => context == 'work';

  factory Lesson.fromMap(Map<String, dynamic> m) => Lesson(
        id: m['id'] as String,
        cefrLevel: m['cefr_level'] as String,
        unit: _num(m['unit']).toInt(),
        orderIndex: _num(m['order_index']).toInt(),
        title: m['title'] as String,
        context: m['context'] as String,
        topic: m['topic'] as String,
        bodyEn: m['body_en'] as String,
        bodyEs: m['body_es'] as String?,
        audioUrl: m['audio_url'] as String?,
        estMinutes: _num(m['est_minutes']).toInt(),
      );
}

class LessonSentence {
  final String id;
  final int idx;
  final String textEn;
  final String? textEs;
  final String? audioUrl;

  const LessonSentence(
      {required this.id,
      required this.idx,
      required this.textEn,
      this.textEs,
      this.audioUrl});

  factory LessonSentence.fromMap(Map<String, dynamic> m) => LessonSentence(
        id: m['id'] as String,
        idx: _num(m['idx']).toInt(),
        textEn: m['text_en'] as String,
        textEs: m['text_es'] as String?,
        audioUrl: m['audio_url'] as String?,
      );
}

class VocabItem {
  final String id;
  final String word;
  final String? ipa;
  final String? definitionEn;
  final String? translationEs;
  final String? exampleEn;

  const VocabItem(
      {required this.id,
      required this.word,
      this.ipa,
      this.definitionEn,
      this.translationEs,
      this.exampleEn});

  factory VocabItem.fromMap(Map<String, dynamic> m) => VocabItem(
        id: m['id'] as String,
        word: m['word'] as String,
        ipa: m['ipa'] as String?,
        definitionEn: m['definition_en'] as String?,
        translationEs: m['translation_es'] as String?,
        exampleEn: m['example_en'] as String?,
      );
}

class QuizQuestion {
  final String id;
  final int idx;
  final String type; // mc | tf | gap | context
  final String prompt;
  final List<String> options;
  final String answer;
  final String? explanation;

  const QuizQuestion(
      {required this.id,
      required this.idx,
      required this.type,
      required this.prompt,
      required this.options,
      required this.answer,
      this.explanation});

  String get typeLabel => switch (type) {
        'tf' => 'Verdadero o falso',
        'gap' => 'Completá el espacio',
        'context' => 'Comprensión contextual',
        _ => 'Opción múltiple',
      };

  factory QuizQuestion.fromMap(Map<String, dynamic> m) => QuizQuestion(
        id: m['id'] as String,
        idx: _num(m['idx']).toInt(),
        type: m['type'] as String,
        prompt: m['prompt'] as String,
        options: _strings(m['options']),
        answer: m['answer'] as String,
        explanation: m['explanation'] as String?,
      );
}

class LessonDetail {
  final Lesson lesson;
  final List<LessonSentence> sentences;
  final List<VocabItem> vocabulary;
  final List<QuizQuestion> quiz;

  const LessonDetail(
      {required this.lesson,
      required this.sentences,
      required this.vocabulary,
      required this.quiz});

  factory LessonDetail.fromMap(Map<String, dynamic> m) {
    List<Map<String, dynamic>> list(String k) =>
        ((m[k] as List?) ?? const []).cast<Map<String, dynamic>>();
    return LessonDetail(
      lesson: Lesson.fromMap(m),
      sentences: list('lesson_sentences').map(LessonSentence.fromMap).toList()
        ..sort((a, b) => a.idx.compareTo(b.idx)),
      vocabulary: list('vocabulary').map(VocabItem.fromMap).toList(),
      quiz: list('quiz_questions').map(QuizQuestion.fromMap).toList()
        ..sort((a, b) => a.idx.compareTo(b.idx)),
    );
  }
}

class PhonemeScore {
  final String phoneme;
  final int score;
  const PhonemeScore(this.phoneme, this.score);
}

class WordScore {
  final String word;
  final int score;
  final String errorType; // None | Mispronunciation | Omission | Insertion
  final List<PhonemeScore> phonemes;

  const WordScore(
      {required this.word,
      required this.score,
      required this.errorType,
      required this.phonemes});

  bool get omitted => errorType == 'Omission';
  bool get inserted => errorType == 'Insertion';

  /// El fonema con menor puntaje (el que más conviene practicar).
  PhonemeScore? get weakestPhoneme {
    if (phonemes.isEmpty) return null;
    return phonemes.reduce((a, b) => a.score <= b.score ? a : b);
  }

  factory WordScore.fromMap(Map<String, dynamic> m) => WordScore(
        word: '${m['word'] ?? ''}',
        score: _num(m['score']).round(),
        errorType: '${m['errorType'] ?? 'None'}',
        phonemes: ((m['phonemes'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map((p) => PhonemeScore('${p['phoneme']}', _num(p['score']).round()))
            .toList(),
      );
}

class PronunciationResult {
  final bool ok;
  final String? message;
  final int overall;
  final num? accuracy;
  final num? fluency;
  final num? completeness;
  final num? prosody;
  final List<WordScore> words;

  const PronunciationResult({
    required this.ok,
    this.message,
    this.overall = 0,
    this.accuracy,
    this.fluency,
    this.completeness,
    this.prosody,
    this.words = const [],
  });

  factory PronunciationResult.fromMap(Map<String, dynamic> m) {
    if (m['status'] != 'ok') {
      return PronunciationResult(
          ok: false,
          message: (m['message'] as String?) ??
              'No pudimos evaluar la grabación. Probá de nuevo.');
    }
    return PronunciationResult(
      ok: true,
      overall: _num(m['overall']).round(),
      accuracy: _numOrNull(m['accuracy']),
      fluency: _numOrNull(m['fluency']),
      completeness: _numOrNull(m['completeness']),
      prosody: _numOrNull(m['prosody']),
      words: ((m['words'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(WordScore.fromMap)
          .toList(),
    );
  }
}

/// Nivel de jugador: el nivel n requiere 100 × n² XP.
class PlayerLevel {
  static const names = [
    'Intern', 'Associate', 'Analyst', 'Specialist', 'Lead',
    'Manager', 'Director', 'VP', 'Executive',
  ];

  final int level;
  final int xp;
  const PlayerLevel._(this.level, this.xp);

  factory PlayerLevel.fromXp(int xp) {
    var n = 1;
    while (100 * (n + 1) * (n + 1) <= xp) {
      n++;
    }
    return PlayerLevel._(n, xp);
  }

  String get name => names[(level - 1).clamp(0, names.length - 1)];
  int get currentFloor => level == 1 ? 0 : 100 * level * level;
  int get nextThreshold => 100 * (level + 1) * (level + 1);
  double get progress =>
      ((xp - currentFloor) / (nextThreshold - currentFloor)).clamp(0.0, 1.0);
}
