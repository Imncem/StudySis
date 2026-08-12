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
import 'package:studysis/services/muffin_context_registry.dart';
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
    expect(find.text('Muffin is ready to help!'), findsOneWidget);
    expect(find.textContaining('Next Bite in'), findsNothing);
    expect(find.textContaining('recharging'), findsNothing);
  });

  testWidgets('dashboard shows recharge and daily-rest Bite states',
      (tester) async {
    final wallet = _WalletController(MuffinWallet.empty);
    await tester.pumpWidget(_app(walletService: wallet));
    await tester.pumpAndSettle();

    expect(find.text('🍪 0 / 5'), findsOneWidget);
    expect(
      find.text('Muffin is recharging. Check back a little later.'),
      findsOneWidget,
    );
    expect(find.textContaining('Next Bite in'), findsNothing);

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

  testWidgets('dashboard shows low Bite message at 1/5', (tester) async {
    final wallet = _WalletController(const MuffinWallet(
      maxBites: 5,
      currentBites: 1,
      regenIntervalMinutes: 60,
      dailyUsedRequests: 0,
      dailySoftLimit: 17,
      dailyHardLimit: 20,
      status: 'active',
    ));
    await tester.pumpWidget(_app(walletService: wallet));
    await tester.pumpAndSettle();

    expect(find.textContaining('1 / 5'), findsOneWidget);
    expect(find.text('Muffin is getting a little tired.'), findsOneWidget);
  });

  testWidgets('dashboard displays regenerated Bites after app reopen',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    final anchor = DateTime.utc(2026, 8, 11, 18, 20);
    await firestore.doc('students/qidah/muffin/state').set({
      'maxBites': 5,
      'currentBites': 0,
      'regenIntervalMinutes': 60,
      'lastRegenAt': Timestamp.fromDate(anchor),
      'dailyUsedRequests': 0,
      'dailySoftLimit': 17,
      'dailyHardLimit': 20,
      'status': 'recharging',
    });
    final walletService = FirestoreMuffinWalletService(
      firestore: firestore,
      nowProvider: () => anchor.add(const Duration(hours: 3)),
    );

    await tester.pumpWidget(_app(walletService: walletService));
    await tester.pumpAndSettle();

    expect(find.textContaining('3 / 5'), findsOneWidget);
    expect(find.text('Muffin is ready to help!'), findsOneWidget);
  });

  testWidgets('dashboard refreshes regenerated Bites while open',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    final anchor = DateTime.utc(2026, 8, 11, 18, 20);
    var now = anchor.add(const Duration(minutes: 59));
    await firestore.doc('students/qidah/muffin/state').set({
      'maxBites': 5,
      'currentBites': 0,
      'regenIntervalMinutes': 60,
      'lastRegenAt': Timestamp.fromDate(anchor),
      'dailyUsedRequests': 0,
      'dailySoftLimit': 17,
      'dailyHardLimit': 20,
      'status': 'recharging',
    });
    final walletService = FirestoreMuffinWalletService(
      firestore: firestore,
      nowProvider: () => now,
      refreshInterval: const Duration(minutes: 1),
    );

    await tester.pumpWidget(_app(walletService: walletService));
    await tester.pumpAndSettle();
    expect(find.textContaining('0 / 5'), findsOneWidget);

    now = anchor.add(const Duration(minutes: 60));
    await tester.pump(const Duration(minutes: 1));
    await tester.pump();

    expect(find.textContaining('1 / 5'), findsOneWidget);
    expect(find.text('Muffin is getting a little tired.'), findsOneWidget);
  });

  testWidgets('dashboard recalculates regenerated Bites on app resume',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    final anchor = DateTime.utc(2026, 8, 11, 18, 20);
    var now = anchor;
    await firestore.doc('students/qidah/muffin/state').set({
      'maxBites': 5,
      'currentBites': 0,
      'regenIntervalMinutes': 60,
      'lastRegenAt': Timestamp.fromDate(anchor),
      'dailyUsedRequests': 0,
      'dailySoftLimit': 17,
      'dailyHardLimit': 20,
      'status': 'recharging',
    });
    final walletService = FirestoreMuffinWalletService(
      firestore: firestore,
      nowProvider: () => now,
      refreshInterval: const Duration(hours: 24),
    );

    await tester.pumpWidget(_app(walletService: walletService));
    await tester.pumpAndSettle();
    expect(find.textContaining('0 / 5'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    now = anchor.add(const Duration(hours: 3));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(find.textContaining('3 / 5'), findsOneWidget);
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
    expect(find.text('1 / 1'), findsOneWidget);
    expect(find.text('Tap to reveal answer'), findsOneWidget);
  });

  testWidgets('Saved Flashcards deck only shows saved cards and swipes',
      (tester) async {
    _setLargeSurface(tester);
    final firestore = FakeFirebaseFirestore();
    await _seedCurriculum(firestore, includeExtraCards: true);
    final service = FirestoreSavedFlashcardService(
      firestore: firestore,
      uidProvider: () => uid,
    );
    await service.saveFlashcard(
      subjectId: 'math',
      chapterId: 'chapter-1',
      cardId: 'card-1',
    );
    await service.saveFlashcard(
      subjectId: 'math',
      chapterId: 'chapter-1',
      cardId: 'card-3',
    );

    await tester.pumpWidget(_app(
      learningRepository: LearningRepository(firestore: firestore),
      savedFlashcardService: service,
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saved Flashcards'));
    await tester.pumpAndSettle();

    final startsOnThirdCard =
        find.text('What is the third saved card?').evaluate().isNotEmpty;
    expect(
      startsOnThirdCard ||
          find.text('What is a sequence?').evaluate().isNotEmpty,
      isTrue,
    );
    expect(find.text('Unsaved middle card'), findsNothing);
    expect(find.text('1 / 2'), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(0, -700), 1000);
    await tester.pumpAndSettle();

    expect(
      find.text(
        startsOnThirdCard
            ? 'What is a sequence?'
            : 'What is the third saved card?',
      ),
      findsOneWidget,
    );
    expect(find.text('2 / 2'), findsOneWidget);
  });

  testWidgets('Saved Flashcards deck tap reveals answer', (tester) async {
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
    await tester.tap(find.text('What is a sequence?'));
    await tester.pumpAndSettle();

    expect(find.text('An ordered list that follows a rule.'), findsOneWidget);
  });

  testWidgets('Saved Flashcards deck updates Muffin context without progress',
      (tester) async {
    _setLargeSurface(tester);
    addTearDown(MuffinContextRegistry.instance.resetToHome);
    final firestore = FakeFirebaseFirestore();
    await _seedCurriculum(firestore, includeExtraCards: true);
    final service = FirestoreSavedFlashcardService(
      firestore: firestore,
      uidProvider: () => uid,
    );
    await service.saveFlashcard(
      subjectId: 'math',
      chapterId: 'chapter-1',
      cardId: 'card-1',
    );
    await service.saveFlashcard(
      subjectId: 'math',
      chapterId: 'chapter-1',
      cardId: 'card-3',
    );

    await tester.pumpWidget(_app(
      learningRepository: LearningRepository(firestore: firestore),
      savedFlashcardService: service,
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saved Flashcards'));
    await tester.pumpAndSettle();

    expect(
      MuffinContextRegistry.instance.current.value?.context.currentScreen,
      'saved_flashcards',
    );
    final initialCardId =
        MuffinContextRegistry.instance.current.value?.context.cardId;
    expect(['card-1', 'card-3'], contains(initialCardId));

    await tester.fling(find.byType(PageView), const Offset(0, -700), 1000);
    await tester.pumpAndSettle();

    final swipedCardId =
        MuffinContextRegistry.instance.current.value?.context.cardId;
    expect(['card-1', 'card-3'], contains(swipedCardId));
    expect(swipedCardId, isNot(initialCardId));
    final progress = await firestore
        .collection('student_progress')
        .doc(uid)
        .collection('chapters')
        .get();
    expect(progress.docs, isEmpty);
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

    expect(find.text('No saved flashcards yet'), findsOneWidget);
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
      ).asBroadcastStream(),
      subjectsStream: Stream.value(const <Subject>[]).asBroadcastStream(),
    ),
  );
}

Future<void> _seedCurriculum(
  FakeFirebaseFirestore firestore, {
  bool includeExtraCards = false,
}) async {
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
  if (!includeExtraCards) return;
  await firestore
      .collection(ContentPaths.flashcardCards('math', 'chapter-1'))
      .doc('card-2')
      .set({
    'front': 'Unsaved middle card',
    'back': 'This card should not appear.',
    'hint': '',
    'order': 2,
    'status': 'active',
  });
  await firestore
      .collection(ContentPaths.flashcardCards('math', 'chapter-1'))
      .doc('card-3')
      .set({
    'front': 'What is the third saved card?',
    'back': 'Only saved references appear in this deck.',
    'hint': '',
    'order': 3,
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
