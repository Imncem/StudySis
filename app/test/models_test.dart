import 'package:flutter_test/flutter_test.dart';
import 'package:studysis/models/student.dart';
import 'package:studysis/models/subject.dart';
import 'package:studysis/models/chapter.dart';
import 'package:studysis/models/learning_module.dart';
import 'package:studysis/models/note_section.dart';
import 'package:studysis/models/flashcard.dart';

void main() {
  test('student maps Firestore fields', () {
    final student = Student.fromMap('qidah', {
      'preferredLanguage': 'English',
      'dailyTargetMinutes': 25,
      'status': 'active',
    });
    expect(student.name, 'Qidah');
    expect(student.dailyTargetMinutes, 25);
  });

  test('coming soon subject is identified', () {
    final subject = Subject.fromMap('math', {
      'displayName': 'Mathematics',
      'contentStatus': 'coming_soon',
      'order': 1,
    });
    expect(subject.isComingSoon, isTrue);
    expect(subject.shortName, 'Mathematics');
  });

  test('chapter maps ordered active content', () {
    final chapter = Chapter.fromMap('chapter-1', {
      'chapterNumber': 1,
      'title': 'Patterns and Sequences',
      'textbookChapterTitle': 'Pola dan Jujukan',
      'learningObjectives': ['Recognise patterns', 'Continue sequences'],
      'estimatedMinutes': 45,
      'status': 'active',
      'order': 1,
    });

    expect(chapter.isActive, isTrue);
    expect(chapter.learningObjectives, hasLength(2));
  });

  test('learning module maps reader fields', () {
    final module = LearningModule.fromMap('notes-1', {
      'title': 'Understanding patterns',
      'type': 'flashcards',
      'content': 'Learning content',
      'summary': 'A short summary',
      'estimatedMinutes': 10,
      'difficulty': 'easy',
      'status': 'active',
      'order': 1,
    });

    expect(module.typeLabel, 'Flashcards');
    expect(module.isActive, isTrue);
  });

  test('note section maps structured content', () {
    final section = NoteSection.fromMap('section-1', {
      'heading': 'Recognising a pattern',
      'body': 'Look for a rule between consecutive terms.',
      'example': '2, 4, 6, 8',
      'order': 1,
    });

    expect(section.heading, 'Recognising a pattern');
    expect(section.order, 1);
  });

  test('flashcard maps active learning content', () {
    final card = Flashcard.fromMap('card-1', {
      'front': 'What is a sequence?',
      'back': 'An ordered list that follows a rule.',
      'hint': 'Think about order.',
      'order': 1,
      'status': 'active',
    });

    expect(card.isActive, isTrue);
    expect(card.back, contains('ordered list'));
  });
}
