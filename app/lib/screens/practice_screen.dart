import 'package:flutter/material.dart';

import '../models/chapter_progress.dart';
import '../models/practice_question.dart';

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({
    required this.title,
    required this.questionsFuture,
    this.onComplete,
    super.key,
  });

  final String title;
  final Future<List<PracticeQuestion>> questionsFuture;
  final ValueChanged<PracticeResult>? onComplete;

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  late Future<List<PracticeQuestion>> _questionsFuture;
  int _questionIndex = 0;
  int? _selectedAnswerIndex;
  bool _hasSubmitted = false;
  int _correctAnswers = 0;
  bool _isComplete = false;
  final _scrollController = ScrollController();

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

  void _selectAnswer(int index) {
    if (_hasSubmitted) return;
    setState(() => _selectedAnswerIndex = index);
  }

  void _submit(PracticeQuestion question) {
    if (_selectedAnswerIndex == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Choose an answer first.')),
        );
      return;
    }
    final isCorrect = _selectedAnswerIndex == question.correctAnswerIndex;
    setState(() {
      _hasSubmitted = true;
      if (isCorrect) _correctAnswers += 1;
    });
  }

  void _nextQuestion(int total) {
    if (_questionIndex >= total - 1) {
      final result = PracticeResult(
        correctAnswers: _correctAnswers,
        totalQuestions: total,
      );
      widget.onComplete?.call(result);
      setState(() => _isComplete = true);
      return;
    }
    setState(() {
      _questionIndex += 1;
      _selectedAnswerIndex = null;
      _hasSubmitted = false;
    });
    _scrollController.jumpTo(0);
  }

  void _showHint(String hint) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hint', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              Text(hint, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        title: Text(widget.title),
      ),
      body: SafeArea(
        child: FutureBuilder<List<PracticeQuestion>>(
          future: _questionsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _PracticeState(
                icon: Icons.hourglass_empty_rounded,
                title: 'Loading practice',
                message: 'Getting the questions ready.',
              );
            }
            if (snapshot.hasError) {
              return const _PracticeState(
                icon: Icons.cloud_off_rounded,
                title: 'Practice could not load',
                message: 'Please try again in a moment.',
              );
            }

            final questions = snapshot.data ?? const <PracticeQuestion>[];
            if (questions.isEmpty) {
              return const _PracticeState(
                icon: Icons.edit_note_rounded,
                title: 'Practice questions coming soon',
                message: 'This chapter does not have practice questions yet.',
              );
            }

            final validQuestions =
                questions.where((question) => question.isValid).toList();
            if (validQuestions.isEmpty) {
              return const _PracticeState(
                icon: Icons.info_outline_rounded,
                title: 'Practice needs a quick fix',
                message:
                    'The questions are missing required answer data, so this practice cannot start yet.',
              );
            }

            if (_isComplete) {
              return _CompletionView(
                correctAnswers: _correctAnswers,
                totalQuestions: validQuestions.length,
              );
            }

            final safeIndex =
                _questionIndex.clamp(0, validQuestions.length - 1);
            final question = validQuestions[safeIndex];
            return _QuestionView(
              question: question,
              scrollController: _scrollController,
              questionNumber: safeIndex + 1,
              totalQuestions: validQuestions.length,
              selectedAnswerIndex: _selectedAnswerIndex,
              hasSubmitted: _hasSubmitted,
              onSelectAnswer: _selectAnswer,
              onShowHint: question.hint.trim().isEmpty
                  ? null
                  : () => _showHint(question.hint),
              onSubmit: () => _submit(question),
              onNext: () => _nextQuestion(validQuestions.length),
            );
          },
        ),
      ),
    );
  }
}

class PracticeResult {
  const PracticeResult({
    required this.correctAnswers,
    required this.totalQuestions,
  });

  final int correctAnswers;
  final int totalQuestions;

  int get percentage => resultPercentage(
        correctCount: correctAnswers,
        totalQuestions: totalQuestions,
      );
}

class _QuestionView extends StatelessWidget {
  const _QuestionView({
    required this.question,
    required this.scrollController,
    required this.questionNumber,
    required this.totalQuestions,
    required this.selectedAnswerIndex,
    required this.hasSubmitted,
    required this.onSelectAnswer,
    required this.onSubmit,
    required this.onNext,
    this.onShowHint,
  });

