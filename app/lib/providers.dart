import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/models.dart';
import 'services/audio.dart';
import 'services/repository.dart';

final repoProvider = Provider<Repository>((ref) => Repository());

final authStateProvider = StreamProvider<AuthState>(
    (ref) => Supabase.instance.client.auth.onAuthStateChange);

final profileProvider = FutureProvider<Profile?>((ref) async {
  ref.watch(authStateProvider);
  return ref.read(repoProvider).fetchProfile();
});

final dashboardProvider = FutureProvider.autoDispose<Map<String, dynamic>>(
    (ref) => ref.read(repoProvider).dashboard());

final lessonsProvider = FutureProvider.autoDispose<List<Lesson>>(
    (ref) => ref.read(repoProvider).allLessons());

final completedLessonsProvider = FutureProvider.autoDispose<Set<String>>(
    (ref) => ref.read(repoProvider).completedLessonIds());

final lessonDetailProvider = FutureProvider.family<LessonDetail, String>(
    (ref, id) => ref.read(repoProvider).lessonDetail(id));

final speakerProvider = Provider<Speaker>((ref) {
  final speaker = Speaker();
  ref.onDispose(speaker.dispose);
  return speaker;
});

/// Estado de una lección en curso (desde que se abre hasta el quiz).
class LessonSession {
  final DateTime startedAt = DateTime.now();
  final Map<String, int> bestBySentence = {};
  PronunciationResult? fullRead;
}

final lessonSessionsProvider =
    Provider<Map<String, LessonSession>>((ref) => <String, LessonSession>{});

LessonSession sessionFor(WidgetRef ref, String lessonId) =>
    ref.read(lessonSessionsProvider).putIfAbsent(lessonId, LessonSession.new);

void startSession(WidgetRef ref, String lessonId) =>
    ref.read(lessonSessionsProvider)[lessonId] = LessonSession();

/// Elige la "Lección de hoy": del nivel actual, sin completar, priorizando
/// los intereses del perfil y alternando trabajo / vida (70/30).
Lesson? pickTodayLesson(
    List<Lesson> lessons, Set<String> completed, Profile profile) {
  final inLevel =
      lessons.where((l) => l.cefrLevel == profile.cefrLevel).toList();
  final pending = inLevel.where((l) => !completed.contains(l.id)).toList();
  if (pending.isEmpty) {
    final anyPending = lessons.where((l) => !completed.contains(l.id));
    if (anyPending.isNotEmpty) return anyPending.first;
    return inLevel.isNotEmpty ? inLevel.first : null;
  }
  // Cada 4ª lección completada del nivel toca una de vida cotidiana (≈70/30).
  final doneInLevel = inLevel.length - pending.length;
  final wantLife = doneInLevel % 4 == 3;
  int rank(Lesson l) {
    var r = 0;
    if (profile.interests.contains(l.topic)) r -= 2;
    if (l.isWork != wantLife) r -= 1;
    return r;
  }

  pending.sort((a, b) {
    final byRank = rank(a).compareTo(rank(b));
    if (byRank != 0) return byRank;
    final byUnit = a.unit.compareTo(b.unit);
    return byUnit != 0 ? byUnit : a.orderIndex.compareTo(b.orderIndex);
  });
  return pending.first;
}
