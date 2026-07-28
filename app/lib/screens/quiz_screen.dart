import 'package:flutter/material.dart';

import '../models/chapter.dart';
import '../models/quiz_muffin_context.dart';
import '../models/quiz_question.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({
    required this.chapter,
    required this.subjectId,
    required this.subjectTitle,
    required this.title,
    required this.questionsFuture,
    this.onComplete,
    super.key,
  });

  final Chapter chapter;
  final String subjectId;
  final String subjectTitle;
  final String title;
  final Future<List<QuizQuestion>> questionsFuture;
  final ValueChanged<QuizResult>? onComplete;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late Future<List<QuizQuestion>> _questionsFuture;
  final Map<String, int> _selectedAnswers = {};
  final _scrollController = ScrollController();
  int _questionIndex = 0;
  QuizResult? _result;
  bool _reviewing = false;
  bool _muffinSheetOpen = false;

  @override
  void initState() {
    super.initState();
    _questionsFuture = widget.questionsFuture;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _selectAnswer(QuizQuestion question, int optionIndex) {
    if (_result != null) return;
    setState(() => _selectedAnswers[question.id] = optionIndex);
  }

  void _previous() {
    if (_questionIndex == 0) return;
    _closeMuffinSheet();
    setState(() => _questionIndex -= 1);
    _scrollController.jumpTo(0);
  }

  void _next(int totalQuestions) {
    if (_questionIndex >= totalQuestions - 1) return;
    _closeMuffinSheet();
    setState(() => _questionIndex += 1);
    _scrollController.jumpTo(0);
  }

  void _closeMuffinSheet() {
    if (!_muffinSheetOpen || !mounted) return;
    Navigator.of(context).pop();
    _muffinSheetOpen = false;
  }

  Future<void> _showMuffin(QuizMuffinContext muffinContext) async {
    _muffinSheetOpen = true;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _MuffinGuidanceSheet(muffinContext: muffinContext),
    );
    if (!mounted) return;
    _muffinSheetOpen = false;
  }

  Future<void> _confirmSubmit(List<QuizQuestion> questions) async {
    final answered = questions
        .where((question) => _selectedAnswers.containsKey(question.id))
        .length;
    final unanswered = questions.length - answered;
    final shouldSubmit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit Quiz?'),
        content: Text(
          'You have answered $answered of ${questions.length} questions.\n'
          '${_unansweredSentence(unanswered)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Submit Quiz'),
          ),
        ],
      ),
    );
    if (shouldSubmit != true) return;
    final result = QuizResult.calculate(questions, _selectedAnswers);
    widget.onComplete?.call(result);
    if (!mounted) return;
    setState(() {
      _result = result;
      _reviewing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        title: Text(widget.chapter.title),
      ),
      body: SafeArea(
        child: FutureBuilder<List<QuizQuestion>>(
          future: _questionsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _QuizState(
                icon: Icons.hourglass_empty_rounded,
                title: 'Loading quiz',
                message: 'Getting the questions ready.',
              );
            }
            if (snapshot.hasError) {
              return const _QuizState(
                icon: Icons.cloud_off_rounded,
                title: 'Quiz could not load',
                message: 'Please try again in a moment.',
              );
            }

            final questions = snapshot.data ?? const <QuizQuestion>[];
            if (questions.isEmpty) {
              return const _QuizState(
                icon: Icons.track_changes_rounded,
                title: 'Quiz questions coming soon',
                message:
                    'This chapter does not have active quiz questions yet.',
              );
            }
            final validQuestions =
                questions.where((question) => question.isValid).toList();
            if (validQuestions.isEmpty) {
              return const _QuizState(
                icon: Icons.info_outline_rounded,
                title: 'Quiz needs a quick fix',
                message:
                    'The questions are missing required answer data, so this quiz cannot start yet.',
              );
            }

            final result = _result;
            if (_reviewing && result != null) {
              return _ReviewView(
                questions: validQuestions,
                selectedAnswers: _selectedAnswers,
                onReturn: () => setState(() => _reviewing = false),
              );
            }
            if (result != null) {
              return _ResultsView(
                result: result,
                onReview: () => setState(() => _reviewing = true),
              );
            }

            final safeIndex =
                _questionIndex.clamp(0, validQuestions.length - 1);
            final question = validQuestions[safeIndex];
            final muffinContext = QuizMuffinContext.fromQuestion(
              subjectId: widget.subjectId,
              subjectTitle: widget.subjectTitle,
              chapterId: widget.chapter.id,
              chapterTitle: widget.chapter.title,
              question: question,
              questionNumber: safeIndex + 1,
              totalQuestions: validQuestions.length,
            );
            return _AttemptView(
              quizTitle: widget.title,
              scrollController: _scrollController,
              question: question,
              muffinContext: muffinContext,
              questionNumber: safeIndex + 1,
              totalQuestions: validQuestions.length,
              selectedAnswerIndex: _selectedAnswers[question.id],
              canGoPrevious: safeIndex > 0,
              isFinalQuestion: safeIndex == validQuestions.length - 1,
              onSelectAnswer: (index) => _selectAnswer(question, index),
              onPrevious: _previous,
              onNext: () => _next(validQuestions.length),
              onSubmit: () => _confirmSubmit(validQuestions),
              onAskMuffin: _showMuffin,
            );
          },
        ),
      ),
    );
  }
}

