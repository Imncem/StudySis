import 'chapter_progress.dart';

enum QuizPerformanceStatus {
  strong,
  developing,
  needsPractice,
  notAttempted,
}

class ProgressSummary {
  const ProgressSummary({
    required this.overallAverageProgress,
    required this.chaptersStarted,
    required this.chaptersCompleted,
    required this.totalActiveMathChapters,
    required this.modulesCompleted,
    required this.averagePracticeScore,
    required this.averageQuizScore,
    required this.quizPerformanceStatus,
  });

  final int overallAverageProgress;
  final int chaptersStarted;
  final int chaptersCompleted;
  final int totalActiveMathChapters;
  final int modulesCompleted;
  final int? averagePracticeScore;
  final int? averageQuizScore;
  final QuizPerformanceStatus quizPerformanceStatus;

  bool get hasProgress => chaptersStarted > 0;

  factory ProgressSummary.fromProgress({
    required List<ChapterProgress> progress,
    required int totalActiveMathChapters,
  }) {
    if (progress.isEmpty) {
      return ProgressSummary(
        overallAverageProgress: 0,
        chaptersStarted: 0,
        chaptersCompleted: 0,
        totalActiveMathChapters: totalActiveMathChapters,
        modulesCompleted: 0,
        averagePracticeScore: null,
        averageQuizScore: null,
        quizPerformanceStatus: QuizPerformanceStatus.notAttempted,
      );
    }

    final overallAverage = _roundedAverage(
      progress.map((chapter) => chapter.overallProgress),
    );
    final practiceScores = progress
        .where((chapter) => chapter.practiceTotalQuestions > 0)
        .map((chapter) => chapter.practiceBestPercentage);
    final quizScores = progress
        .where((chapter) => chapter.quizCompletedAt != null)
        .map((chapter) => chapter.quizBestPercentage);
    final averageQuiz = _nullableRoundedAverage(quizScores);

    return ProgressSummary(
      overallAverageProgress: overallAverage,
      chaptersStarted:
          progress.where((chapter) => chapter.overallProgress > 0).length,
      chaptersCompleted:
          progress.where((chapter) => chapter.overallProgress == 100).length,
      totalActiveMathChapters: totalActiveMathChapters,
      modulesCompleted: progress.fold<int>(
        0,
        (total, chapter) =>
            total +
            (chapter.learnCompleted ? 1 : 0) +
            (chapter.flashcardsCompleted ? 1 : 0) +
            (chapter.practiceTotalQuestions > 0 ? 1 : 0) +
            (chapter.quizCompletedAt != null ? 1 : 0),
      ),
      averagePracticeScore: _nullableRoundedAverage(practiceScores),
      averageQuizScore: averageQuiz,
      quizPerformanceStatus: _quizStatus(averageQuiz),
    );
  }

  static int _roundedAverage(Iterable<int> values) {
    final list = values.toList(growable: false);
    if (list.isEmpty) return 0;
    return (list.reduce((a, b) => a + b) / list.length).round();
  }

  static int? _nullableRoundedAverage(Iterable<int> values) {
    final list = values.toList(growable: false);
    if (list.isEmpty) return null;
    return _roundedAverage(list);
  }

  static QuizPerformanceStatus _quizStatus(int? averageQuizScore) {
    if (averageQuizScore == null) return QuizPerformanceStatus.notAttempted;
    if (averageQuizScore >= 80) return QuizPerformanceStatus.strong;
    if (averageQuizScore >= 70) return QuizPerformanceStatus.developing;
    return QuizPerformanceStatus.needsPractice;
  }
}

extension QuizPerformanceStatusLabel on QuizPerformanceStatus {
  String get label {
    switch (this) {
      case QuizPerformanceStatus.strong:
        return 'Strong';
      case QuizPerformanceStatus.developing:
        return 'Developing';
      case QuizPerformanceStatus.needsPractice:
        return 'Needs Practice';
      case QuizPerformanceStatus.notAttempted:
        return 'Not Attempted';
    }
  }

  String get encouragement {
    switch (this) {
      case QuizPerformanceStatus.strong:
        return 'You are building strong quiz confidence.';
      case QuizPerformanceStatus.developing:
        return 'You are getting closer with each try.';
      case QuizPerformanceStatus.needsPractice:
        return 'A little more practice will help this grow.';
      case QuizPerformanceStatus.notAttempted:
        return 'Try a quiz when you are ready.';
    }
  }
}
