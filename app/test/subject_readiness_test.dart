import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studysis/config/content_paths.dart';
import 'package:studysis/models/subject.dart';
import 'package:studysis/services/firestore_service.dart';

void main() {
  test('static subject metadata and draft modules do not make a subject ready',
      () async {
    final firestore = FakeFirebaseFirestore();
    await _seedSubject(firestore, 'math', 1, contentStatus: 'available');
    await _seedSubject(firestore, 'science', 2);
    await _seedModule(
      firestore,
      subjectId: 'science',
      itemId: 'chapter-01',
      status: 'draft',
    );

    final subjects = await FirestoreService(firestore: firestore)
        .watchSubjects()
        .first
        .timeout(const Duration(seconds: 2));

    expect(_byId(subjects, 'math').isComingSoon, isTrue);
    expect(_byId(subjects, 'science').isComingSoon, isTrue);
  });

  test('an active module makes every normal Form 2 subject ready', () async {
    final firestore = FakeFirebaseFirestore();
    const subjectIds = [
      'math',
      'science',
      'geography',
      'rbt',
      'pendidikan_islam',
      'pjk',
      'seni',
    ];
    for (var index = 0; index < subjectIds.length; index++) {
      final subjectId = subjectIds[index];
      await _seedSubject(firestore, subjectId, index + 1);
      await _seedModule(
        firestore,
        subjectId: subjectId,
        itemId: 'item-01',
        status: 'active',
      );
    }

    final subjects = await FirestoreService(firestore: firestore)
        .watchSubjects()
        .first
        .timeout(const Duration(seconds: 2));

    expect(subjects.map((subject) => subject.id), subjectIds);
    expect(subjects.every((subject) => !subject.isComingSoon), isTrue);
  });

  test('Sejarah requires an active module beneath a subchapter', () async {
    final firestore = FakeFirebaseFirestore();
    await _seedSubject(firestore, 'sejarah', 1);
    await _seedModule(
      firestore,
      subjectId: 'sejarah',
      itemId: 'chapter-01',
      status: 'active',
    );

    var subjects =
        await FirestoreService(firestore: firestore).watchSubjects().first;
    expect(_byId(subjects, 'sejarah').isComingSoon, isTrue);

    await firestore
        .doc(
            '${ContentPaths.subchapterModules('sejarah', 'chapter-01', 'subchapter_01_01')}/notes')
        .set(_moduleData('active'));
    subjects =
        await FirestoreService(firestore: firestore).watchSubjects().first;
    expect(_byId(subjects, 'sejarah').isComingSoon, isFalse);
  });

  test('nested active modules make Bahasa Melayu and English ready', () async {
    final firestore = FakeFirebaseFirestore();
    await _seedSubject(firestore, 'bahasa_melayu', 1);
    await _seedSubject(firestore, 'english', 2);
    await _seedTopicModule(
      firestore,
      subjectId: 'bahasa_melayu',
      sectionId: 'tatabahasa',
      topicId: 'kata_nama',
    );
    await _seedTopicModule(
      firestore,
      subjectId: 'english',
      sectionId: 'grammar',
      topicId: 'verbs',
    );

    final subjects = await FirestoreService(firestore: firestore)
        .watchSubjects()
        .first
        .timeout(const Duration(seconds: 2));

    expect(_byId(subjects, 'bahasa_melayu').isComingSoon, isFalse);
    expect(_byId(subjects, 'english').isComingSoon, isFalse);
  });

  test('reopening readiness reflects published and archived content', () async {
    final firestore = FakeFirebaseFirestore();
    await _seedSubject(firestore, 'science', 1);
    final module = firestore.doc(
      '${ContentPaths.modules('science', 'chapter-01')}/notes',
    );
    await module.set(_moduleData('draft'));
    final service = FirestoreService(firestore: firestore);

    var subjects = await service.watchSubjects().first;
    expect(_byId(subjects, 'science').isComingSoon, isTrue);

    await module.update({'status': 'active'});
    subjects = await service.watchSubjects().first;
    expect(_byId(subjects, 'science').isComingSoon, isFalse);

    await module.update({'status': 'archived'});
    subjects = await service.watchSubjects().first;
    expect(_byId(subjects, 'science').isComingSoon, isTrue);
  });

  test(
      'invalid module paths and unsupported module types do not unlock subjects',
      () async {
    final firestore = FakeFirebaseFirestore();
    await _seedSubject(firestore, 'science', 1);
    await _seedSubject(firestore, 'bahasa_melayu', 2);
    await _seedModule(
      firestore,
      subjectId: 'science',
      itemId: 'chapter-01',
      status: 'active',
      type: 'video',
    );
    await _seedModule(
      firestore,
      subjectId: 'bahasa_melayu',
      itemId: 'tatabahasa',
      status: 'active',
    );

    final subjects = await FirestoreService(firestore: firestore)
        .watchSubjects()
        .first
        .timeout(const Duration(seconds: 2));

    expect(subjects.every((subject) => subject.isComingSoon), isTrue);
  });
}

Subject _byId(List<Subject> subjects, String id) {
  return subjects.singleWhere((subject) => subject.id == id);
}

Future<void> _seedSubject(
  FakeFirebaseFirestore firestore,
  String id,
  int order, {
  String contentStatus = 'coming_soon',
}) {
  return firestore.doc(ContentPaths.subject(id)).set({
    'displayName': id,
    'shortName': id,
    'contentStatus': contentStatus,
    'iconName': 'book',
    'themeColor': '#7B8F72',
    'order': order,
  });
}

Future<void> _seedModule(
  FakeFirebaseFirestore firestore, {
  required String subjectId,
  required String itemId,
  required String status,
  String type = 'notes',
}) {
  return firestore
      .doc('${ContentPaths.modules(subjectId, itemId)}/$type')
      .set(_moduleData(status, type: type));
}

Future<void> _seedTopicModule(
  FakeFirebaseFirestore firestore, {
  required String subjectId,
  required String sectionId,
  required String topicId,
}) {
  return firestore
      .doc('${ContentPaths.topicModules(subjectId, sectionId, topicId)}/notes')
      .set(_moduleData('active'));
}

Map<String, Object> _moduleData(String status, {String type = 'notes'}) {
  return {
    'title': 'Learning module',
    'type': type,
    'status': status,
    'order': 1,
    'createdAt': Timestamp.fromMillisecondsSinceEpoch(0),
    'updatedAt': Timestamp.fromMillisecondsSinceEpoch(0),
  };
}