  final PracticeQuestion question;
  final ScrollController scrollController;
  final int questionNumber;
  final int totalQuestions;
  final int? selectedAnswerIndex;
  final bool hasSubmitted;
  final ValueChanged<int> onSelectAnswer;
  final VoidCallback onSubmit;
  final VoidCallback onNext;
  final VoidCallback? onShowHint;

  bool get _isCorrect => selectedAnswerIndex == question.correctAnswerIndex;

  @override
  Widget build(BuildContext context) {
    final progress = questionNumber / totalQuestions;
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      children: [
        Text('Practice', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          'Question $questionNumber of $totalQuestions',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: progress,
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
          _AnswerOption(
            label: question.options[index],
            index: index,
            selectedAnswerIndex: selectedAnswerIndex,
            correctAnswerIndex: question.correctAnswerIndex,
            hasSubmitted: hasSubmitted,
            onTap: () => onSelectAnswer(index),
          ),
          const SizedBox(height: 10),
        ],
        if (onShowHint != null) ...[
          const SizedBox(height: 2),
          OutlinedButton.icon(
            onPressed: hasSubmitted ? null : onShowHint,
            icon: const Icon(Icons.lightbulb_outline_rounded),
            label: const Text('Hint'),
          ),
        ],
        if (hasSubmitted) ...[
          const SizedBox(height: 16),
          _FeedbackCard(
            isCorrect: _isCorrect,
            explanation: question.explanation,
          ),
        ],
        const SizedBox(height: 18),
        FilledButton(
          onPressed: hasSubmitted ? onNext : onSubmit,
          child: Text(hasSubmitted ? 'Next Question' : 'Submit Answer'),
        ),
      ],
    );
  }
}

class _AnswerOption extends StatelessWidget {
  const _AnswerOption({
    required this.label,
    required this.index,
    required this.selectedAnswerIndex,
    required this.correctAnswerIndex,
    required this.hasSubmitted,
    required this.onTap,
  });

  final String label;
  final int index;
  final int? selectedAnswerIndex;
  final int correctAnswerIndex;
  final bool hasSubmitted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedAnswerIndex == index;
    final isCorrect = correctAnswerIndex == index;
    final isIncorrectSelection = hasSubmitted && isSelected && !isCorrect;
    final showCorrect = hasSubmitted && isCorrect;
    final borderColor = showCorrect
        ? const Color(0xFF3F7D58)
        : isIncorrectSelection
            ? const Color(0xFFB65F4A)
            : isSelected
                ? const Color(0xFF496A5A)
                : const Color(0xFFE2E8E3);
    final backgroundColor = showCorrect
        ? const Color(0xFFE5EEE8)
        : isIncorrectSelection
            ? const Color(0xFFFFEDE7)
            : Colors.white;

    return Material(
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: borderColor, width: isSelected ? 2 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: hasSubmitted ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (showCorrect || isIncorrectSelection) ...[
                      const SizedBox(height: 5),
                      Text(
                        showCorrect ? 'Correct answer' : 'Your answer',
                        style: TextStyle(
                          color: showCorrect
                              ? const Color(0xFF3F7D58)
                              : const Color(0xFFB65F4A),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (showCorrect)
                const Icon(Icons.check_circle_rounded, color: Color(0xFF3F7D58))
              else if (isIncorrectSelection)
                const Icon(Icons.cancel_rounded, color: Color(0xFFB65F4A))
              else if (isSelected)
                const Icon(Icons.radio_button_checked_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.isCorrect, required this.explanation});

  final bool isCorrect;
  final String explanation;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isCorrect ? const Color(0xFFE5EEE8) : const Color(0xFFFFEDE7),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isCorrect ? 'Correct. Nice work.' : 'Good try. Let us review it.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (explanation.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                explanation,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CompletionView extends StatelessWidget {
  const _CompletionView({
    required this.correctAnswers,
    required this.totalQuestions,
  });

  final int correctAnswers;
  final int totalQuestions;

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
                const Icon(Icons.check_circle_rounded,
                    size: 54, color: Color(0xFF496A5A)),
                const SizedBox(height: 18),
                Text(
                  'Practice Complete',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Score',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  '$correctAnswers out of $totalQuestions correct',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                const Text(
                  'Great work!\nYou are ready to try the quiz.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Return to Chapter'),
        ),
      ],
    );
  }
}

class _PracticeState extends StatelessWidget {
  const _PracticeState({
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
