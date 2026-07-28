import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/chapter_progress.dart';
import '../screens/practice_screen.dart';
import '../screens/quiz_screen.dart';

class StudentProgressRepository {
  StudentProgressRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    String Function()? uidProvider,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth,
        _uidProvider = uidProvider;

  final FirebaseFirestore _firestore;
  final FirebaseAuth? _auth;
  final String Function()? _uidProvider;

  Stream<ChapterProgress> streamChapterProgress({
    required String subjectId,
    required String chapterId,
  }) {
    final uid = _uid;
    return _doc(uid, subjectId, chapterId).snapshots().map(
          (snapshot) => ChapterProgress.fromMap(
            subjectId: subjectId,
            chapterId: chapterId,
            data: snapshot.data(),
          ),
        );
  }

  Future<ChapterProgress> getChapterProgress({
    required String subjectId,
    required String chapterId,
  }) async {
    final uid = _uid;
    final snapshot = await _doc(uid, subjectId, chapterId).get();
    return ChapterProgress.fromMap(
      subjectId: subjectId,
      chapterId: chapterId,
      data: snapshot.data(),
    );
  }

  Future<void> markLearnCompleted({
    required String subjectId,
    required String chapterId,
  }) {
    return _updateProgress(
      operation: 'markLearnCompleted',
      subjectId: subjectId,
      chapterId: chapterId,
      update: (progress) => {
        'learnCompleted': true,
        if (!progress.learnCompleted)
          'learnCompletedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  Future<void> updateFlashcardProgress({
    required String subjectId,
    required String chapterId,
    required int masteredCount,
    required int totalCount,
    List<String>? masteredCardIds,
  }) {
    final safeMastered =
        masteredCount.clamp(0, totalCount < 0 ? 0 : totalCount);
    final safeTotal = totalCount < 0 ? 0 : totalCount;
    return _updateProgress(
      operation: 'updateFlashcardProgress',
      subjectId: subjectId,
      chapterId: chapterId,
      update: (_) => {
        'flashcardsMasteredCount': safeMastered,
        'flashcardsTotalCount': safeTotal,
        'flashcardsCompleted': safeTotal > 0 && safeMastered >= safeTotal,
        if (masteredCardIds != null) 'masteredFlashcardIds': masteredCardIds,
      },
    );
  }

  Future<void> recordPracticeResult({
    required String subjectId,
    required String chapterId,
    required PracticeResult result,
  }) {
    final latest = result.percentage;
    return _updateProgress(
      operation: 'recordPracticeResult',
      subjectId: subjectId,
      chapterId: chapterId,
      update: (progress) => {
        'practiceLatestPercentage': latest,
        'practiceBestPercentage': latest > progress.practiceBestPercentage
            ? latest
            : progress.practiceBestPercentage,
        'practiceCorrectCount': result.correctAnswers,
        'practiceTotalQuestions': result.totalQuestions,
        'practiceCompletedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  Future<void> recordQuizResult({
    required String subjectId,
    required String chapterId,
    required QuizResult result,
  }) {
    final latest = result.percentage;
    return _updateProgress(
      operation: 'recordQuizResult',
      subjectId: subjectId,
      chapterId: chapterId,
      update: (progress) => {
        'quizLatestPercentage': latest,
        'quizBestPercentage': latest > progress.quizBestPercentage
            ? latest
            : progress.quizBestPercentage,
        'quizCorrectCount': result.correctCount,
        'quizIncorrectCount': result.incorrectCount,
        'quizUnansweredCount': result.unansweredCount,
        'quizPassed': result.passed,
        'quizCompletedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  Future<void> _updateProgress({
    required String operation,
    required String subjectId,
    required String chapterId,
    required Map<String, Object?> Function(ChapterProgress progress) update,
  }) async {
    final uid = _uid;
    final ref = _doc(uid, subjectId, chapterId);
    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(ref);
        final existing = snapshot.data();
        final current = ChapterProgress.fromMap(
          subjectId: subjectId,
          chapterId: chapterId,
          data: existing,
        );
        final fields = update(current);
        final next = _nextProgress(current, fields);
        final payload = {
          if (existing == null)
            ..._initialProgressPayload(
              subjectId: subjectId,
              chapterId: chapterId,
            )
          else
            ...existing,
          'studentProfileId': 'qidah',
          'subjectId': subjectId,
          'chapterId': chapterId,
          ...fields,
          'overallProgress': next,
          'lastActivityAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };
        _logProgressWrite(
          operation: operation,
          uid: uid,
          path: ref.path,
          payload: payload,
        );
        transaction.set(ref, payload);
      });
    } on FirebaseException catch (error, stackTrace) {
      _logProgressFailure(
        operation: operation,
        uid: uid,
        path: ref.path,
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  int _nextProgress(ChapterProgress current, Map<String, Object?> fields) {
    final practiceCompleted =
        fields.containsKey('practiceCompletedAt') || current.practiceCompleted;
    final quizCompleted =
        fields.containsKey('quizCompletedAt') || current.quizCompleted;
    return calculateOverallProgress(
      learnCompleted:
          fields['learnCompleted'] == true || current.learnCompleted,
      flashcardsMasteredCount: (fields['flashcardsMasteredCount'] as int?) ??
          current.flashcardsMasteredCount,
      flashcardsTotalCount: (fields['flashcardsTotalCount'] as int?) ??
          current.flashcardsTotalCount,
      practiceCompleted: practiceCompleted,
      quizCompleted: quizCompleted,
    );
  }

  Map<String, Object?> _initialProgressPayload({
    required String subjectId,
    required String chapterId,
  }) {
    return {
      'studentProfileId': 'qidah',
      'subjectId': subjectId,
      'chapterId': chapterId,
      'learnCompleted': false,
      'learnCompletedAt': null,
      'flashcardsMasteredCount': 0,
      'flashcardsTotalCount': 0,
      'flashcardsCompleted': false,
      'masteredFlashcardIds': <String>[],
      'practiceLatestPercentage': 0,
      'practiceBestPercentage': 0,
      'practiceCorrectCount': 0,
      'practiceTotalQuestions': 0,
      'practiceCompletedAt': null,
      'quizLatestPercentage': 0,
      'quizBestPercentage': 0,
      'quizCorrectCount': 0,
      'quizIncorrectCount': 0,
      'quizUnansweredCount': 0,
      'quizPassed': false,
      'quizCompletedAt': null,
      'overallProgress': 0,
      'lastActivityAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  DocumentReference<Map<String, dynamic>> _doc(
    String uid,
    String subjectId,
    String chapterId,
  ) {
    return _firestore
        .collection('student_progress')
        .doc(uid)
        .collection('chapters')
        .doc('${subjectId}_$chapterId');
  }

  String get _uid {
    final provided = _uidProvider?.call();
    if (provided != null && provided.trim().isNotEmpty) return provided;
    final user = (_auth ?? FirebaseAuth.instance).currentUser;
    if (user == null) {
      throw StateError(
          'Student authentication is required before saving progress.');
    }
    return user.uid;
  }

  void _logProgressWrite({
    required String operation,
    required String uid,
    required String path,
    required Map<String, Object?> payload,
  }) {
    final user = _currentUserForDiagnostics();
    debugPrint('[StudySis][progress] operation=$operation');
    debugPrint('[StudySis][progress] projectId=${_projectIdForDiagnostics()}');
    debugPrint(
        '[StudySis][progress] auth.uid=$uid anonymous=${user?.isAnonymous}');
    debugPrint('[StudySis][progress] path=$path');
    debugPrint('[StudySis][progress] payload=${_stringifyPayload(payload)}');
  }

  void _logProgressFailure({
    required String operation,
    required String uid,
    required String path,
    required FirebaseException error,
    required StackTrace stackTrace,
  }) {
    final user = _currentUserForDiagnostics();
    debugPrint('[StudySis][progress][error] operation=$operation');
    debugPrint(
        '[StudySis][progress][error] projectId=${_projectIdForDiagnostics()}');
    debugPrint(
        '[StudySis][progress][error] auth.uid=$uid anonymous=${user?.isAnonymous}');
    debugPrint('[StudySis][progress][error] path=$path');
    debugPrint('[StudySis][progress][error] code=${error.code}');
    debugPrint('[StudySis][progress][error] message=${error.message}');
    debugPrint('[StudySis][progress][error] stackTrace=$stackTrace');
  }

  Map<String, String> _stringifyPayload(Map<String, Object?> payload) {
    return payload.map((key, value) => MapEntry(key, value.toString()));
  }

  User? _currentUserForDiagnostics() {
    if (_auth != null) return _auth.currentUser;
    if (_uidProvider != null) return null;
    return FirebaseAuth.instance.currentUser;
  }

  String _projectIdForDiagnostics() {
    try {
      return _firestore.app.options.projectId;
    } catch (_) {
      return 'unavailable';
    }
  }
}
