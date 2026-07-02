import 'package:cloud_firestore/cloud_firestore.dart';

class NoteSection {
  const NoteSection({
    required this.id,
    required this.heading,
    required this.body,
    required this.example,
    required this.order,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String heading;
  final String body;
  final String example;
  final int order;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory NoteSection.fromMap(String id, Map<String, dynamic> data) {
    return NoteSection(
      id: id,
      heading: (data['heading'] ?? '').toString(),
      body: (data['body'] ?? '').toString(),
      example: (data['example'] ?? '').toString(),
      order: (data['order'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