class QuizResult {
  const QuizResult({
    required this.correctCount,
    required this.incorrectCount,
    required this.unansweredCount,
    required this.totalQuestions,
  });

  final int correctCount;
  final int incorrectCount;
  final int unansweredCount;
  final int totalQuestions;

  int get percentage =>
      totalQuestions == 0 ? 0 : ((correctCount / totalQuestions) * 100).round();

  bool get passed => percentage >= 70;

  String get message {
    if (percentage >= 90) return 'Excellent work!';
    if (percentage >= 70) return 'Good job!';
    return 'Keep practising. You can improve!';
  }

  static QuizResult calculate(
    List<QuizQuestion> questions,
    Map<String, int> selectedAnswers,
  ) {
    var correct = 0;
    var incorrect = 0;
    var unanswered = 0;
    for (final question in questions) {
      final selected = selectedAnswers[question.id];
      if (selected == null) {
        unanswered += 1;
      } else if (selected == question.correctOptionIndex) {
        correct += 1;
      } else {
        incorrect += 1;
      }
    }
    return QuizResult(
      correctCount: correct,
      incorrectCount: incorrect,
      unansweredCount: unanswered,
      totalQuestions: questions.length,
    );
  }
}

class _AttemptView extends StatelessWidget {
  const _AttemptView({
    required this.quizTitle,
    required this.scrollController,
    required this.question,
    required this.muffinContext,
    required this.questionNumber,
    required this.totalQuestions,
    required this.selectedAnswerIndex,
    required this.canGoPrevious,
    required this.isFinalQuestion,
    required this.onSelectAnswer,
    required this.onPrevious,
    required this.onNext,
    required this.onSubmit,
    required this.onAskMuffin,
  });

