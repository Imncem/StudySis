import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../config/content_paths.dart';
import '../models/student.dart';
import '../models/subject.dart';

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<Student> watchQidah() {
    return _firestore.doc('students/qidah').snapshots().map((snapshot) {
      final projectId = Firebase.app().options.projectId;
      debugPrint(
        '[StudySis] Firestore snapshot: projectId=$projectId, '
        'path=students/qidah, exists=${snapshot.exists}',
      );
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        throw StateError(
          'Student profile not found at students/qidah in Firebase project '
          '"$projectId". Check that the document exists in this project.',
        );
      }
      return Student.fromMap(snapshot.id, data);
    });
  }

  Stream<List<Subject>> watchSubjects() {
    final subjects = _firestore
        .collection(ContentPaths.subjects)
        .orderBy('order')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Subject.fromMap(doc.id, doc.data()))
            .toList());
    final activeModules = _firestore
        .collectionGroup('modules')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((document) => _subjectIdForUsableModule(
                  document.reference.path,
                  document.data(),
                ))
            .whereType<String>()
            .toSet());
    return _combineSubjectReadiness(subjects, activeModules);
  }
}

const _verifiedSubjectIds = <String>{
  'bahasa_melayu',
  'english',
  'math',
  'science',
  'sejarah',
  'geography',
  'rbt',
  'pendidikan_islam',
  'pjk',
  'seni',
};

const _languageSubjectIds = <String>{'bahasa_melayu', 'english'};
const _studentModuleTypes = <String>{
  'notes',
  'flashcards',
  'practice',
  'quiz',
  'test',
  'review',
};

String? _subjectIdForUsableModule(
  String documentPath,
  Map<String, dynamic> data,
) {
  if (!_studentModuleTypes.contains(data['type'])) return null;
  final parts = documentPath.split('/');
  if (parts.length != 8 && parts.length != 10) return null;
  if (parts[0] != 'curriculum' ||
      parts[1] != ContentPaths.currentCurriculumId ||
      parts[2] != 'subjects' ||
      parts[4] != 'chapters') {
    return null;
  }
  final subjectId = parts[3];
  if (!_verifiedSubjectIds.contains(subjectId)) return null;
  if (parts.length == 8) {
    if (_languageSubjectIds.contains(subjectId) ||
        subjectId == 'sejarah' ||
        parts[6] != 'modules') {
      return null;
    }
  } else {
    final isLanguageModule = _languageSubjectIds.contains(subjectId) &&
        parts[6] == 'topics' &&
        parts[8] == 'modules';
    final isSejarahModule = subjectId == 'sejarah' &&
        parts[6] == 'subchapters' &&
        parts[8] == 'modules';
    if (!isLanguageModule && !isSejarahModule) return null;
  }
  return subjectId;
}

Stream<List<Subject>> _combineSubjectReadiness(
  Stream<List<Subject>> subjects,
  Stream<Set<String>> readySubjectIds,
) {
  late final StreamController<List<Subject>> controller;
  StreamSubscription<List<Subject>>? subjectSubscription;
  StreamSubscription<Set<String>>? readinessSubscription;
  List<Subject>? latestSubjects;
  Set<String>? latestReadySubjectIds;

  void emitIfReady() {
    final subjectValues = latestSubjects;
    final readyIds = latestReadySubjectIds;
    if (subjectValues == null || readyIds == null || controller.isClosed) {
      return;
    }
    controller.add(
      subjectValues
          .map(
              (subject) => subject.withReadiness(readyIds.contains(subject.id)))
          .toList(growable: false),
    );
  }

  controller = StreamController<List<Subject>>(
    onListen: () {
      subjectSubscription = subjects.listen(
        (value) {
          latestSubjects = value;
          emitIfReady();
        },
        onError: controller.addError,
      );
      readinessSubscription = readySubjectIds.listen(
        (value) {
          latestReadySubjectIds = value;
          emitIfReady();
        },
        onError: controller.addError,
      );
    },
    onCancel: () async {
      await subjectSubscription?.cancel();
      await readinessSubscription?.cancel();
    },
  );
  return controller.stream;
}
