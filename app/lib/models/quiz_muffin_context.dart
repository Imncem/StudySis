import 'quiz_question.dart';

class QuizMuffinContext {
  const QuizMuffinContext({
    required this.subjectId,
    required this.subjectTitle,
    required this.chapterId,
    required this.chapterTitle,
    required this.questionText,
    required this.options,
    required this.questionNumber,
    required this.totalQuestions,
  });

  final String subjectId;
  final String subjectTitle;
  final String chapterId;
  final String chapterTitle;
  final String questionText;
  final List<String> options;
  final int questionNumber;
  final int totalQuestions;

  factory QuizMuffinContext.fromQuestion({
    required String subjectId,
    required String subjectTitle,
    required String chapterId,
    required String chapterTitle,
    required QuizQuestion question,
    required int questionNumber,
    required int totalQuestions,
  }) {
    return QuizMuffinContext(
      subjectId: subjectId,
      subjectTitle: subjectTitle,
      chapterId: chapterId,
      chapterTitle: chapterTitle,
      questionText: question.question,
      options: List.unmodifiable(question.options),
      questionNumber: questionNumber,
      totalQuestions: totalQuestions,
    );
  }

  Map<String, Object> toSafeMap() {
    return {
      'subjectId': subjectId,
      'subjectTitle': subjectTitle,
      'chapterId': chapterId,
      'chapterTitle': chapterTitle,
      'questionText': questionText,
      'options': options,
      'questionNumber': questionNumber,
      'totalQuestions': totalQuestions,
    };
  }
}
