import 'package:flutter/material.dart';

import '../models/chapter.dart';
import '../models/learning_content.dart';
import '../models/learning_location.dart';
import '../models/learning_module.dart';
import '../models/learning_module_sequence.dart';
import '../models/quiz_question.dart';
import '../repositories/learning_repository.dart';
import '../services/saved_flashcard_service.dart';
import '../widgets/learning_module_navigation.dart';
import '../widgets/learning_module_metadata.dart';
import 'flashcard_screen.dart';
import 'module_reader_screen.dart';
import 'practice_screen.dart';
import 'quiz_screen.dart';
import 'review_screen.dart';

class LearningModuleSequenceScreen extends StatefulWidget {
  const LearningModuleSequenceScreen({
    required this.subjectName,
    required this.chapter,
    required this.parent,
    required this.modules,
    required this.initialModuleId,
    this.parentTitle,
    this.repository,
    this.onNotesCompleted,
    this.onFlashcardCompleted,
    this.onPracticeCompleted,
    this.onQuizCompleted,
    this.onLocationNotesCompleted,
    this.onLocationFlashcardCompleted,
    this.onLocationPracticeCompleted,
    this.onLocationQuizCompleted,
    this.onLocationTestCompleted,
    this.onLoadTestQuestions,
    this.onLocationReviewCompleted,
    this.savedFlashcardService,
    super.key,
  });

  final String subjectName;
  final Chapter chapter;
  final LearningModuleParent parent;
  final List<LearningModule> modules;
  final String initialModuleId;
  final String? parentTitle;
  final LearningRepository? repository;
  final Future<void> Function(LearningModule module)? onNotesCompleted;
  final Future<void> Function(
    LearningModule module,
    String cardId,
    int totalCards,
  )? onFlashcardCompleted;
  final Future<void> Function(
    LearningModule module,
    PracticeResult result,
  )? onPracticeCompleted;
  final Future<void> Function(
    LearningModule module,
    QuizResult result,
  )? onQuizCompleted;
  final Future<void> Function(
    LearningLocation location,
    LearningModule module,
  )? onLocationNotesCompleted;
  final Future<void> Function(
    LearningLocation location,
    LearningModule module,
    String cardId,
    int totalCards,
  )? onLocationFlashcardCompleted;
  final Future<void> Function(
    LearningLocation location,
    LearningModule module,
    PracticeResult result,
  )? onLocationPracticeCompleted;
  final Future<void> Function(
    LearningLocation location,
    LearningModule module,
    QuizResult result,
  )? onLocationQuizCompleted;
  final Future<QuizResult> Function(
    LearningLocation location,
    LearningModule module,
    Map<String, int> answers,
  )? onLocationTestCompleted;
  final Future<List<QuizQuestion>> Function(
    LearningLocation location,
    LearningModule module,
  )? onLoadTestQuestions;
  final Future<void> Function(
    LearningLocation location,
    LearningModule module,
  )? onLocationReviewCompleted;
  final SavedFlashcardService? savedFlashcardService;

  @override
  State<LearningModuleSequenceScreen> createState() =>
      _LearningModuleSequenceScreenState();
}

