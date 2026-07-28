import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studysis/models/chapter.dart';
import 'package:studysis/models/quiz_muffin_context.dart';
import 'package:studysis/models/quiz_question.dart';
import 'package:studysis/screens/quiz_screen.dart';
import 'package:studysis/services/muffin_guidance_policy.dart';
import 'package:studysis/theme/app_theme.dart';

void main() {
  testWidgets('shows loading state while quiz loads', (tester) async {
    final completer = Completer<List<QuizQuestion>>();

    await tester.pumpWidget(_quizApp(completer.future));

    expect(find.text('Loading quiz'), findsOneWidget);
  });

  testWidgets('shows empty state when no questions exist', (tester) async {
    await tester.pumpWidget(_quizApp(Future.value(const [])));
    await tester.pumpAndSettle();

    expect(find.text('Quiz questions coming soon'), findsOneWidget);
  });

  testWidgets('selects an option and navigates next and previous',
      (tester) async {
    await tester.pumpWidget(_quizApp(Future.value(_questions())));
    await tester.pumpAndSettle();

    await tester.tap(find.text('A').first);
    await _tapVisible(tester, find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Question 2 of 3'), findsOneWidget);
    expect(find.text('Which number is even?'), findsOneWidget);

    await _tapVisible(tester, find.text('Previous'));
    await tester.pumpAndSettle();

    expect(find.text('Question 1 of 3'), findsOneWidget);
    expect(find.text('Correct'), findsNothing);
  });

  testWidgets('renders Ask Muffin assistance and opens bottom sheet',
      (tester) async {
    await tester.pumpWidget(_quizApp(Future.value(_questions())));
    await tester.pumpAndSettle();

    expect(find.text('Need a little help?'), findsOneWidget);
    expect(find.text('Ask Muffin'), findsOneWidget);

    await _tapVisible(tester, find.text('Ask Muffin'));
    await tester.pumpAndSettle();

    expect(find.text('Muffin'), findsOneWidget);
    expect(find.text('I can guide you without revealing the answer.'),
        findsOneWidget);
    expect(find.text('Give me a small hint'), findsOneWidget);
    expect(find.text('Explain the concept'), findsOneWidget);
    expect(find.text('Help me identify the pattern'), findsOneWidget);
  });

  testWidgets('changes Muffin placeholder response based on selected action',
      (tester) async {
    await tester.pumpWidget(_quizApp(Future.value(_questions())));
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.text('Ask Muffin'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Give me a small hint'));
    await tester.pumpAndSettle();
    expect(
      find.text('Soon, Muffin will provide a gentle clue to help you begin.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Explain the concept'));
    await tester.pumpAndSettle();
    expect(
      find.text('Soon, Muffin will explain the concept behind this question.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Help me identify the pattern'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Soon, Muffin will guide you in finding the relationship between the values.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('closes Muffin bottom sheet', (tester) async {
    await tester.pumpWidget(_quizApp(Future.value(_questions())));
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.text('Ask Muffin'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(find.text('I can guide you without revealing the answer.'),
        findsNothing);
  });

  testWidgets('Muffin keeps selected answer and does not submit quiz',
      (tester) async {
    await tester.pumpWidget(_quizApp(Future.value(_questions())));
    await tester.pumpAndSettle();

    await tester.tap(find.text('A').first);
    await _tapVisible(tester, find.text('Ask Muffin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explain the concept'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.text('Next'));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('Next'));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('Submit Quiz'));
    await tester.pumpAndSettle();

    expect(find.text('Submit Quiz?'), findsOneWidget);
    expect(find.textContaining('You have answered 1 of 3 questions.'),
        findsOneWidget);
    expect(find.text('Quiz Complete'), findsNothing);
  });

  testWidgets('retains and allows changing a selected answer', (tester) async {
    await tester.pumpWidget(_quizApp(Future.value(_questions())));
    await tester.pumpAndSettle();

    await tester.tap(find.text('A').first);
    await _tapVisible(tester, find.text('Next'));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('Previous'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('C').first);
    await _tapVisible(tester, find.text('Next'));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('Next'));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('Submit Quiz'));
    await tester.pumpAndSettle();
    await _tapDialogSubmit(tester);
    await tester.pumpAndSettle();

    expect(find.text('1 / 3'), findsOneWidget);
  });

  testWidgets('shows submission confirmation with answered and unanswered',
      (tester) async {
    await tester.pumpWidget(_quizApp(Future.value(_questions())));
    await tester.pumpAndSettle();

    await tester.tap(find.text('C').first);
    await _tapVisible(tester, find.text('Next'));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('Next'));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('Submit Quiz'));
    await tester.pumpAndSettle();

    expect(find.text('Submit Quiz?'), findsOneWidget);
    expect(find.textContaining('You have answered 1 of 3 questions.'),
        findsOneWidget);
    expect(find.textContaining('2 questions are still unanswered.'),
        findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Submit Quiz?'), findsNothing);
  });

  testWidgets('calculates score, unanswered count, and pass result',
      (tester) async {
    await tester.pumpWidget(_quizApp(Future.value(_questions())));
    await tester.pumpAndSettle();

    await tester.tap(find.text('C').first);
    await _tapVisible(tester, find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('C').first);
    await _tapVisible(tester, find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('B').first);
    await _tapVisible(tester, find.text('Submit Quiz'));
    await tester.pumpAndSettle();
    await _tapDialogSubmit(tester);
    await tester.pumpAndSettle();

    expect(find.text('Quiz Complete'), findsOneWidget);
    expect(find.text('3 / 3'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('Pass'), findsOneWidget);
    expect(find.text('Excellent work!'), findsOneWidget);
    expect(find.text('Unanswered'), findsOneWidget);
    expect(find.text('0'), findsWidgets);
  });

  testWidgets('calculates fail result with unanswered questions',
      (tester) async {
    await tester.pumpWidget(_quizApp(Future.value(_questions())));
    await tester.pumpAndSettle();

    await tester.tap(find.text('A').first);
    await _tapVisible(tester, find.text('Next'));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('Next'));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('Submit Quiz'));
    await tester.pumpAndSettle();
    await _tapDialogSubmit(tester);
    await tester.pumpAndSettle();

    expect(find.text('0 / 3'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
    expect(find.text('Needs Revision'), findsOneWidget);
    expect(find.text('Keep practising. You can improve!'), findsOneWidget);
  });

  testWidgets('shows review answers after results', (tester) async {
    await tester.pumpWidget(_quizApp(Future.value(_questions())));
    await tester.pumpAndSettle();

    await tester.tap(find.text('C').first);
    await _tapVisible(tester, find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A').first);
    await _tapVisible(tester, find.text('Next'));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('Submit Quiz'));
    await tester.pumpAndSettle();
    await _tapDialogSubmit(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Review Answers'));
    await tester.pumpAndSettle();

    expect(find.text('Review Answers'), findsOneWidget);
    expect(find.textContaining('Status: Correct'), findsOneWidget);
    expect(find.textContaining('Status: Incorrect'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('Status: Unanswered'),
      220,
      scrollable: find.byType(Scrollable).last,
      maxScrolls: 12,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Status: Unanswered'), findsOneWidget);
    expect(find.textContaining('Student answer: No answer selected'),
        findsOneWidget);
    expect(find.textContaining('Correct answer: B.'), findsOneWidget);
    expect(find.text('Next'), findsNothing);
  });

  test('safe QuizMuffinContext excludes correct-answer data', () {
    final context = QuizMuffinContext.fromQuestion(
      subjectId: 'math',
      subjectTitle: 'Mathematics',
      chapterId: 'chapter-1',
      chapterTitle: 'Patterns and Sequences',
      question: _questions().first,
      questionNumber: 1,
      totalQuestions: 3,
    );
    final safeMap = context.toSafeMap();

    expect(safeMap['questionText'], 'What is 2 + 2?');
    expect(safeMap['options'], ['2', '3', '4', '5']);
    expect(safeMap.containsKey('correctOptionIndex'), isFalse);
    expect(safeMap.containsKey('correctAnswer'), isFalse);
    expect(safeMap.containsKey('explanation'), isFalse);
  });

  test('Muffin quiz guidance policy forbids answer reveal behavior', () {
    expect(
        muffinQuizGuidancePolicy, contains('Never reveal the correct answer.'));
    expect(
        muffinQuizGuidancePolicy, contains('Never name the correct option.'));
    expect(muffinQuizGuidancePolicy, contains('Never say "Choose A/B/C/D".'));
    expect(muffinQuizGuidancePolicy,
        contains('Never solve the entire quiz question.'));
  });
}

Widget _quizApp(Future<List<QuizQuestion>> questionsFuture) {
  return MaterialApp(
    theme: AppTheme.light,
    home: QuizScreen(
      chapter: const Chapter(
        id: 'chapter-1',
        chapterNumber: 1,
        title: 'Patterns and Sequences',
        textbookChapterTitle: 'Patterns and Sequences',
        learningObjectives: [],
        estimatedMinutes: 30,
        status: 'active',
        order: 1,
      ),
      subjectId: 'math',
      subjectTitle: 'Mathematics',
      title: 'Chapter 1 Quiz',
      questionsFuture: questionsFuture,
    ),
  );
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    220,
    scrollable: find.byType(Scrollable).last,
    maxScrolls: 12,
  );
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
}

Future<void> _tapDialogSubmit(WidgetTester tester) async {
  final button = find.descendant(
    of: find.byType(AlertDialog),
    matching: find.widgetWithText(FilledButton, 'Submit Quiz'),
  );
  await tester.tap(button);
}

List<QuizQuestion> _questions() {
  return const [
    QuizQuestion(
      id: 'q1',
      question: 'What is 2 + 2?',
      options: ['2', '3', '4', '5'],
      correctOptionIndex: 2,
      explanation: '2 + 2 equals 4.',
      difficulty: 'easy',
      order: 1,
      status: 'active',
    ),
    QuizQuestion(
      id: 'q2',
      question: 'Which number is even?',
      options: ['3', '5', '8', '9'],
      correctOptionIndex: 2,
      explanation: '8 is divisible by 2.',
      difficulty: 'easy',
      order: 2,
      status: 'active',
    ),
    QuizQuestion(
      id: 'q3',
      question: 'Which letter is second?',
      options: ['A', 'B', 'C', 'D'],
      correctOptionIndex: 1,
      explanation: 'B is the second letter.',
      difficulty: 'easy',
      order: 3,
      status: 'active',
    ),
  ];
}
