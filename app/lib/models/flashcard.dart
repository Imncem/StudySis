import 'package:cloud_firestore/cloud_firestore.dart';

class Flashcard {
  const Flashcard({
    required this.id,
    required this.front,
    required this.back,
    required this.hint,
    required this.order,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String front;
  final String back;
  final String hint;
  final int order;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isActive => status == 'active';

  factory Flashcard.fromMap(String id, Map<String, dynamic> data) {
    return Flashcard(
      id: id,
      front: (data['front'] ?? '').toString(),
      back: (data['back'] ?? '').toString(),
      hint: (data['hint'] ?? '').toString(),
      order: (data['order'] as num?)?.toInt() ?? 0,
      status: (data['status'] ?? 'draft').toString(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
