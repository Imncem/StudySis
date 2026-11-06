import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studysis/models/chapter.dart';
import 'package:studysis/models/quiz_question.dart';
import 'package:studysis/models/review_item.dart';
import 'package:studysis/screens/quiz_screen.dart';
import 'package:studysis/screens/review_screen.dart';

void main() {
  testWidgets('Test has a distinct start screen and uses trusted score result',
      (tester) async {
    Map<String, int>? submitted;
    await tester.pumpWidget(MaterialApp(
      home: QuizScreen(
        chapter: _chapter,
        subjectId: 'geography',
        subjectTitle: 'Geography',
        title: 'Chapter assessment',
        assessmentLabel: 'Test',
        requireStart: true,
        questionsFuture: Future.value(const [
          QuizQuestion(
            id: 'q1',
            question: 'Which answer is correct?',
            options: ['A', 'B', 'C', 'D'],
            correctOptionIndex: -1,
            explanation: '',
            difficulty: 'easy',
            order: 1,
            status: 'active',
          ),
        ]),
        onSubmitAnswers: (answers) async {
          submitted = answers;
          return QuizResult.fromTrustedScore(const {
            'correctCount': 0,
            'incorrectCount': 1,
            'unansweredCount': 0,
            'totalQuestions': 1,
          }, answers);
        },
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Start Test'), findsOneWidget);
    expect(find.text('Which answer is correct?'), findsNothing);
    await tester.tap(find.text('Start Test'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A').first);
    await tester.ensureVisible(find.text('Submit Test'));
    await tester.tap(find.text('Submit Test'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, 'Submit Test'),
    ));
    await tester.pumpAndSettle();

    expect(submitted, {'q1': 0});
    expect(find.text('Test Complete'), findsOneWidget);
    expect(find.text('0 / 1'), findsOneWidget);
    expect(find.text('Review Answers'), findsNothing);
  });

  testWidgets('Review renders ordered revision content and completes once',
      (tester) async {
    var completions = 0;
    await tester.pumpWidget(MaterialApp(
      home: ReviewScreen(
        title: 'Scale review',
        itemsFuture: Future.value(const [
          ReviewItem(
            id: 'r1',
            heading: 'Key concept',
            body: 'Scale compares map distance with actual distance.',
            keyPoint: 'Keep units consistent.',
            prompt: 'Can you explain scale?',
            order: 1,
            status: 'active',
          ),
        ]),
        onComplete: () async => completions += 1,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Review'), findsOneWidget);
    expect(find.text('Key concept'), findsOneWidget);
    expect(find.text('Keep units consistent.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('complete-review-button')));
    await tester.pumpAndSettle();
    expect(completions, 1);
    expect(find.text('Review complete'), findsOneWidget);
  });
}

const _chapter = Chapter(
  id: 'chapter-01',
  chapterNumber: 1,
  title: 'Scale and Distance',
  textbookChapterTitle: 'Scale and Distance',
  learningObjectives: [],
  estimatedMinutes: 20,
  status: 'active',
  order: 1,
);
