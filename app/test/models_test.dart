import 'package:flutter_test/flutter_test.dart';
import 'package:studysis/models/student.dart';
import 'package:studysis/models/subject.dart';

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
}
