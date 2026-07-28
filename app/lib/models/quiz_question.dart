import 'package:cloud_firestore/cloud_firestore.dart';

class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.correctOptionIndex,
    required this.explanation,
    required this.difficulty,
    required this.order,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String question;
  final List<String> options;
  final int correctOptionIndex;
  final String explanation;
  final String difficulty;
  final int order;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isActive => status == 'active';

  bool get isValid =>
      question.trim().isNotEmpty &&
      options.length >= 2 &&
      correctOptionIndex >= 0 &&
      correctOptionIndex < options.length;

  factory QuizQuestion.fromMap(String id, Map<String, dynamic> data) {
    return QuizQuestion(
      id: id,
      question: (data['question'] ?? '').toString(),
      options: (data['options'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(growable: false),
      correctOptionIndex: (data['correctOptionIndex'] as num?)?.toInt() ?? -1,
      explanation: (data['explanation'] ?? '').toString(),
      difficulty: (data['difficulty'] ?? 'easy').toString(),
      order: (data['order'] as num?)?.toInt() ?? 0,
      status: (data['status'] ?? 'draft').toString(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
