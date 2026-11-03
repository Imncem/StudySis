import 'package:cloud_firestore/cloud_firestore.dart';

class LearningModule {
  const LearningModule({
    required this.id,
    required this.title,
    required this.type,
    required this.content,
    required this.summary,
    required this.estimatedMinutes,
    required this.difficulty,
    required this.order,
    required this.status,
    this.hasValidOrder = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String type;
  final String content;
  final String summary;
  final int estimatedMinutes;
  final String difficulty;
  final int order;
  final String status;
  final bool hasValidOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isActive => status == 'active';

  String get typeLabel => type
      .split('_')
      .map((part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');

  factory LearningModule.fromMap(String id, Map<String, dynamic> data) {
    final rawOrder = data['order'];
    final parsedOrder = rawOrder is num ? rawOrder.toInt() : 0;
    return LearningModule(
      id: id,
      title: (data['title'] ?? 'Untitled module').toString(),
      type: (data['type'] ?? 'notes').toString(),
      content: (data['content'] ?? '').toString(),
      summary: (data['summary'] ?? '').toString(),
      estimatedMinutes: (data['estimatedMinutes'] as num?)?.toInt() ?? 0,
      difficulty: (data['difficulty'] ?? 'medium').toString(),
      order: parsedOrder,
      status: (data['status'] ?? 'draft').toString(),
      hasValidOrder: rawOrder is num && parsedOrder >= 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
