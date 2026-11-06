import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewItem {
  const ReviewItem({
    required this.id,
    required this.heading,
    required this.body,
    required this.keyPoint,
    required this.prompt,
    required this.order,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String heading;
  final String body;
  final String keyPoint;
  final String prompt;
  final int order;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isActive => status == 'active';
  bool get isUsable =>
      isActive && heading.trim().isNotEmpty && body.trim().isNotEmpty;

  factory ReviewItem.fromMap(String id, Map<String, dynamic> data) {
    return ReviewItem(
      id: id,
      heading: (data['heading'] ?? '').toString(),
      body: (data['body'] ?? '').toString(),
      keyPoint: (data['keyPoint'] ?? '').toString(),
      prompt: (data['prompt'] ?? '').toString(),
      order: (data['order'] as num?)?.toInt() ?? 0,
      status: (data['status'] ?? 'draft').toString(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
