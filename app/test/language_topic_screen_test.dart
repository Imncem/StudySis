import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studysis/config/content_paths.dart';
import 'package:studysis/models/subject.dart';
import 'package:studysis/repositories/learning_repository.dart';
import 'package:studysis/screens/subject_screen.dart';

void main() {
  for (final entry in {
    'bahasa_melayu': ('Bahasa Melayu', 'Pemahaman'),
    'english': ('English', 'Grammar'),
  }.entries) {
    testWidgets('${entry.value.$1} navigates Section to Topic module sequence',
        (tester) async {
      final firestore = FakeFirebaseFirestore();
      await firestore.doc(ContentPaths.subject(entry.key)).set({
        'displayName': entry.value.$1,
      });
      await firestore.doc('${ContentPaths.chapters(entry.key)}/section-1').set({
        'chapterNumber': 1,
        'title': entry.value.$2,
        'textbookChapterTitle': entry.value.$2,
        'learningObjectives': <String>[],
        'estimatedMinutes': 20,
        'status': 'active',
        'order': 1,
      });
      await firestore
          .doc('${ContentPaths.topics(entry.key, 'section-1')}/topic-1')
          .set({
        'title': 'Topic One',
        'order': 1,
        'status': 'active',
      });
      await firestore
          .doc(ContentPaths.topicModule(
        entry.key,
        'section-1',
        'topic-1',
        'notes-1',
      ))
          .set({
        'title': 'Topic Notes',
        'type': 'notes',
        'content': 'Nested topic lesson',
        'summary': '',
        'estimatedMinutes': 5,
        'difficulty': 'easy',
        'order': 1,
        'status': 'active',
      });

      await tester.pumpWidget(MaterialApp(
        home: SubjectScreen(
          subject: Subject(
            id: entry.key,
            displayName: entry.value.$1,
            shortName: entry.value.$1,
            contentStatus: 'ready',
            iconName: 'language',
            themeColor: '#8067C7',
            order: 1,
          ),
          repository: LearningRepository(firestore: firestore),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text(entry.value.$2).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Topic One'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Topic Notes'));
      await tester.pumpAndSettle();

      expect(find.text('Nested topic lesson'), findsOneWidget);
      expect(find.text('This lesson is being prepared.'), findsNothing);
    });
  }
}
