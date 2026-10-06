import 'package:cloud_firestore/cloud_firestore.dart';

class Subchapter {
  const Subchapter({
    required this.id,
    required this.number,
    required this.title,
    required this.order,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String number;
  final String title;
  final int order;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isActive => status == 'active';

  factory Subchapter.fromMap(String id, Map<String, dynamic> data) {
    return Subchapter(
      id: id,
      number: (data['number'] ?? '').toString(),
      title: (data['title'] ?? 'Untitled subchapter').toString(),
      order: (data['order'] as num?)?.toInt() ?? 0,
      status: (data['status'] ?? 'draft').toString(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
