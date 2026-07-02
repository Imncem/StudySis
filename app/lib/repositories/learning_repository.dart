import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../config/content_paths.dart';
import '../models/chapter.dart';
import '../models/learning_content.dart';
import '../models/learning_module.dart';

class LearningRepository {
  LearningRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<LearningContent?> getFirstAvailableContent() async {
    const subjectId = ContentPaths.mathematicsSubjectId;
    final subjectSnapshot =
        await _firestore.doc(ContentPaths.subject(subjectId)).get();
    final subjectName =
        (subjectSnapshot.data()?['displayName'] ?? 'Mathematics').toString();

    final chapterSnapshot = await _firestore
        .collection(ContentPaths.chapters(subjectId))
        .orderBy('order')
        .get();

    for (final chapterDocument in chapterSnapshot.docs) {
      final chapter =
          Chapter.fromMap(chapterDocument.id, chapterDocument.data());
      if (!chapter.isActive) continue;

      final moduleSnapshot = await _firestore
          .collection(ContentPaths.modules(subjectId, chapter.id))
          .orderBy('order')
          .get();
      for (final moduleDocument in moduleSnapshot.docs) {
        final module =
            LearningModule.fromMap(moduleDocument.id, moduleDocument.data());
        if (module.isActive) {
          debugPrint(
            '[StudySis] Continue content: subject=$subjectId, '
            'chapter=${chapter.id}, module=${module.id}',
          );
          return LearningContent(
            subjectName: subjectName,
            chapter: chapter,
            module: module,
          );
        }
      }
    }

    debugPrint('[StudySis] No active Mathematics learning module found.');
    return null;
  }
}
