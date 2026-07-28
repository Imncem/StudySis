import 'package:cloud_firestore/cloud_firestore.dart';

class PracticeQuestion {
  const PracticeQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.correctAnswerIndex,
    required this.explanation,
    required this.hint,
    required this.topic,
    required this.difficulty,
    required this.order,
    required this.status,
    required this.isPublished,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String question;
  final List<String> options;
  final int correctAnswerIndex;
  final String explanation;
  final String hint;
  final String topic;
  final String difficulty;
  final int order;
  final String status;
  final bool isPublished;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isValid =>
      question.trim().isNotEmpty &&
      options.length >= 2 &&
      correctAnswerIndex >= 0 &&
      correctAnswerIndex < options.length;

  factory PracticeQuestion.fromMap(String id, Map<String, dynamic> data) {
    final legacyAnswer = (data['answer'] ?? '').toString();
    final parsedOptions = (data['options'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList(growable: true);
    if (parsedOptions.isEmpty && legacyAnswer.trim().isNotEmpty) {
      parsedOptions.add(legacyAnswer);
    }
    final status = (data['status'] ?? '').toString();
    return PracticeQuestion(
      id: id,
      question: (data['question'] ?? '').toString(),
      options: parsedOptions.toList(growable: false),
      correctAnswerIndex: (data['correctAnswerIndex'] as num?)?.toInt() ??
          (data['correctOptionIndex'] as num?)?.toInt() ??
          -1,
      explanation: (data['explanation'] ?? '').toString(),
      hint: (data['hint'] ?? '').toString(),
      topic: (data['topic'] ?? '').toString(),
      difficulty: (data['difficulty'] ?? 'easy').toString(),
      order: (data['order'] as num?)?.toInt() ?? 0,
      status: status.isEmpty
          ? (data['isPublished'] == true ? 'active' : 'draft')
          : status,
      isPublished: data['isPublished'] == true || status == 'active',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
