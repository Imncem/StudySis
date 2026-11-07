import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../config/content_paths.dart';
import '../config/curriculum_structure.dart';
import '../models/chapter.dart';
import '../models/curriculum_topic.dart';
import '../models/flashcard.dart';
import '../models/learning_content.dart';
import '../models/learning_continue_context.dart';
import '../models/learning_location.dart';
import '../models/learning_module.dart';
import '../models/learning_module_sequence.dart';
import '../models/note_section.dart';
import '../models/practice_question.dart';
import '../models/quiz_question.dart';
import '../models/review_item.dart';
import '../models/subchapter.dart';
import '../models/chapter_progress.dart';
import '../services/subject_readiness_service.dart';

class LearningRepository {
  LearningRepository({
    FirebaseFirestore? firestore,
    SubjectReadinessService? subjectReadinessService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _subjectReadinessService =
            subjectReadinessService ?? RemoteSubjectReadinessService();

  final FirebaseFirestore _firestore;
  final SubjectReadinessService _subjectReadinessService;

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

  Future<List<LearningLocation>> getActiveLearningLocations() async {
    final subjects = await _firestore
        .collection(ContentPaths.subjects)
        .orderBy('order')
        .get();
    final locations = <LearningLocation>[];

    for (final subjectDocument in subjects.docs) {
      final subjectId = subjectDocument.id;
      final structure = CurriculumStructure.forSubject(subjectId);
      final subjectName =
          (subjectDocument.data()['displayName'] ?? subjectId).toString();
      final chapters = await getActiveChapters(subjectId);

      for (final chapter in chapters) {
        if (structure.usesTopics) {
          final topics = await getActiveTopics(
            subjectId: subjectId,
            sectionId: chapter.id,
          );
          for (final topic in topics) {
            locations.add(LearningLocation(
              subjectId: subjectId,
              subjectName: subjectName,
              parentKind: 'topic',
              parentId: topic.id,
              parentTitle: topic.title,
              parentNumber: '${topic.order}',
              parentOrder: topic.order,
              structureLabel: 'Topic',
              containerKind: 'section',
              containerId: chapter.id,
              containerTitle: chapter.title,
              containerNumber: '${chapter.chapterNumber}',
            ));
          }
          continue;
        }

        if (structure.usesSubchapters) {
          final subchapters = await getActiveSubchapters(
            subjectId: subjectId,
            chapterId: chapter.id,
          );
          for (final subchapter in subchapters) {
            locations.add(LearningLocation(
              subjectId: subjectId,
              subjectName: subjectName,
              parentKind: 'subchapter',
              parentId: subchapter.id,
              parentTitle: subchapter.title,
              parentNumber: subchapter.number,
              parentOrder: subchapter.order,
              structureLabel: 'Subchapter',
              containerKind: 'chapter',
              containerId: chapter.id,
              containerTitle: chapter.title,
              containerNumber: '${chapter.chapterNumber}',
            ));
          }
          continue;
        }

        locations.add(LearningLocation(
          subjectId: subjectId,
          subjectName: subjectName,
          parentKind: structure.parentKind,
          parentId: chapter.id,
          parentTitle: chapter.title,
          parentNumber: '${chapter.chapterNumber}',
          parentOrder: chapter.order,
          structureLabel: structure.labelSingular,
        ));
      }
    }

    return locations;
  }

  Future<LearningContinueContext?> getContinueLearningContext({
    required List<ChapterProgress> progress,
  }) async {
    final locations = prioritizeLearningLocations(
      locations: await getActiveLearningLocations(),
      progress: progress,
    );
    final progressByIdentity = {
      for (final item in progress) item.identityKey: item,
    };
    for (final location in locations) {
      final modules = await getActiveModules(
        LearningModuleParent.fromLocation(location),
      );
      final selectedModule = nextIncompleteLearningModule(
        modules: modules,
        progress: progressByIdentity[location.identityKey],
      );
      if (selectedModule != null) {
        return LearningContinueContext(
          location: location,
          modules: modules,
          initialModuleId: selectedModule.id,
        );
      }
    }
    return null;
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

  Future<List<CurriculumTopic>> getActiveTopics({
    required String subjectId,
    required String sectionId,
  }) async {
    final snapshot = await _firestore
        .collection(ContentPaths.topics(subjectId, sectionId))
        .where('status', isEqualTo: 'active')
        .get();
    final topics = snapshot.docs
        .map((item) => CurriculumTopic.fromMap(item.id, item.data()))
        .where((item) => item.isActive)
        .toList();
    topics.sort((left, right) => left.order.compareTo(right.order));
    return topics;
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
        .toList(growable: false);
    return sequenceActiveLearningModules(
      await _filterUsableAssessmentModules(
        LearningModuleParent.subchapter(
          subjectId: subjectId,
          chapterId: chapterId,
          subchapterId: subchapterId,
        ),
        items,
      ),
      parentLabel: '$subjectId/$chapterId/subchapters/$subchapterId',
    );
  }

  Future<List<LearningModule>> getActiveChapterModules({
    required String subjectId,
    required String chapterId,
  }) =>
      getActiveModules(
        LearningModuleParent.chapter(
          subjectId: subjectId,
          chapterId: chapterId,
        ),
      );

  Future<List<LearningModule>> getActiveTopicModules({
    required String subjectId,
    required String sectionId,
    required String topicId,
  }) =>
      getActiveModules(
        LearningModuleParent.topic(
          subjectId: subjectId,
          chapterId: sectionId,
          topicId: topicId,
        ),
      );

  Future<List<LearningModule>> getActiveModules(
    LearningModuleParent parent,
  ) async {
    final snapshot = await _firestore
        .collection(_moduleCollectionPath(parent))
        .where('status', isEqualTo: 'active')
        .get();
    final modules = snapshot.docs
        .map(
          (item) => LearningModule.fromMap(item.id, item.data()),
        )
        .toList(growable: false);
    return sequenceActiveLearningModules(
      await _filterUsableAssessmentModules(parent, modules),
      parentLabel: parent.diagnosticLabel,
    );
  }

  Future<LearningContent?> getNotesContentForModule({
    required LearningModuleParent parent,
    required String moduleId,
  }) async {
    final chapter = await getChapter(
      subjectId: parent.subjectId,
      chapterId: parent.chapterId,
    );
    if (chapter == null) return null;
    final moduleSnapshot =
        await _firestore.doc(_moduleDocumentPath(parent, moduleId)).get();
    final moduleData = moduleSnapshot.data();
    if (moduleData == null) return null;
    final module = LearningModule.fromMap(moduleSnapshot.id, moduleData);
    if (!module.isActive || module.type != 'notes') return null;
    final sections = await _loadLegacyNoteSections(
      module,
      _moduleContentPath(parent, moduleId, 'sections'),
    );
    return LearningContent(
      subjectId: parent.subjectId,
      subjectName: await getSubjectName(parent.subjectId),
      chapter: chapter,
      module: module,
      noteSections: sections,
    );
  }

  Future<List<Flashcard>> getModuleFlashcards({
    required LearningModuleParent parent,
    required String moduleId,
  }) async {
    final snapshot = await _firestore
        .collection(_moduleContentPath(parent, moduleId, 'cards'))
        .orderBy('order')
        .get();
    return snapshot.docs
        .map((item) => Flashcard.fromMap(item.id, item.data()))
        .where((item) => item.isActive)
        .toList(growable: false);
  }

  Future<List<PracticeQuestion>> getModulePractice({
    required LearningModuleParent parent,
    required String moduleId,
    bool includeLegacyUnassigned = false,
  }) async {
    final snapshot = await _firestore
        .collection(_practiceQuestionCollectionPath(parent))
        .orderBy('order')
        .get();
    return snapshot.docs
        .map((item) => PracticeQuestion.fromMap(item.id, item.data()))
        .where((item) =>
            item.isPublished &&
            (item.moduleId == moduleId ||
                (includeLegacyUnassigned && item.moduleId == null)))
        .toList(growable: false);
  }

  Future<List<QuizQuestion>> getModuleQuiz({
    required LearningModuleParent parent,
    required String moduleId,
  }) async {
    final snapshot = await _firestore
        .collection(_moduleContentPath(parent, moduleId, 'questions'))
        .orderBy('order')
        .get();
    return snapshot.docs
        .map((item) => QuizQuestion.fromMap(item.id, item.data()))
        .where((item) => item.isActive)
        .toList(growable: false);
  }

  Future<List<ReviewItem>> getModuleReview({
    required LearningModuleParent parent,
    required String moduleId,
  }) async {
    final snapshot = await _firestore
        .collection(_moduleContentPath(parent, moduleId, 'items'))
        .where('status', isEqualTo: 'active')
        .get();
    final items = snapshot.docs
        .map((item) => ReviewItem.fromMap(item.id, item.data()))
        .where((item) => item.isUsable)
        .toList(growable: true)
      ..sort((left, right) => left.order.compareTo(right.order));
    return items;
  }

  Future<List<LearningModule>> _filterUsableAssessmentModules(
    LearningModuleParent parent,
    List<LearningModule> modules,
  ) async {
    final assessmentPaths = <String>{
      for (final module in modules)
        if (module.type == 'test' || module.type == 'review')
          _moduleDocumentPath(parent, module.id),
    };
    Set<String> usableAssessmentPaths = const <String>{};
    if (assessmentPaths.isNotEmpty) {
      try {
        usableAssessmentPaths = await _subjectReadinessService
            .usableAssessmentModulePaths(assessmentPaths);
      } catch (error, stackTrace) {
        debugPrint(
          '[StudySis] Assessment module readiness unavailable; protected '
          'Test/Review modules will be omitted: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
    }
    return modules.where((module) {
      if (module.type != 'test' && module.type != 'review') return true;
      return usableAssessmentPaths.contains(
        _moduleDocumentPath(parent, module.id),
      );
    }).toList(growable: false);
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
    final sections = await _loadLegacyNoteSections(
      module,
      ContentPaths.subchapterModuleContent(
        subjectId,
        chapterId,
        subchapterId,
        moduleId,
        'sections',
      ),
    );
    return LearningContent(
      subjectId: subjectId,
      subjectName: await getSubjectName(subjectId),
      chapter: chapter,
      module: module,
      noteSections: sections,
    );
  }

  Future<LearningContent?> getTopicNotesContent({
    required String subjectId,
    required String sectionId,
    required String topicId,
    required String moduleId,
  }) async {
    final chapter = await getChapter(
      subjectId: subjectId,
      chapterId: sectionId,
    );
    if (chapter == null) return null;
    final topicSnapshot = await _firestore
        .doc('${ContentPaths.topics(subjectId, sectionId)}/$topicId')
        .get();
    if (!topicSnapshot.exists || topicSnapshot.data()?['status'] != 'active') {
      return null;
    }
    final moduleSnapshot = await _firestore
        .doc(ContentPaths.topicModule(
          subjectId,
          sectionId,
          topicId,
          moduleId,
        ))
        .get();
    final moduleData = moduleSnapshot.data();
    if (moduleData == null) return null;
    final module = LearningModule.fromMap(moduleSnapshot.id, moduleData);
    if (!module.isActive || module.type != 'notes') return null;
    final sections = await _loadLegacyNoteSections(
      module,
      ContentPaths.topicModuleContent(
        subjectId,
        sectionId,
        topicId,
        moduleId,
        'sections',
      ),
    );
    return LearningContent(
      subjectId: subjectId,
      subjectName: await getSubjectName(subjectId),
      chapter: chapter,
      module: module,
      noteSections: sections,
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
    return getModulePractice(
      parent: LearningModuleParent.subchapter(
        subjectId: subjectId,
        chapterId: chapterId,
        subchapterId: subchapterId,
      ),
      moduleId: moduleId,
    );
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
        final sections = await _loadLegacyNoteSections(
          module,
          ContentPaths.noteSections(subjectId, chapter.id, module.id),
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
          final sections = await _loadLegacyNoteSections(
            module,
            ContentPaths.noteSections(subjectId, chapter.id, module.id),
          );
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

  Future<List<NoteSection>> _loadLegacyNoteSections(
    LearningModule module,
    String collectionPath,
  ) async {
    if (isMeaningfulLessonContent(module.content)) return const [];
    final snapshot =
        await _firestore.collection(collectionPath).orderBy('order').get();
    return snapshot.docs
        .map((section) => NoteSection.fromMap(section.id, section.data()))
        .toList(growable: false);
  }

  String _moduleCollectionPath(LearningModuleParent parent) =>
      switch (parent.kind) {
        LearningModuleParentKind.chapter =>
          ContentPaths.modules(parent.subjectId, parent.chapterId),
        LearningModuleParentKind.subchapter => ContentPaths.subchapterModules(
            parent.subjectId,
            parent.chapterId,
            parent.subchapterId!,
          ),
        LearningModuleParentKind.topic => ContentPaths.topicModules(
            parent.subjectId,
            parent.chapterId,
            parent.topicId!,
          ),
      };

  String _moduleDocumentPath(
    LearningModuleParent parent,
    String moduleId,
  ) =>
      '${_moduleCollectionPath(parent)}/$moduleId';

  String _practiceQuestionCollectionPath(LearningModuleParent parent) =>
      switch (parent.kind) {
        LearningModuleParentKind.chapter => ContentPaths.practiceQuestions(
            parent.subjectId,
            parent.chapterId,
          ),
        LearningModuleParentKind.subchapter =>
          ContentPaths.subchapterPracticeQuestions(
            parent.subjectId,
            parent.chapterId,
            parent.subchapterId!,
          ),
        LearningModuleParentKind.topic => ContentPaths.topicPracticeQuestions(
            parent.subjectId,
            parent.chapterId,
            parent.topicId!,
          ),
      };

  String _moduleContentPath(
    LearningModuleParent parent,
    String moduleId,
    String collectionName,
  ) =>
      '${_moduleDocumentPath(parent, moduleId)}/$collectionName';
}