class _LearningModuleSequenceScreenState
    extends State<LearningModuleSequenceScreen> {
  late final LearningRepository _repository;
  late final List<LearningModule> _modules;
  late int _currentIndex;
  final Set<String> _completedFlashcardIds = <String>{};
  final Set<String> _completedNotes = <String>{};

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? LearningRepository();
    _modules = sequenceActiveLearningModules(
      widget.modules,
      parentLabel: widget.parent.diagnosticLabel,
    );
    final initialIndex =
        _modules.indexWhere((module) => module.id == widget.initialModuleId);
    _currentIndex = initialIndex < 0 ? 0 : initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    if (_modules.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Learning modules are being prepared.')),
      );
    }
    final module = _modules[_currentIndex];
    final navigation = LearningModuleNavigation(
      currentIndex: _currentIndex,
      totalModules: _modules.length,
      onPrevious: _currentIndex > 0 ? () => _moveTo(_currentIndex - 1) : null,
      onNext: _currentIndex < _modules.length - 1
          ? () => _moveTo(_currentIndex + 1)
          : null,
      onFinish: () => Navigator.of(context).pop(),
    );

    return PopScope<void>(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _completeNotes(module);
      },
      child: KeyedSubtree(
        key: ValueKey('module-${module.id}'),
        child: switch (module.type) {
          'notes' => _buildNotes(module, navigation),
          'flashcards' => FlashcardScreen(
              subjectId: widget.parent.subjectId,
              subjectName: widget.subjectName,
              chapter: widget.chapter,
              repository: _repository,
              savedFlashcardService: widget.savedFlashcardService,
              initialCompletedCardIds: _completedFlashcardIds,
              cardsFuture: _repository.getModuleFlashcards(
                parent: widget.parent,
                moduleId: module.id,
              ),
              onCardCompleted: (cardId) async {
                _completedFlashcardIds.add(cardId);
                final cards = await _repository.getModuleFlashcards(
                  parent: widget.parent,
                  moduleId: module.id,
                );
                await widget.onFlashcardCompleted?.call(
                  module,
                  cardId,
                  cards.length,
                );
                await widget.onLocationFlashcardCompleted?.call(
                  widget.parent.location,
                  module,
                  cardId,
                  cards.length,
                );
              },
              moduleNavigation: navigation,
              moduleMetadata: LearningModuleMetadata(module: module),
            ),
          'practice' => PracticeScreen(
              title: module.title,
              subjectId: widget.parent.subjectId,
              subjectTitle: widget.subjectName,
              chapterId: widget.parent.chapterId,
              chapterTitle: widget.parentTitle ?? widget.chapter.title,
              questionsFuture: _repository.getModulePractice(
                parent: widget.parent,
                moduleId: module.id,
                includeLegacyUnassigned: widget.modules
                        .where((item) => item.type == 'practice')
                        .length ==
                    1,
              ),
              onComplete: (result) async {
                await widget.onPracticeCompleted?.call(module, result);
                await widget.onLocationPracticeCompleted?.call(
                  widget.parent.location,
                  module,
                  result,
                );
              },
              moduleNavigation: navigation,
              moduleMetadata: LearningModuleMetadata(module: module),
            ),
          'quiz' => QuizScreen(
              chapter: widget.chapter,
              subjectId: widget.parent.subjectId,
              subjectTitle: widget.subjectName,
              title: module.title,
              questionsFuture: _repository.getModuleQuiz(
                parent: widget.parent,
                moduleId: module.id,
              ),
              onComplete: (result) async {
                await widget.onQuizCompleted?.call(module, result);
                await widget.onLocationQuizCompleted?.call(
                  widget.parent.location,
                  module,
                  result,
                );
              },
              moduleNavigation: navigation,
              moduleMetadata: LearningModuleMetadata(module: module),
            ),
          'test' => QuizScreen(
              chapter: widget.chapter,
              subjectId: widget.parent.subjectId,
              subjectTitle: widget.subjectName,
              title: module.title,
              assessmentLabel: 'Test',
              requireStart: true,
              questionsFuture: widget.onLoadTestQuestions?.call(
                    widget.parent.location,
                    module,
                  ) ??
                  Future<List<QuizQuestion>>.error(
                    StateError('Secure Test question loader is unavailable.'),
                  ),
              onSubmitAnswers: (answers) async {
                final callback = widget.onLocationTestCompleted;
                if (callback == null) {
                  final questions = await _repository.getModuleQuiz(
                    parent: widget.parent,
                    moduleId: module.id,
                  );
                  return QuizResult.calculate(questions, answers);
                }
                return callback(widget.parent.location, module, answers);
              },
              moduleNavigation: navigation,
              moduleMetadata: LearningModuleMetadata(module: module),
            ),
          'review' => ReviewScreen(
              title: module.title,
              itemsFuture: _repository.getModuleReview(
                parent: widget.parent,
                moduleId: module.id,
              ),
              onComplete: () async {
                await widget.onLocationReviewCompleted?.call(
                  widget.parent.location,
                  module,
                );
              },
              moduleNavigation: navigation,
              moduleMetadata: LearningModuleMetadata(module: module),
            ),
          _ => Scaffold(
              body: const Center(
                child: Text('This module type is being prepared.'),
              ),
              bottomNavigationBar: navigation,
            ),
        },
      ),
    );
  }

  Widget _buildNotes(
    LearningModule module,
    Widget navigation,
  ) {
    return FutureBuilder<LearningContent?>(
      future: _repository.getNotesContentForModule(
        parent: widget.parent,
        moduleId: module.id,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final content = snapshot.data;
        if (snapshot.hasError || content == null) {
          return Scaffold(
            appBar: AppBar(title: Text(module.title)),
            body: const Center(child: Text('This lesson could not be loaded.')),
            bottomNavigationBar: navigation,
          );
        }
        return ModuleReaderScreen(
          learningContent: content,
          moduleNavigation: navigation,
        );
      },
    );
  }

  Future<void> _moveTo(int index) async {
    final current = _modules[_currentIndex];
    if (index > _currentIndex && current.type == 'notes') {
      await _completeNotes(current);
    }
    if (!mounted) return;
    setState(() => _currentIndex = index);
  }

  Future<void> _completeNotes(LearningModule module) async {
    if (module.type != 'notes' || !_completedNotes.add(module.id)) return;
    await widget.onNotesCompleted?.call(module);
    await widget.onLocationNotesCompleted?.call(
      widget.parent.location,
      module,
    );
  }
}
