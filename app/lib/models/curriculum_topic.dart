import 'package:cloud_firestore/cloud_firestore.dart';

class CurriculumTopic {
  const CurriculumTopic({
    required this.id,
    required this.title,
    required this.order,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final int order;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isActive => status == 'active';

  factory CurriculumTopic.fromMap(String id, Map<String, dynamic> data) =>
      CurriculumTopic(
        id: id,
        title: (data['title'] ?? 'Untitled topic').toString(),
        order: (data['order'] as num?)?.toInt() ?? 0,
        status: (data['status'] ?? 'draft').toString(),
        createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
        updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      );
}
