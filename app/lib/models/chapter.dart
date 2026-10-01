import 'package:cloud_firestore/cloud_firestore.dart';

class Chapter {
  const Chapter({
    required this.id,
    required this.chapterNumber,
    required this.title,
    required this.textbookChapterTitle,
    required this.learningObjectives,
    required this.estimatedMinutes,
    required this.status,
    required this.order,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final int chapterNumber;
  final String title;
  final String textbookChapterTitle;
  final List<String> learningObjectives;
  final int estimatedMinutes;
  final String status;
  final int order;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isActive => status == 'active';

  factory Chapter.fromMap(String id, Map<String, dynamic> data) {
    return Chapter(
      id: id,
      chapterNumber: (data['chapterNumber'] as num?)?.toInt() ?? 0,
      title: (data['title'] ?? 'Untitled chapter').toString(),
      textbookChapterTitle: (data['textbookChapterTitle'] ?? '').toString(),
      learningObjectives: (data['learningObjectives'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(growable: false),
      estimatedMinutes: (data['estimatedMinutes'] as num?)?.toInt() ?? 0,
      status: (data['status'] ?? 'draft').toString(),
      order: (data['order'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
