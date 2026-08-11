import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studysis/config/content_paths.dart';
import 'package:studysis/models/chapter.dart';
import 'package:studysis/repositories/learning_repository.dart';
import 'package:studysis/screens/flashcard_screen.dart';
import 'package:studysis/services/muffin_context_registry.dart';
import 'package:studysis/services/saved_flashcard_service.dart';
import 'package:studysis/theme/app_theme.dart';

void main() {
  testWidgets('Flashcard uses global Muffin entry only', (tester) async {
    await tester.pumpWidget(await _app());
    await tester.pumpAndSettle();

    expect(find.widgetWithIcon(IconButton, Icons.pets_rounded), findsNothing);
    final actions = MuffinContextRegistry.instance.current.value!.actions;
    expect(
        actions.map((action) => action.label), contains('Explain this card'));
    expect(
        actions.map((action) => action.label), contains('Translate this card'));
    expect(actions.map((action) => action.label),
        contains('Give another example'));
  });

  testWidgets('Flashcard registry context protects unrevealed answer',
      (tester) async {
    await tester.pumpWidget(await _app());
    await tester.pumpAndSettle();

    expect(
        MuffinContextRegistry.instance.current.value!.context
            .toJson()
            .toString(),
        isNot(contains('An ordered list that follows a rule.')));

    await tester.drag(find.text('What is a sequence?'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(
        MuffinContextRegistry.instance.current.value!.context
            .toJson()
            .toString(),
        contains('An ordered list that follows a rule.'));
  });

  testWidgets('Flashcard Save persists and restores saved state',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    await _seedFlashcard(firestore);
    final service = FirestoreSavedFlashcardService(
      firestore: firestore,
      uidProvider: () => 'anonymousUid123',
    );

    await tester.pumpWidget(_appWith(
      firestore: firestore,
      savedFlashcardService: service,
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.bookmark_border_rounded));
    await tester.pumpAndSettle();

    var refs = await service.watchSavedFlashcards().first;
    expect(refs.single.cardId, 'card-1');

    await tester.pumpWidget(_appWith(
      firestore: firestore,
      savedFlashcardService: FirestoreSavedFlashcardService(
        firestore: firestore,
        uidProvider: () => 'anonymousUid123',
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
  });
}

Future<Widget> _app() async {
  final firestore = FakeFirebaseFirestore();
  await _seedFlashcard(firestore);

  return _appWith(firestore: firestore);
}

Future<void> _seedFlashcard(FakeFirebaseFirestore firestore) async {
  await firestore
      .doc(ContentPaths.module('math', 'chapter-1', 'flashcards'))
      .set({
    'title': 'Flashcards',
    'type': 'flashcards',
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

Widget _appWith({
  required FakeFirebaseFirestore firestore,
  SavedFlashcardService? savedFlashcardService,
}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: FlashcardScreen(
      subjectId: 'math',
      subjectName: 'Mathematics',
      chapter: const Chapter(
        id: 'chapter-1',
        chapterNumber: 1,
        title: 'Patterns and Sequences',
        textbookChapterTitle: '',
        learningObjectives: [],
        estimatedMinutes: 30,
        status: 'active',
        order: 1,
      ),
      repository: LearningRepository(firestore: firestore),
      savedFlashcardService: savedFlashcardService ??
          FirestoreSavedFlashcardService(
            firestore: firestore,
            uidProvider: () => 'anonymousUid123',
          ),
    ),
  );
}
