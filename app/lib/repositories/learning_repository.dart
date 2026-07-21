import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../config/content_paths.dart';
import '../models/chapter.dart';
import '../models/flashcard.dart';
import '../models/learning_content.dart';
import '../models/learning_module.dart';
import '../models/note_section.dart';

class LearningRepository {
  LearningRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<List<Chapter>> getActiveChapters(String subjectId) async {
    final chapterSnapshot = await _firestore
        .collection(ContentPaths.chapters(subjectId))
        .orderBy('order')
        .get();
    return chapterSnapshot.docs
        .map((chapter) => Chapter.fromMap(chapter.id, chapter.data()))
        .where((chapter) => chapter.isActive)
        .toList(growable: false);
  }

  Future<List<Flashcard>> getActiveFlashcards(
    String chapterId, {
    String subjectId = ContentPaths.mathematicsSubjectId,
  }) async {
    final moduleSnapshot = await _firestore
        .doc(ContentPaths.module(subjectId, chapterId, 'flashcards'))
        .get();
    final moduleData = moduleSnapshot.data();
    if (!moduleSnapshot.exists || moduleData?['status'] != 'active') {
      debugPrint(
        '[StudySis] Flashcards module is not active for chapter=$chapterId.',
      );
      return const [];
    }

    final cardSnapshot = await _firestore
        .collection(ContentPaths.flashcardCards(subjectId, chapterId))
        .orderBy('order')
        .get();
    final cards = cardSnapshot.docs
        .map((card) => Flashcard.fromMap(card.id, card.data()))
        .where((card) => card.isActive)
        .toList(growable: false);
    debugPrint(
      '[StudySis] Active flashcards: chapter=$chapterId, count=${cards.length}',
    );
    return cards;
  }

  Future<LearningContent?> getChapterNotesContent({
    required String subjectId,
    required String chapterId,
  }) async {
    final subjectSnapshot =
        await _firestore.doc(ContentPaths.subject(subjectId)).get();
    final subjectName =
        (subjectSnapshot.data()?['displayName'] ?? 'Mathematics').toString();

    final chapterSnapshot = await _firestore
        .doc('${ContentPaths.chapters(subjectId)}/$chapterId')
        .get();
    final chapterData = chapterSnapshot.data();
    if (!chapterSnapshot.exists || chapterData == null) return null;
    final chapter = Chapter.fromMap(chapterSnapshot.id, chapterData);
    if (!chapter.isActive) return null;

    final moduleSnapshot = await _firestore
        .collection(ContentPaths.modules(subjectId, chapter.id))
        .orderBy('order')
        .get();
    for (final moduleDocument in moduleSnapshot.docs) {
      final module =
          LearningModule.fromMap(moduleDocument.id, moduleDocument.data());
      if (module.isActive && module.type == 'notes') {
        final sectionSnapshot = await _firestore
            .collection(
              ContentPaths.noteSections(subjectId, chapter.id, module.id),
            )
            .orderBy('order')
            .get();
        final sections = sectionSnapshot.docs
            .map((section) => NoteSection.fromMap(section.id, section.data()))
            .toList(growable: false);
        return LearningContent(
          subjectName: subjectName,
          chapter: chapter,
          module: module,
          noteSections: sections,
        );
      }
    }
    return null;
  }

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
        if (module.isActive && module.type == 'notes') {
          final sectionSnapshot = await _firestore
              .collection(
                ContentPaths.noteSections(subjectId, chapter.id, module.id),
              )
              .orderBy('order')
              .get();
          final sections = sectionSnapshot.docs
              .map((section) => NoteSection.fromMap(section.id, section.data()))
              .toList(growable: false);
          debugPrint(
            '[StudySis] Continue content: subject=$subjectId, '
            'chapter=${chapter.id}, module=${module.id}, '
            'sections=${sections.length}',
          );
          return LearningContent(
            subjectName: subjectName,
            chapter: chapter,
            module: module,
            noteSections: sections,
          );
        }
      }
    }

    debugPrint('[StudySis] No active Mathematics notes module found.');
    return null;
  }
}
