import 'package:flutter_test/flutter_test.dart';
import 'package:studysis/models/student.dart';
import 'package:studysis/models/subject.dart';
import 'package:studysis/models/chapter.dart';
import 'package:studysis/models/learning_module.dart';
import 'package:studysis/models/note_section.dart';
import 'package:studysis/models/flashcard.dart';
import 'package:studysis/models/practice_question.dart';
import 'package:studysis/models/quiz_question.dart';

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

  test('practice question maps published multiple choice content', () {
    final question = PracticeQuestion.fromMap('practice-1', {
      'question': 'What is 2 + 2?',
      'options': ['2', '3', '4', '5'],
      'correctAnswerIndex': 2,
      'explanation': '2 + 2 equals 4.',
      'hint': 'Count two more after 2.',
      'topic': 'addition',
      'difficulty': 'easy',
      'order': 1,
      'status': 'active',
    });

    expect(question.isPublished, isTrue);
    expect(question.isValid, isTrue);
    expect(question.topic, 'addition');
    expect(question.options, hasLength(4));
    expect(question.correctAnswerIndex, 2);
  });

  test('practice question handles legacy answer data without crashing', () {
    final question = PracticeQuestion.fromMap('practice-2', {
      'question': 'Legacy question',
      'answer': 'Legacy answer',
      'isPublished': true,
    });

    expect(question.isValid, isFalse);
    expect(question.options, ['Legacy answer']);
    expect(question.correctAnswerIndex, -1);
    expect(question.status, 'active');
  });

  test('quiz question maps active assessment content', () {
    final question = QuizQuestion.fromMap('quiz-1', {
      'question': 'Which value is even?',
      'options': ['3', '5', '8', '9'],
      'correctOptionIndex': 2,
      'explanation': '8 is divisible by 2.',
      'difficulty': 'easy',
      'order': 1,
      'status': 'active',
    });

    expect(question.isActive, isTrue);
    expect(question.isValid, isTrue);
    expect(question.correctOptionIndex, 2);
  });

  test('quiz question handles invalid data without crashing', () {
    final question = QuizQuestion.fromMap('quiz-2', {
      'question': 'Incomplete quiz question',
      'options': ['Only one option'],
      'status': 'active',
    });

    expect(question.isActive, isTrue);
    expect(question.isValid, isFalse);
  });
}
