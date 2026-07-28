import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studysis/models/chapter_progress.dart';
import 'package:studysis/models/progress_summary.dart';

void main() {
  test('no progress documents reports zero and not attempted metrics', () {
    final summary = ProgressSummary.fromProgress(
      progress: const [],
      totalActiveMathChapters: 13,
    );

    expect(summary.overallAverageProgress, 0);
    expect(summary.chaptersStarted, 0);
    expect(summary.chaptersCompleted, 0);
    expect(summary.totalActiveMathChapters, 13);
    expect(summary.modulesCompleted, 0);
    expect(summary.averagePracticeScore, isNull);
    expect(summary.averageQuizScore, isNull);
    expect(summary.quizPerformanceStatus, QuizPerformanceStatus.notAttempted);
  });

  test('one chapter at 50 percent is started but not completed', () {
    final summary = ProgressSummary.fromProgress(
      progress: [_progress(overallProgress: 50)],
      totalActiveMathChapters: 13,
    );

    expect(summary.overallAverageProgress, 50);
    expect(summary.chaptersStarted, 1);
    expect(summary.chaptersCompleted, 0);
  });

  test('one completed chapter is counted as completed', () {
    final summary = ProgressSummary.fromProgress(
      progress: [_progress(overallProgress: 100)],
      totalActiveMathChapters: 13,
    );

    expect(summary.overallAverageProgress, 100);
    expect(summary.chaptersStarted, 1);
    expect(summary.chaptersCompleted, 1);
  });

  test('multiple chapter average calculation rounds to whole percentage', () {
    final summary = ProgressSummary.fromProgress(
      progress: [
        _progress(overallProgress: 25),
        _progress(overallProgress: 50),
        _progress(overallProgress: 100),
      ],
      totalActiveMathChapters: 13,
    );

    expect(summary.overallAverageProgress, 58);
  });

  test('modules completed calculation uses available saved fields', () {
    final summary = ProgressSummary.fromProgress(
      progress: [
        _progress(
          learnCompleted: true,
          flashcardsCompleted: true,
          practiceTotalQuestions: 5,
          quizCompletedAt: DateTime(2026, 1, 1),
        ),
        _progress(learnCompleted: true),
      ],
      totalActiveMathChapters: 13,
    );

    expect(summary.modulesCompleted, 5);
  });

  test('average practice score uses chapters with practice questions', () {
    final summary = ProgressSummary.fromProgress(
      progress: [
        _progress(practiceBestPercentage: 80, practiceTotalQuestions: 5),
        _progress(practiceBestPercentage: 60, practiceTotalQuestions: 4),
        _progress(practiceBestPercentage: 100, practiceTotalQuestions: 0),
      ],
      totalActiveMathChapters: 13,
    );

    expect(summary.averagePracticeScore, 70);
  });

  test('average quiz score uses completed quizzes only', () {
    final summary = ProgressSummary.fromProgress(
      progress: [
        _progress(
          quizBestPercentage: 90,
          quizCompletedAt: DateTime(2026, 1, 1),
        ),
        _progress(
          quizBestPercentage: 70,
          quizCompletedAt: DateTime(2026, 1, 2),
        ),
        _progress(quizBestPercentage: 100),
      ],
      totalActiveMathChapters: 13,
    );

    expect(summary.averageQuizScore, 80);
  });

  test('quiz performance status thresholds are encouraging', () {
    expect(
      ProgressSummary.fromProgress(
        progress: [
          _progress(
            quizBestPercentage: 80,
            quizCompletedAt: DateTime(2026, 1, 1),
          )
        ],
        totalActiveMathChapters: 13,
      ).quizPerformanceStatus,
      QuizPerformanceStatus.strong,
    );
    expect(
      ProgressSummary.fromProgress(
        progress: [
          _progress(
            quizBestPercentage: 70,
            quizCompletedAt: DateTime(2026, 1, 1),
          )
        ],
        totalActiveMathChapters: 13,
      ).quizPerformanceStatus,
      QuizPerformanceStatus.developing,
    );
    expect(
      ProgressSummary.fromProgress(
        progress: [
          _progress(
            quizBestPercentage: 69,
            quizCompletedAt: DateTime(2026, 1, 1),
          )
        ],
        totalActiveMathChapters: 13,
      ).quizPerformanceStatus,
      QuizPerformanceStatus.needsPractice,
    );
  });

  test('missing optional fields map safely before summary calculation', () {
    final progress = ChapterProgress.fromMap(
      subjectId: 'math',
      chapterId: 'chapter-1',
      data: const {
        'studentProfileId': 'qidah',
        'subjectId': 'math',
        'chapterId': 'chapter-1',
        'overallProgress': 25,
      },
    );
    final summary = ProgressSummary.fromProgress(
      progress: [progress],
      totalActiveMathChapters: 13,
    );

    expect(summary.chaptersStarted, 1);
    expect(summary.averagePracticeScore, isNull);
    expect(summary.averageQuizScore, isNull);
  });
}

ChapterProgress _progress({
  int overallProgress = 0,
  bool learnCompleted = false,
  bool flashcardsCompleted = false,
  int practiceBestPercentage = 0,
  int practiceTotalQuestions = 0,
  int quizBestPercentage = 0,
  DateTime? quizCompletedAt,
}) {
  return ChapterProgress.fromMap(
    subjectId: 'math',
    chapterId: 'chapter-1',
    data: {
      'studentProfileId': 'qidah',
      'subjectId': 'math',
      'chapterId': 'chapter-1',
      'learnCompleted': learnCompleted,
      'flashcardsCompleted': flashcardsCompleted,
      'practiceBestPercentage': practiceBestPercentage,
      'practiceTotalQuestions': practiceTotalQuestions,
      'quizBestPercentage': quizBestPercentage,
      'quizCompletedAt':
          quizCompletedAt == null ? null : Timestamp.fromDate(quizCompletedAt),
      'overallProgress': overallProgress,
    },
  );
}
