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
    return _firestore
        .collection(ContentPaths.subjects)
        .orderBy('order')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Subject.fromMap(doc.id, doc.data()))
            .toList());
  }
}
