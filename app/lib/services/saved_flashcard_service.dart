import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/saved_flashcard.dart';

abstract class SavedFlashcardService {
  Stream<List<SavedFlashcardRef>> watchSavedFlashcards();

  Future<void> saveFlashcard({
    required String subjectId,
    required String chapterId,
    required String cardId,
  });

  Future<void> unsaveFlashcard({
    required String subjectId,
    required String chapterId,
    required String cardId,
  });
}

class SavedFlashcardServiceFactory {
  SavedFlashcardServiceFactory._();

  static SavedFlashcardService create() => FirestoreSavedFlashcardService();
}

class FirestoreSavedFlashcardService implements SavedFlashcardService {
  FirestoreSavedFlashcardService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    String Function()? uidProvider,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth,
        _uidProvider = uidProvider;

  final FirebaseFirestore _firestore;
  final FirebaseAuth? _auth;
  final String Function()? _uidProvider;

  @override
  Stream<List<SavedFlashcardRef>> watchSavedFlashcards() {
    return _collection(_uid)
        .orderBy('savedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SavedFlashcardRef.fromMap(doc.data()))
              .where((ref) =>
                  ref.subjectId.isNotEmpty &&
                  ref.chapterId.isNotEmpty &&
                  ref.cardId.isNotEmpty)
              .toList(growable: false),
        );
  }

  @override
  Future<void> saveFlashcard({
    required String subjectId,
    required String chapterId,
    required String cardId,
  }) {
    return _doc(_uid, subjectId, chapterId, cardId).set({
      'subjectId': subjectId,
      'chapterId': chapterId,
      'cardId': cardId,
      'savedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> unsaveFlashcard({
    required String subjectId,
    required String chapterId,
    required String cardId,
  }) {
    return _doc(_uid, subjectId, chapterId, cardId).delete();
  }

  CollectionReference<Map<String, dynamic>> _collection(String uid) {
    return _firestore
        .collection('student_progress')
        .doc(uid)
        .collection('saved_flashcards');
  }

  DocumentReference<Map<String, dynamic>> _doc(
    String uid,
    String subjectId,
    String chapterId,
    String cardId,
  ) {
    return _collection(uid).doc(SavedFlashcardRef.documentIdFor(
      subjectId: subjectId,
      chapterId: chapterId,
      cardId: cardId,
    ));
  }

  String get _uid {
    final provided = _uidProvider?.call();
    if (provided != null && provided.trim().isNotEmpty) return provided;
    final user = (_auth ?? FirebaseAuth.instance).currentUser;
    if (user == null) {
      throw StateError(
          'Student authentication is required before saving flashcards.');
    }
    return user.uid;
  }
}

class StaticSavedFlashcardService implements SavedFlashcardService {
  const StaticSavedFlashcardService([this.refs = const <SavedFlashcardRef>[]]);

  final List<SavedFlashcardRef> refs;

  @override
  Stream<List<SavedFlashcardRef>> watchSavedFlashcards() => Stream.value(refs);

  @override
  Future<void> saveFlashcard({
    required String subjectId,
    required String chapterId,
    required String cardId,
  }) async {}

  @override
  Future<void> unsaveFlashcard({
    required String subjectId,
    required String chapterId,
    required String cardId,
  }) async {}
}
