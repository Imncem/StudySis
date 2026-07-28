import 'package:cloud_firestore/cloud_firestore.dart';

class ChapterProgress {
  const ChapterProgress({
    required this.studentProfileId,
    required this.subjectId,
    required this.chapterId,
    required this.learnCompleted,
    required this.learnCompletedAt,
    required this.flashcardsMasteredCount,
    required this.flashcardsTotalCount,
    required this.flashcardsCompleted,
    required this.masteredFlashcardIds,
    required this.practiceLatestPercentage,
    required this.practiceBestPercentage,
    required this.practiceCorrectCount,
    required this.practiceTotalQuestions,
    required this.practiceCompletedAt,
    required this.quizLatestPercentage,
    required this.quizBestPercentage,
    required this.quizCorrectCount,
    required this.quizIncorrectCount,
    required this.quizUnansweredCount,
    required this.quizPassed,
    required this.quizCompletedAt,
    required this.overallProgress,
    required this.lastActivityAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String studentProfileId;
  final String subjectId;
  final String chapterId;
  final bool learnCompleted;
  final DateTime? learnCompletedAt;
  final int flashcardsMasteredCount;
  final int flashcardsTotalCount;
  final bool flashcardsCompleted;
  final List<String> masteredFlashcardIds;
  final int practiceLatestPercentage;
  final int practiceBestPercentage;
  final int practiceCorrectCount;
  final int practiceTotalQuestions;
  final DateTime? practiceCompletedAt;
  final int quizLatestPercentage;
  final int quizBestPercentage;
  final int quizCorrectCount;
  final int quizIncorrectCount;
  final int quizUnansweredCount;
  final bool quizPassed;
  final DateTime? quizCompletedAt;
  final int overallProgress;
  final DateTime? lastActivityAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get practiceCompleted => practiceCompletedAt != null;
  bool get quizCompleted => quizCompletedAt != null;

  factory ChapterProgress.empty({
    required String subjectId,
    required String chapterId,
    String studentProfileId = 'qidah',
  }) {
    return ChapterProgress(
      studentProfileId: studentProfileId,
      subjectId: subjectId,
      chapterId: chapterId,
      learnCompleted: false,
      learnCompletedAt: null,
      flashcardsMasteredCount: 0,
      flashcardsTotalCount: 0,
      flashcardsCompleted: false,
      masteredFlashcardIds: const [],
      practiceLatestPercentage: 0,
      practiceBestPercentage: 0,
      practiceCorrectCount: 0,
      practiceTotalQuestions: 0,
      practiceCompletedAt: null,
      quizLatestPercentage: 0,
      quizBestPercentage: 0,
      quizCorrectCount: 0,
      quizIncorrectCount: 0,
      quizUnansweredCount: 0,
      quizPassed: false,
      quizCompletedAt: null,
      overallProgress: 0,
      lastActivityAt: null,
      createdAt: null,
      updatedAt: null,
    );
  }

  factory ChapterProgress.fromMap({
    required String subjectId,
    required String chapterId,
    required Map<String, dynamic>? data,
  }) {
    if (data == null) {
      return ChapterProgress.empty(subjectId: subjectId, chapterId: chapterId);
    }
    final masteredIds = data['masteredFlashcardIds'];
    return ChapterProgress(
      studentProfileId: _string(data['studentProfileId'], 'qidah'),
      subjectId: _string(data['subjectId'], subjectId),
      chapterId: _string(data['chapterId'], chapterId),
      learnCompleted: data['learnCompleted'] == true,
      learnCompletedAt: _date(data['learnCompletedAt']),
      flashcardsMasteredCount: _nonNegativeInt(data['flashcardsMasteredCount']),
      flashcardsTotalCount: _nonNegativeInt(data['flashcardsTotalCount']),
      flashcardsCompleted: data['flashcardsCompleted'] == true,
      masteredFlashcardIds: masteredIds is List
          ? masteredIds.map((value) => value.toString()).toList()
          : const [],
      practiceLatestPercentage: _percentage(data['practiceLatestPercentage']),
      practiceBestPercentage: _percentage(data['practiceBestPercentage']),
      practiceCorrectCount: _nonNegativeInt(data['practiceCorrectCount']),
      practiceTotalQuestions: _nonNegativeInt(data['practiceTotalQuestions']),
      practiceCompletedAt: _date(data['practiceCompletedAt']),
      quizLatestPercentage: _percentage(data['quizLatestPercentage']),
      quizBestPercentage: _percentage(data['quizBestPercentage']),
      quizCorrectCount: _nonNegativeInt(data['quizCorrectCount']),
      quizIncorrectCount: _nonNegativeInt(data['quizIncorrectCount']),
      quizUnansweredCount: _nonNegativeInt(data['quizUnansweredCount']),
      quizPassed: data['quizPassed'] == true,
      quizCompletedAt: _date(data['quizCompletedAt']),
      overallProgress: _percentage(data['overallProgress']),
      lastActivityAt: _date(data['lastActivityAt']),
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
    );
  }

  static String _string(Object? value, String fallback) {
    if (value is String && value.trim().isNotEmpty) return value;
    return fallback;
  }

  static int _nonNegativeInt(Object? value) {
    final number = value is num ? value.round() : 0;
    return number < 0 ? 0 : number;
  }

  static int _percentage(Object? value) {
    return _nonNegativeInt(value).clamp(0, 100);
  }

  static DateTime? _date(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

int calculateOverallProgress({
  required bool learnCompleted,
  required int flashcardsMasteredCount,
  required int flashcardsTotalCount,
  required bool practiceCompleted,
  required bool quizCompleted,
}) {
  final learn = learnCompleted ? 25.0 : 0.0;
  final flashcards = flashcardsTotalCount <= 0
      ? 0.0
      : (flashcardsMasteredCount.clamp(0, flashcardsTotalCount) /
              flashcardsTotalCount) *
          25;
  final practice = practiceCompleted ? 25.0 : 0.0;
  final quiz = quizCompleted ? 25.0 : 0.0;
  return (learn + flashcards + practice + quiz).round().clamp(0, 100);
}

int resultPercentage({required int correctCount, required int totalQuestions}) {
  if (totalQuestions <= 0) return 0;
  return ((correctCount / totalQuestions) * 100).round().clamp(0, 100);
}