  final String quizTitle;
  final ScrollController scrollController;
  final QuizQuestion question;
  final QuizMuffinContext muffinContext;
  final int questionNumber;
  final int totalQuestions;
  final int? selectedAnswerIndex;
  final bool canGoPrevious;
  final bool isFinalQuestion;
  final ValueChanged<int> onSelectAnswer;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onSubmit;
  final ValueChanged<QuizMuffinContext> onAskMuffin;

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      children: [
        Text(quizTitle, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          'Question $questionNumber of $totalQuestions',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: questionNumber / totalQuestions,
            minHeight: 8,
            backgroundColor: const Color(0xFFE2E8E3),
          ),
        ),
        const SizedBox(height: 22),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Text(
              question.question,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(height: 1.35),
            ),
          ),
        ),
        const SizedBox(height: 14),
        for (var index = 0; index < question.options.length; index++) ...[
          _QuizOption(
            label: optionLabel(index),
            text: question.options[index],
            selected: selectedAnswerIndex == index,
            onTap: () => onSelectAnswer(index),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 14),
        _MuffinAssistSection(
          muffinContext: muffinContext,
          onAskMuffin: onAskMuffin,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: canGoPrevious ? onPrevious : null,
                child: const Text('Previous'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: isFinalQuestion ? onSubmit : onNext,
                child: Text(isFinalQuestion ? 'Submit Quiz' : 'Next'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuizOption extends StatelessWidget {
  const _QuizOption({
    required this.label,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFE5EEE8) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected ? const Color(0xFF496A5A) : const Color(0xFFE2E8E3),
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF496A5A)
                      : const Color(0xFFF1F4F0),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected ? Colors.white : const Color(0xFF496A5A),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MuffinAssistSection extends StatelessWidget {
  const _MuffinAssistSection({
    required this.muffinContext,
    required this.onAskMuffin,
  });

  final QuizMuffinContext muffinContext;
  final ValueChanged<QuizMuffinContext> onAskMuffin;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Ask Muffin for quiz guidance',
      child: Card(
        color: const Color(0xFFF6F8F5),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Need a little help?',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton.icon(
                onPressed: () => onAskMuffin(muffinContext),
                icon: const Icon(Icons.psychology_rounded),
                label: const Text('Ask Muffin'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MuffinGuidanceSheet extends StatefulWidget {
  const _MuffinGuidanceSheet({required this.muffinContext});

  final QuizMuffinContext muffinContext;

  @override
  State<_MuffinGuidanceSheet> createState() => _MuffinGuidanceSheetState();
}

class _MuffinGuidanceSheetState extends State<_MuffinGuidanceSheet> {
  static const _defaultMessage =
      'Muffin guidance is being prepared.\nSoon, I will help you think through the question without giving away the answer.';
  String _message = _defaultMessage;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Semantics(
        label:
            'Muffin guidance for question ${widget.muffinContext.questionNumber} of ${widget.muffinContext.totalQuestions}',
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            4,
            20,
            20 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5EEE8),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.psychology_rounded,
                      color: Color(0xFF496A5A),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Muffin',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'I can guide you without revealing the answer.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _MuffinGuidanceAction(
                label: 'Give me a small hint',
                onPressed: () => _setMessage(
                  'Soon, Muffin will provide a gentle clue to help you begin.',
                ),
              ),
              _MuffinGuidanceAction(
                label: 'Explain the concept',
                onPressed: () => _setMessage(
                  'Soon, Muffin will explain the concept behind this question.',
                ),
              ),
              _MuffinGuidanceAction(
                label: 'Help me identify the pattern',
                onPressed: () => _setMessage(
                  'Soon, Muffin will guide you in finding the relationship between the values.',
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F8F5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8E3)),
                ),
                child: Text(_message),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _setMessage(String message) {
    setState(() => _message = message);
  }
}

class _MuffinGuidanceAction extends StatelessWidget {
  const _MuffinGuidanceAction({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: onPressed,
          child: Text(label),
        ),
      ),
    );
  }
}

class _ResultsView extends StatelessWidget {
  const _ResultsView({required this.result, required this.onReview});

  final QuizResult result;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 40),
      children: [
        Card(
          color: const Color(0xFFE5EEE8),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                Icon(
                  result.passed
                      ? Icons.check_circle_rounded
                      : Icons.auto_stories_rounded,
                  size: 54,
                  color: const Color(0xFF496A5A),
                ),
                const SizedBox(height: 18),
                Text(
                  'Quiz Complete',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  '${result.correctCount} / ${result.totalQuestions}',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  '${result.percentage}%',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                _ResultLine(label: 'Correct', value: result.correctCount),
                _ResultLine(label: 'Incorrect', value: result.incorrectCount),
                _ResultLine(label: 'Unanswered', value: result.unansweredCount),
                const SizedBox(height: 12),
                _ResultStatus(passed: result.passed),
                const SizedBox(height: 14),
                Text(result.message, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: onReview,
          child: const Text('Review Answers'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Return to Chapter'),
        ),
      ],
    );
  }
}

class _ResultLine extends StatelessWidget {
  const _ResultLine({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value.toString(),
              style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _ResultStatus extends StatelessWidget {
  const _ResultStatus({required this.passed});

  final bool passed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        passed ? 'Pass' : 'Needs Revision',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _ReviewView extends StatelessWidget {
  const _ReviewView({
    required this.questions,
    required this.selectedAnswers,
    required this.onReturn,
  });

  final List<QuizQuestion> questions;
  final Map<String, int> selectedAnswers;
  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      children: [
        Text('Review Answers',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 18),
        for (var index = 0; index < questions.length; index++) ...[
          _ReviewCard(
            number: index + 1,
            question: questions[index],
            selectedAnswerIndex: selectedAnswers[questions[index].id],
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: onReturn,
          child: const Text('Back to Results'),
        ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.number,
    required this.question,
    required this.selectedAnswerIndex,
  });

  final int number;
  final QuizQuestion question;
  final int? selectedAnswerIndex;

  @override
  Widget build(BuildContext context) {
    final correctIndex = question.correctOptionIndex;
    final status = selectedAnswerIndex == null
        ? 'Unanswered'
        : selectedAnswerIndex == correctIndex
            ? 'Correct'
            : 'Incorrect';
    final selectedAnswer = selectedAnswerIndex == null
        ? 'No answer selected'
        : '${optionLabel(selectedAnswerIndex!)}. ${question.options[selectedAnswerIndex!]}';
    final correctAnswer =
        '${optionLabel(correctIndex)}. ${question.options[correctIndex]}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Question $number',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(question.question,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _ReviewRow(label: 'Status', value: status),
            _ReviewRow(label: 'Student answer', value: selectedAnswer),
            _ReviewRow(label: 'Correct answer', value: correctAnswer),
            if (question.explanation.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Explanation',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(question.explanation),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Text('$label: $value'),
    );
  }
}

class _QuizState extends StatelessWidget {
  const _QuizState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 48),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String optionLabel(int index) => ['A', 'B', 'C', 'D'][index];

String _unansweredSentence(int unanswered) {
  if (unanswered == 0) return 'All questions have an answer.';
  if (unanswered == 1) return 'One question is still unanswered.';
  return '$unanswered questions are still unanswered.';
}
