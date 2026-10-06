import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../config/content_paths.dart';
import '../models/chapter.dart';
import '../models/flashcard.dart';
import '../models/learning_content.dart';
import '../models/learning_module.dart';
import '../models/note_section.dart';
import '../models/practice_question.dart';
import '../models/quiz_question.dart';
import '../models/subchapter.dart';

class LearningRepository {
  LearningRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<String> getSubjectName(String subjectId) async {
    final snapshot =
        await _firestore.doc(ContentPaths.subject(subjectId)).get();
    return (snapshot.data()?['displayName'] ?? subjectId).toString();
  }

  Future<Chapter?> getChapter({
    required String subjectId,
    required String chapterId,
  }) async {
    final snapshot = await _firestore
        .doc('${ContentPaths.chapters(subjectId)}/$chapterId')
        .get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null) return null;
    final chapter = Chapter.fromMap(snapshot.id, data);
    return chapter.isActive ? chapter : null;
  }

  Future<Flashcard?> getFlashcard({
    required String subjectId,
    required String chapterId,
    required String cardId,
  }) async {
    final snapshot = await _firestore
        .doc('${ContentPaths.flashcardCards(subjectId, chapterId)}/$cardId')
        .get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null) return null;
    final card = Flashcard.fromMap(snapshot.id, data);
    return card.isActive ? card : null;
  }

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

  Future<List<Subchapter>> getActiveSubchapters({
    required String subjectId,
    required String chapterId,
  }) async {
    final snapshot = await _firestore
        .collection(ContentPaths.subchapters(subjectId, chapterId))
        .where('status', isEqualTo: 'active')
        .get();
    final items = snapshot.docs
        .map((item) => Subchapter.fromMap(item.id, item.data()))
        .where((item) => item.isActive)
        .toList(growable: false);
    items.sort((left, right) => left.order.compareTo(right.order));
    return items;
  }

  Future<List<LearningModule>> getActiveSubchapterModules({
    required String subjectId,
    required String chapterId,
    required String subchapterId,
  }) async {
    final snapshot = await _firestore
        .collection(ContentPaths.subchapterModules(
          subjectId,
          chapterId,
          subchapterId,
        ))
        .where('status', isEqualTo: 'active')
        .get();
    final items = snapshot.docs
        .map((item) => LearningModule.fromMap(item.id, item.data()))
        .where((item) => item.isActive)
        .toList(growable: false);
    items.sort((left, right) => left.order.compareTo(right.order));
    return items;
  }

  Future<LearningContent?> getSubchapterNotesContent({
    required String subjectId,
    required String chapterId,
    required String subchapterId,
    required String moduleId,
  }) async {
    final chapter =
        await getChapter(subjectId: subjectId, chapterId: chapterId);
    if (chapter == null) return null;
    final moduleSnapshot = await _firestore
        .doc(ContentPaths.subchapterModule(
          subjectId,
          chapterId,
          subchapterId,
          moduleId,
        ))
        .get();
    final moduleData = moduleSnapshot.data();
    if (moduleData == null) return null;
    final module = LearningModule.fromMap(moduleSnapshot.id, moduleData);
    if (!module.isActive || module.type != 'notes') return null;
    final sectionSnapshot = await _firestore
        .collection(ContentPaths.subchapterModuleContent(
          subjectId,
          chapterId,
          subchapterId,
          moduleId,
          'sections',
        ))
        .orderBy('order')
        .get();
    return LearningContent(
      subjectId: subjectId,
      subjectName: await getSubjectName(subjectId),
      chapter: chapter,
      module: module,
      noteSections: sectionSnapshot.docs
          .map((item) => NoteSection.fromMap(item.id, item.data()))
          .toList(growable: false),
    );
  }

  Future<List<Flashcard>> getActiveSubchapterFlashcards({
    required String subjectId,
    required String chapterId,
    required String subchapterId,
    required String moduleId,
  }) async {
    final snapshot = await _firestore
        .collection(ContentPaths.subchapterModuleContent(
          subjectId,
          chapterId,
          subchapterId,
          moduleId,
          'cards',
        ))
        .orderBy('order')
        .get();
    return snapshot.docs
        .map((item) => Flashcard.fromMap(item.id, item.data()))
        .where((item) => item.isActive)
        .toList(growable: false);
  }

  Future<List<PracticeQuestion>> getActiveSubchapterPractice({
    required String subjectId,
    required String chapterId,
    required String subchapterId,
    required String moduleId,
  }) async {
    final snapshot = await _firestore
        .collection(ContentPaths.subchapterModuleContent(
          subjectId,
          chapterId,
          subchapterId,
          moduleId,
          'items',
        ))
        .orderBy('order')
        .get();
    return snapshot.docs
        .map((item) => PracticeQuestion.fromMap(item.id, item.data()))
        .where((item) => item.isPublished)
        .toList(growable: false);
  }

  Future<List<QuizQuestion>> getActiveSubchapterQuiz({
    required String subjectId,
    required String chapterId,
    required String subchapterId,
    required String moduleId,
  }) async {
    final snapshot = await _firestore
        .collection(ContentPaths.subchapterModuleContent(
          subjectId,
          chapterId,
          subchapterId,
          moduleId,
          'questions',
        ))
        .orderBy('order')
        .get();
    return snapshot.docs
        .map((item) => QuizQuestion.fromMap(item.id, item.data()))
        .where((item) => item.isActive)
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
          subjectId: subjectId,
          subjectName: subjectName,
          chapter: chapter,
          module: module,
          noteSections: sections,
        );
      }
    }
    return null;
  }

  Future<List<PracticeQuestion>> getPublishedPracticeQuestions({
    required String subjectId,
    required String chapterId,
  }) async {
    final questionSnapshot = await _firestore
        .collection(ContentPaths.practiceQuestions(subjectId, chapterId))
        .orderBy('order')
        .get();
    final questions = questionSnapshot.docs
        .map((question) => PracticeQuestion.fromMap(
              question.id,
              question.data(),
            ))
        .where((question) => question.isPublished)
        .toList(growable: false);
    debugPrint(
      '[StudySis] Published practice questions: subject=$subjectId, '
      'chapter=$chapterId, count=${questions.length}',
    );
    return questions;
  }

  Future<List<QuizQuestion>> getActiveQuizQuestions({
    required String subjectId,
    required String chapterId,
  }) async {
    final questionSnapshot = await _firestore
        .collection(ContentPaths.quizQuestions(subjectId, chapterId))
        .orderBy('order')
        .get();
    final questions = questionSnapshot.docs
        .map((question) => QuizQuestion.fromMap(
              question.id,
              question.data(),
            ))
        .where((question) => question.isActive)
        .toList(growable: false);
    debugPrint(
      '[StudySis] Active quiz questions: subject=$subjectId, '
      'chapter=$chapterId, count=${questions.length}',
    );
    return questions;
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
            subjectId: subjectId,
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
