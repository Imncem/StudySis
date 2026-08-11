import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studysis/config/content_paths.dart';
import 'package:studysis/models/muffin_wallet.dart';
import 'package:studysis/models/student.dart';
import 'package:studysis/models/subject.dart';
import 'package:studysis/repositories/learning_repository.dart';
import 'package:studysis/screens/home_screen.dart';
import 'package:studysis/services/muffin_wallet_service.dart';
import 'package:studysis/services/saved_flashcard_service.dart';
import 'package:studysis/theme/app_theme.dart';

void main() {
  const uid = 'anonymousUid123';

  testWidgets('dashboard displays and updates Muffin Bites value',
      (tester) async {
    final wallet = _WalletController(MuffinWallet.full);
    await tester.pumpWidget(_app(walletService: wallet));
    await tester.pumpAndSettle();

    expect(find.text('Muffin Bites'), findsOneWidget);
    expect(find.text('🍪 5 / 5'), findsOneWidget);
    expect(find.text('Muffin is ready to help!'), findsOneWidget);

    wallet.add(const MuffinWallet(
      maxBites: 5,
      currentBites: 2,
      regenIntervalMinutes: 60,
      dailyUsedRequests: 0,
      dailySoftLimit: 17,
      dailyHardLimit: 20,
      status: 'active',
    ));
    await tester.pumpAndSettle();

    expect(find.text('🍪 2 / 5'), findsOneWidget);
    expect(find.textContaining('Next Bite in'), findsOneWidget);
  });

  testWidgets('dashboard shows recharge and daily-rest Bite states',
      (tester) async {
    final wallet = _WalletController(MuffinWallet.empty);
    await tester.pumpWidget(_app(walletService: wallet));
    await tester.pumpAndSettle();

    expect(find.text('🍪 0 / 5'), findsOneWidget);
    expect(find.textContaining('Muffin is recharging'), findsOneWidget);

    wallet.add(MuffinWallet(
      maxBites: 5,
      currentBites: 4,
      regenIntervalMinutes: 60,
      dailyUsedRequests: 0,
      dailySoftLimit: 17,
      dailyHardLimit: 20,
      status: 'daily_limit',
      nextProviderResetAt: DateTime.now().add(const Duration(hours: 3)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('🍪 4 / 5'), findsOneWidget);
    expect(find.textContaining('Muffin is resting for today'), findsOneWidget);
    expect(find.textContaining('daily reset'), findsOneWidget);
  });

  testWidgets('Saved Flashcards dashboard section renders and opens screen',
      (tester) async {
    _setLargeSurface(tester);
    final firestore = FakeFirebaseFirestore();
    await _seedCurriculum(firestore);
    final service = FirestoreSavedFlashcardService(
      firestore: firestore,
      uidProvider: () => uid,
    );
    await service.saveFlashcard(
      subjectId: 'math',
      chapterId: 'chapter-1',
      cardId: 'card-1',
    );

    await tester.pumpWidget(_app(
      learningRepository: LearningRepository(firestore: firestore),
      savedFlashcardService: service,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Saved Flashcards'), findsOneWidget);
    expect(find.text('1 saved flashcards'), findsOneWidget);
    expect(find.text('Patterns and Sequences'), findsOneWidget);

    await tester.tap(find.text('Saved Flashcards'));
    await tester.pumpAndSettle();

    expect(find.text('Saved Flashcards'), findsWidgets);
    expect(find.text('What is a sequence?'), findsOneWidget);
  });

  testWidgets('Saved Flashcards dashboard count updates after unsave',
      (tester) async {
    _setLargeSurface(tester);
    final firestore = FakeFirebaseFirestore();
    await _seedCurriculum(firestore);
    final service = FirestoreSavedFlashcardService(
      firestore: firestore,
      uidProvider: () => uid,
    );
    await service.saveFlashcard(
      subjectId: 'math',
      chapterId: 'chapter-1',
      cardId: 'card-1',
    );

    await tester.pumpWidget(_app(
      learningRepository: LearningRepository(firestore: firestore),
      savedFlashcardService: service,
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saved Flashcards'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.bookmark_remove_rounded));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('0 saved flashcards'), findsOneWidget);
  });

  testWidgets('empty Saved Flashcards state works', (tester) async {
    _setLargeSurface(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saved Flashcards'));
    await tester.pumpAndSettle();

    expect(find.text('No saved flashcards yet'), findsOneWidget);
    expect(find.textContaining('Save useful cards'), findsOneWidget);
  });

  test('saved flashcards survive supported persistence lifecycle', () async {
    final firestore = FakeFirebaseFirestore();
    final first = FirestoreSavedFlashcardService(
      firestore: firestore,
      uidProvider: () => uid,
    );
    await first.saveFlashcard(
      subjectId: 'math',
      chapterId: 'chapter-1',
      cardId: 'card-1',
    );

    final restored = FirestoreSavedFlashcardService(
      firestore: firestore,
      uidProvider: () => uid,
    );
    final refs = await restored.watchSavedFlashcards().first;

    expect(refs.single.cardId, 'card-1');
  });
}

Widget _app({
  MuffinWalletService walletService = const StaticMuffinWalletService(),
  SavedFlashcardService savedFlashcardService =
      const StaticSavedFlashcardService(),
  LearningRepository? learningRepository,
}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: HomeScreen(
      walletService: walletService,
      savedFlashcardService: savedFlashcardService,
      learningRepository: learningRepository ??
          LearningRepository(
            firestore: FakeFirebaseFirestore(),
          ),
      studentStream: Stream.value(
        const Student(
          id: 'qidah',
          name: 'Qidah',
          preferredLanguage: 'Bahasa Melayu',
          dailyTargetMinutes: 20,
          status: 'active',
        ),
      ),
      subjectsStream: Stream.value(const <Subject>[]),
    ),
  );
}

Future<void> _seedCurriculum(FakeFirebaseFirestore firestore) async {
  await firestore.doc(ContentPaths.subject('math')).set({
    'displayName': 'Mathematics',
    'shortName': 'Math',
    'contentStatus': 'available',
    'iconName': 'math',
    'themeColor': '#496A5A',
    'order': 1,
  });
  await firestore.doc('${ContentPaths.chapters('math')}/chapter-1').set({
    'chapterNumber': 1,
    'title': 'Patterns and Sequences',
    'textbookChapterTitle': '',
    'learningObjectives': <String>[],
    'estimatedMinutes': 30,
    'status': 'active',
    'order': 1,
    'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
  });
  await firestore
      .doc(ContentPaths.module('math', 'chapter-1', 'flashcards'))
      .set({
    'title': 'Flashcards',
    'type': 'flashcards',
    'content': '',
    'summary': '',
    'estimatedMinutes': 5,
    'difficulty': 'easy',
    'order': 1,
    'status': 'active',
  });
  await firestore
      .collection(ContentPaths.flashcardCards('math', 'chapter-1'))
      .doc('card-1')
      .set({
    'front': 'What is a sequence?',
    'back': 'An ordered list that follows a rule.',
    'hint': 'Think about order.',
    'order': 1,
    'status': 'active',
  });
}

void _setLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

class _WalletController implements MuffinWalletService {
  _WalletController(this._current);

  MuffinWallet _current;
  final _controller = StreamController<MuffinWallet>.broadcast();

  void add(MuffinWallet wallet) {
    _current = wallet;
    _controller.add(wallet);
  }

  @override
  Stream<MuffinWallet> watchWallet() async* {
    yield _current;
    yield* _controller.stream;
  }
}
