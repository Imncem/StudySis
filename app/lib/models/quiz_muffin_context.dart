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
    this.selectedStudentAnswer,
  });

  final String subjectId;
  final String subjectTitle;
  final String chapterId;
  final String chapterTitle;
  final String questionText;
  final List<String> options;
  final int questionNumber;
  final int totalQuestions;
  final String? selectedStudentAnswer;

  factory QuizMuffinContext.fromQuestion({
    required String subjectId,
    required String subjectTitle,
    required String chapterId,
    required String chapterTitle,
    required QuizQuestion question,
    required int questionNumber,
    required int totalQuestions,
    int? selectedAnswerIndex,
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
      selectedStudentAnswer: selectedAnswerIndex == null
          ? null
          : selectedAnswerIndex < question.options.length
              ? question.options[selectedAnswerIndex]
              : null,
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
      if (selectedStudentAnswer != null)
        'selectedStudentAnswer': selectedStudentAnswer!,
    };
  }
}
