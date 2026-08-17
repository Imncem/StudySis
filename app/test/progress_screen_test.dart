import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studysis/config/content_paths.dart';
import 'package:studysis/repositories/engagement_repository.dart';
import 'package:studysis/repositories/learning_repository.dart';
import 'package:studysis/repositories/student_progress_repository.dart';
import 'package:studysis/screens/progress_screen.dart';
import 'package:studysis/theme/app_theme.dart';

void main() {
  const uid = 'anonymousUid123';

  testWidgets('progress screen shows empty state with start learning action',
      (tester) async {
    _setLargeSurface(tester);
    final firestore = FakeFirebaseFirestore();
    await _seedChapter(firestore, 'chapter-1', order: 1, number: 1);

    await tester.pumpWidget(
      _app(
        firestore: firestore,
        uid: uid,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your learning journey starts here.'), findsOneWidget);
    expect(
      find.text('Complete your first lesson to see your progress.'),
      findsOneWidget,
    );
    expect(find.text('Start Learning'), findsOneWidget);
  });

  testWidgets('progress screen shows populated summary from saved progress',
      (tester) async {
    _setLargeSurface(tester);
    final firestore = FakeFirebaseFirestore();
    await _seedChapter(firestore, 'chapter-1', order: 1, number: 1);
    await _seedProgress(
      firestore,
      uid: uid,
      chapterId: 'chapter-1',
      overallProgress: 100,
      learnCompleted: true,
      flashcardsCompleted: true,
      practiceBestPercentage: 80,
      practiceTotalQuestions: 5,
      quizBestPercentage: 90,
      quizPassed: true,
      quizCompletedAt: DateTime(2026, 1, 2),
    );

    await tester.pumpWidget(_app(firestore: firestore, uid: uid));
    await tester.pumpAndSettle();

    expect(find.text('Overall Learning Progress'), findsOneWidget);
    expect(find.text('100%'), findsWidgets);
    expect(find.text('1 / 1 chapters completed'), findsOneWidget);
    expect(find.text('Chapters Started'), findsOneWidget);
    expect(find.text('Modules Completed'), findsOneWidget);
    expect(find.text('Average Practice Score'), findsOneWidget);
    expect(find.text('Average Quiz Score'), findsOneWidget);
    expect(find.text('Strong'), findsOneWidget);
    expect(find.text('Chapter 1: Patterns and Sequences'), findsOneWidget);
    expect(find.text('Quiz passed'), findsOneWidget);
  });

  testWidgets('chapter progress cards sort by most recent activity',
      (tester) async {
    _setLargeSurface(tester);
    final firestore = FakeFirebaseFirestore();
    await _seedChapter(firestore, 'chapter-1', order: 1, number: 1);
    await _seedChapter(firestore, 'chapter-2', order: 2, number: 2);
    await _seedProgress(
      firestore,
      uid: uid,
      chapterId: 'chapter-1',
      overallProgress: 25,
      lastActivityAt: DateTime(2026, 1, 1),
    );
    await _seedProgress(
      firestore,
      uid: uid,
      chapterId: 'chapter-2',
      overallProgress: 50,
      lastActivityAt: DateTime(2026, 1, 3),
    );

    await tester.pumpWidget(_app(firestore: firestore, uid: uid));
    await tester.pumpAndSettle();

    final chapterTwoTop =
        tester.getTopLeft(find.text('Chapter 2: Linear Equations')).dy;
    final chapterOneTop =
        tester.getTopLeft(find.text('Chapter 1: Patterns and Sequences')).dy;
    expect(chapterTwoTop, lessThan(chapterOneTop));
  });

  testWidgets('chapter progress cards use chapter order when activity missing',
      (tester) async {
    _setLargeSurface(tester);
    final firestore = FakeFirebaseFirestore();
    await _seedChapter(firestore, 'chapter-1', order: 1, number: 1);
    await _seedChapter(firestore, 'chapter-2', order: 2, number: 2);
    await _seedProgress(
      firestore,
      uid: uid,
      chapterId: 'chapter-2',
      overallProgress: 50,
    );
    await _seedProgress(
      firestore,
      uid: uid,
      chapterId: 'chapter-1',
      overallProgress: 25,
    );

    await tester.pumpWidget(_app(firestore: firestore, uid: uid));
    await tester.pumpAndSettle();

    final chapterOneTop =
        tester.getTopLeft(find.text('Chapter 1: Patterns and Sequences')).dy;
    final chapterTwoTop =
        tester.getTopLeft(find.text('Chapter 2: Linear Equations')).dy;
    expect(chapterOneTop, lessThan(chapterTwoTop));
  });

  testWidgets('tapping a chapter card opens chapter overview', (tester) async {
    _setLargeSurface(tester);
    final firestore = FakeFirebaseFirestore();
    await _seedChapter(firestore, 'chapter-1', order: 1, number: 1);
    await _seedProgress(
      firestore,
      uid: uid,
      chapterId: 'chapter-1',
      overallProgress: 25,
      learnCompleted: true,
    );

    await tester.pumpWidget(_app(firestore: firestore, uid: uid));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chapter 1: Patterns and Sequences'));
    await tester.pumpAndSettle();

    expect(find.text('Chapter Overview'), findsOneWidget);
  });
}

void _setLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _app({
  required FakeFirebaseFirestore firestore,
  required String uid,
}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: ProgressScreen(
      learningRepository: LearningRepository(firestore: firestore),
      progressRepository: StudentProgressRepository(
        firestore: firestore,
        uidProvider: () => uid,
      ),
      engagementRepository: EngagementRepository(
        firestore: firestore,
        uidProvider: () => uid,
      ),
    ),
  );
}

Future<void> _seedChapter(
  FakeFirebaseFirestore firestore,
  String chapterId, {
  required int order,
  required int number,
}) {
  return firestore.doc('${ContentPaths.chapters('math')}/$chapterId').set({
    'chapterNumber': number,
    'title': number == 1 ? 'Patterns and Sequences' : 'Linear Equations',
    'textbookChapterTitle': '',
    'learningObjectives': <String>[],
    'estimatedMinutes': 30,
    'status': 'active',
    'order': order,
  });
}

Future<void> _seedProgress(
  FakeFirebaseFirestore firestore, {
  required String uid,
  required String chapterId,
  required int overallProgress,
  bool learnCompleted = false,
  bool flashcardsCompleted = false,
  int practiceBestPercentage = 0,
  int practiceTotalQuestions = 0,
  int quizBestPercentage = 0,
  bool quizPassed = false,
  DateTime? quizCompletedAt,
  DateTime? lastActivityAt,
}) {
  return firestore.doc('student_progress/$uid/chapters/math_$chapterId').set({
    'studentProfileId': 'qidah',
    'subjectId': 'math',
    'chapterId': chapterId,
    'learnCompleted': learnCompleted,
    'learnCompletedAt':
        learnCompleted ? Timestamp.fromDate(DateTime(2026, 1, 1)) : null,
    'flashcardsMasteredCount': flashcardsCompleted ? 3 : 0,
    'flashcardsTotalCount': flashcardsCompleted ? 3 : 0,
    'flashcardsCompleted': flashcardsCompleted,
    'masteredFlashcardIds': flashcardsCompleted
        ? <String>['card-1', 'card-2', 'card-3']
        : <String>[],
    'practiceLatestPercentage': practiceBestPercentage,
    'practiceBestPercentage': practiceBestPercentage,
    'practiceCorrectCount': practiceBestPercentage > 0 ? 4 : 0,
    'practiceTotalQuestions': practiceTotalQuestions,
    'practiceCompletedAt': practiceTotalQuestions > 0
        ? Timestamp.fromDate(DateTime(2026, 1, 2))
        : null,
    'quizLatestPercentage': quizBestPercentage,
    'quizBestPercentage': quizBestPercentage,
    'quizCorrectCount': quizBestPercentage > 0 ? 9 : 0,
    'quizIncorrectCount': quizBestPercentage > 0 ? 1 : 0,
    'quizUnansweredCount': 0,
    'quizPassed': quizPassed,
    'quizCompletedAt':
        quizCompletedAt == null ? null : Timestamp.fromDate(quizCompletedAt),
    'overallProgress': overallProgress,
    'lastActivityAt':
        lastActivityAt == null ? null : Timestamp.fromDate(lastActivityAt),
    'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 2)),
  });
}
