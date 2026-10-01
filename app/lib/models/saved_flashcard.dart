import 'package:cloud_firestore/cloud_firestore.dart';

class SavedFlashcardRef {
  const SavedFlashcardRef({
    required this.subjectId,
    required this.chapterId,
    required this.cardId,
    this.savedAt,
  });

  final String subjectId;
  final String chapterId;
  final String cardId;
  final DateTime? savedAt;

  String get documentId => documentIdFor(
        subjectId: subjectId,
        chapterId: chapterId,
        cardId: cardId,
      );

  static String documentIdFor({
    required String subjectId,
    required String chapterId,
    required String cardId,
  }) {
    return '${_safeId(subjectId)}_${_safeId(chapterId)}_${_safeId(cardId)}';
  }

  static String _safeId(String value) {
    return value.trim().replaceAll(RegExp(r'[^A-Za-z0-9-]'), '-');
  }

  factory SavedFlashcardRef.fromMap(Map<String, dynamic> data) {
    return SavedFlashcardRef(
      subjectId: (data['subjectId'] ?? '').toString(),
      chapterId: (data['chapterId'] ?? '').toString(),
      cardId: (data['cardId'] ?? '').toString(),
      savedAt: (data['savedAt'] as Timestamp?)?.toDate(),
    );
  }
}
