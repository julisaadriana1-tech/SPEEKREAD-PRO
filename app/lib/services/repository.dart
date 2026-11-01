import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';

/// Toda la comunicación con Supabase pasa por aquí.
class Repository {
  SupabaseClient get _db => Supabase.instance.client;

  String? get userId => _db.auth.currentUser?.id;
  int get _offsetMin => DateTime.now().timeZoneOffset.inMinutes;

  // ---------- Autenticación ----------
  Future<void> signIn(String email, String password) =>
      _db.auth.signInWithPassword(email: email, password: password);

  Future<bool> signUp(String email, String password, String name) async {
    final res = await _db.auth
        .signUp(email: email, password: password, data: {'name': name});
    // Si el proyecto exige confirmar el email, no hay sesión todavía.
    return res.session != null;
  }

  Future<void> signOut() => _db.auth.signOut();

  // ---------- Perfil ----------
  Future<Profile?> fetchProfile() async {
    final id = userId;
    if (id == null) return null;
    final row = await _db.from('profiles').select().eq('id', id).maybeSingle();
    return row == null ? null : Profile.fromMap(row);
  }

  Future<void> saveOnboarding({
    required String jobRole,
    required List<String> goals,
    required List<String> interests,
    required int dailyGoalMin,
    required String cefrLevel,
  }) async {
    await _db.from('profiles').update({
      'job_role': jobRole,
      'goals': goals,
      'interests': interests,
      'daily_goal_min': dailyGoalMin,
      'cefr_level': cefrLevel,
      'onboarded': true,
    }).eq('id', userId!);
  }

  Future<void> updateLevel(String cefrLevel) async {
    await _db
        .from('profiles')
        .update({'cefr_level': cefrLevel}).eq('id', userId!);
  }

  // ---------- Lecciones ----------
  Future<List<Lesson>> allLessons() async {
    final rows = await _db
        .from('lessons')
        .select(
            'id, cefr_level, unit, order_index, title, context, topic, body_en, body_es, audio_url, est_minutes')
        .order('cefr_level')
        .order('unit')
        .order('order_index');
    return rows.map(Lesson.fromMap).toList();
  }

  Future<LessonDetail> lessonDetail(String id) async {
    final row = await _db
        .from('lessons')
        .select('*, lesson_sentences(*), vocabulary(*), quiz_questions(*)')
        .eq('id', id)
        .single();
    return LessonDetail.fromMap(row);
  }

  Future<Set<String>> completedLessonIds() async {
    final rows = await _db.from('lesson_attempts').select('lesson_id');
    return rows.map((r) => r['lesson_id'] as String).toSet();
  }

  // ---------- Pronunciación ----------
  /// Envía la grabación a la Edge Function, que llama a Azure.
  Future<PronunciationResult> assessPronunciation({
    required Uint8List wav,
    required String referenceText,
    String? lessonId,
    String? sentenceId,
  }) async {
    try {
      final res = await _db.functions.invoke('assess-pronunciation', body: {
        'referenceText': referenceText,
        'audioBase64': base64Encode(wav),
        'lessonId': lessonId,
        'sentenceId': sentenceId,
      });
      final data = res.data;
      if (data is Map<String, dynamic>) return PronunciationResult.fromMap(data);
      if (data is String) {
        return PronunciationResult.fromMap(
            jsonDecode(data) as Map<String, dynamic>);
      }
      return const PronunciationResult(
          ok: false, message: 'Respuesta inesperada del servidor.');
    } on FunctionException catch (e) {
      return PronunciationResult(
          ok: false,
          message: e.status == 413
              ? 'La grabación es demasiado larga (máximo 60 segundos).'
              : 'No pudimos evaluar la grabación (error ${e.status}). Revisá tu conexión.');
    } catch (_) {
      return const PronunciationResult(
          ok: false, message: 'Sin conexión. Probá de nuevo en unos segundos.');
    }
  }

  // ---------- Progreso ----------
  Future<Map<String, dynamic>> completeLesson({
    required String lessonId,
    required Map<String, String> answers,
    required DateTime startedAt,
  }) async {
    final res = await _db.rpc('complete_lesson', params: {
      'p_lesson_id': lessonId,
      'p_answers': answers.entries
          .map((e) => {'question_id': e.key, 'answer': e.value})
          .toList(),
      'p_duration_sec': DateTime.now().difference(startedAt).inSeconds,
      'p_started_at': startedAt.toUtc().toIso8601String(),
      'p_offset_min': _offsetMin,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> dashboard() async {
    final res =
        await _db.rpc('get_dashboard', params: {'p_offset_min': _offsetMin});
    return Map<String, dynamic>.from(res as Map);
  }
}
