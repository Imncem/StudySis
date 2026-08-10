import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studysis/models/practice_question.dart';
import 'package:studysis/screens/practice_screen.dart';
import 'package:studysis/theme/app_theme.dart';

void main() {
  testWidgets('shows loading state while questions load', (tester) async {
    final completer = Completer<List<PracticeQuestion>>();

    await tester.pumpWidget(_practiceApp(completer.future));

    expect(find.text('Loading practice'), findsOneWidget);
  });

  testWidgets('shows empty state when no questions exist', (tester) async {
    await tester.pumpWidget(_practiceApp(Future.value(const [])));
    await tester.pumpAndSettle();

    expect(find.text('Practice questions coming soon'), findsOneWidget);
  });

  testWidgets('shows invalid question state for unusable question data',
      (tester) async {
    await tester.pumpWidget(_practiceApp(Future.value([
      PracticeQuestion.fromMap('bad', {
        'question': 'Missing options',
        'options': ['Only one'],
        'isPublished': true,
      }),
    ])));
    await tester.pumpAndSettle();

    expect(find.text('Practice needs a quick fix'), findsOneWidget);
  });

  testWidgets('shows correct feedback after submitting the right answer',
      (tester) async {
    await tester.pumpWidget(_practiceApp(Future.value([_questionOne()])));
    await tester.pumpAndSettle();

    await tester.tap(find.text('4'));
    await _tapVisible(tester, find.text('Submit Answer'));
    await tester.pumpAndSettle();

    expect(find.text('Correct. Nice work.'), findsOneWidget);
    expect(find.text('Correct answer'), findsOneWidget);
    expect(find.text('2 + 2 equals 4.'), findsOneWidget);
    await _makeVisible(tester, find.text('Next Question'));
    expect(find.text('Next Question'), findsOneWidget);
  });

  testWidgets('shows incorrect feedback and the correct option',
      (tester) async {
    await tester.pumpWidget(_practiceApp(Future.value([_questionOne()])));
    await tester.pumpAndSettle();

    await tester.tap(find.text('3'));
    await _tapVisible(tester, find.text('Submit Answer'));
    await tester.pumpAndSettle();

    expect(find.text('Good try. Let us review it.'), findsOneWidget);
    expect(find.text('Your answer'), findsOneWidget);
    expect(find.text('Correct answer'), findsOneWidget);
    expect(find.text('2 + 2 equals 4.'), findsOneWidget);
  });

  testWidgets('moves to the next question after feedback', (tester) async {
    await tester.pumpWidget(_practiceApp(Future.value([
      _questionOne(),
      _questionTwo(),
    ])));
    await tester.pumpAndSettle();

    await tester.tap(find.text('4'));
    await _tapVisible(tester, find.text('Submit Answer'));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('Next Question'));
    await tester.pumpAndSettle();

    expect(find.text('Question 2 of 2'), findsOneWidget);
    expect(find.text('Which number is even?'), findsOneWidget);
  });

  testWidgets('shows completion score after the final question',
      (tester) async {
    await tester.pumpWidget(_practiceApp(Future.value([
      _questionOne(),
      _questionTwo(),
    ])));
    await tester.pumpAndSettle();

    await tester.tap(find.text('4'));
    await _tapVisible(tester, find.text('Submit Answer'));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('Next Question'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5'));
    await _tapVisible(tester, find.text('Submit Answer'));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('Next Question'));
    await tester.pumpAndSettle();

    expect(find.text('Practice Complete'), findsOneWidget);
    expect(find.text('Score'), findsOneWidget);
    expect(find.text('1 out of 2 correct'), findsOneWidget);
    expect(find.text('Great work!\nYou are ready to try the quiz.'),
        findsOneWidget);
    expect(find.text('Return to Chapter'), findsOneWidget);
  });

  testWidgets('Practice removes inline Muffin entry point', (tester) async {
    _setLargeSurface(tester);
    await tester.pumpWidget(_practiceApp(Future.value([_questionOne()])));
    await tester.pumpAndSettle();

    expect(find.text('Ask Muffin'), findsNothing);
    expect(find.byIcon(Icons.psychology_rounded), findsNothing);
  });

  testWidgets('official score is unaffected without inline Muffin UI',
      (tester) async {
    _setLargeSurface(tester);
    await tester.pumpWidget(_practiceApp(Future.value([_questionOne()])));
    await tester.pumpAndSettle();

    await tester.tap(find.text('4'));
    await _tapVisible(tester, find.text('Submit Answer'));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('Next Question'));
    await tester.pumpAndSettle();

    expect(find.text('1 out of 1 correct'), findsOneWidget);
  });
}

void _setLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _practiceApp(Future<List<PracticeQuestion>> questionsFuture) {
  return MaterialApp(
    theme: AppTheme.light,
    home: PracticeScreen(
      title: 'Chapter 1 Practice',
      questionsFuture: questionsFuture,
    ),
  );
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await _makeVisible(tester, finder);
  await tester.tap(finder);
  await tester.pump();
}

Future<void> _makeVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    220,
    scrollable: find.byType(Scrollable).last,
    maxScrolls: 12,
  );
  await tester.pumpAndSettle();
}

PracticeQuestion _questionOne() {
  return const PracticeQuestion(
    id: 'q1',
    question: 'What is 2 + 2?',
    options: ['2', '3', '4', '5'],
    correctAnswerIndex: 2,
    explanation: '2 + 2 equals 4.',
    hint: 'Count two more after 2.',
    topic: 'addition',
    difficulty: 'easy',
    order: 1,
    status: 'active',
    isPublished: true,
  );
}

PracticeQuestion _questionTwo() {
  return const PracticeQuestion(
    id: 'q2',
    question: 'Which number is even?',
    options: ['3', '5', '8', '9'],
    correctAnswerIndex: 2,
    explanation: '8 is divisible by 2.',
    hint: '',
    topic: 'numbers',
    difficulty: 'easy',
    order: 2,
    status: 'active',
    isPublished: true,
  );
}
