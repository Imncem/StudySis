import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studysis/config/content_paths.dart';
import 'package:studysis/models/subject.dart';
import 'package:studysis/repositories/learning_repository.dart';
import 'package:studysis/screens/subject_screen.dart';

void main() {
  testWidgets('Sejarah shows active subchapters and active nested modules only',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    await firestore.doc('${ContentPaths.chapters('sejarah')}/chapter-01').set({
      'chapterNumber': 1,
      'title': 'Kerajaan Alam Melayu',
      'textbookChapterTitle': 'Kerajaan Alam Melayu',
      'learningObjectives': <String>[],
      'estimatedMinutes': 30,
      'status': 'active',
      'order': 1,
    });
    final subchapters = firestore.collection(
      ContentPaths.subchapters('sejarah', 'chapter-01'),
    );
    await subchapters.doc('subchapter_01_01').set({
      'number': '1.1',
      'title': 'Konsep Alam Melayu',
      'order': 1,
      'status': 'active',
    });
    await subchapters.doc('subchapter_01_02').set({
      'number': '1.2',
      'title': 'Draft Subchapter',
      'order': 2,
      'status': 'draft',
    });
    final modules = firestore.collection(ContentPaths.subchapterModules(
      'sejarah',
      'chapter-01',
      'subchapter_01_01',
    ));
    await modules.doc('notes').set({
      'title': 'Notes',
      'type': 'notes',
      'content': '',
      'summary': '',
      'estimatedMinutes': 5,
      'difficulty': 'easy',
      'order': 1,
      'status': 'active',
    });
    await modules.doc('quiz').set({
      'title': 'Draft Quiz',
      'type': 'quiz',
      'content': '',
      'summary': '',
      'estimatedMinutes': 5,
      'difficulty': 'easy',
      'order': 2,
      'status': 'draft',
    });

    await tester.pumpWidget(MaterialApp(
      home: SubjectScreen(
        subject: const Subject(
          id: 'sejarah',
          displayName: 'Sejarah',
          shortName: 'Sejarah',
          contentStatus: 'ready',
          iconName: 'history',
          themeColor: '#C96E5D',
          order: 3,
        ),
        repository: LearningRepository(firestore: firestore),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kerajaan Alam Melayu').last);
    await tester.pumpAndSettle();
    expect(find.text('Konsep Alam Melayu'), findsOneWidget);
    expect(find.text('Draft Subchapter'), findsNothing);

    await tester.tap(find.text('Konsep Alam Melayu'));
    await tester.pumpAndSettle();
    expect(find.text('Learning modules'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Draft Quiz'), findsNothing);
  });
}
