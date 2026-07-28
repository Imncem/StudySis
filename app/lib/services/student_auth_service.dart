import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class StudentAuthService {
  StudentAuthService({FirebaseAuth? auth, StudentAuthClient? client})
      : _client =
            client ?? FirebaseStudentAuthClient(auth ?? FirebaseAuth.instance);

  final StudentAuthClient _client;

  StudentAuthSession? get currentUser => _client.currentUser;

  Stream<StudentAuthSession?> authStateChanges() => _client.authStateChanges();

  Future<StudentAuthSession> ensureSignedInAnonymously() async {
    final existing = _client.currentUser;
    if (existing != null) {
      debugPrint(
        '[StudySis][auth] Reusing current Firebase user: uid=${existing.uid} anonymous=${existing.isAnonymous}',
      );
      return existing;
    }

    final restored = await _initialAuthState();
    if (restored != null) {
      debugPrint(
        '[StudySis][auth] Reusing restored Firebase user: uid=${restored.uid} anonymous=${restored.isAnonymous}',
      );
      return restored;
    }

    try {
      debugPrint(
          '[StudySis][auth] No existing Firebase user; signing in anonymously.');
      final user = await _client.signInAnonymously();
      return user;
    } on FirebaseAuthException catch (error) {
      if (error.code == 'operation-not-allowed' ||
          error.code == 'admin-restricted-operation') {
        throw const StudentAuthException(
          'Anonymous Authentication must be enabled in Firebase Console > Authentication > Sign-in method > Anonymous.',
        );
      }
      throw StudentAuthException(
        'StudySis could not start the student session: ${error.message ?? error.code}',
      );
    }
  }

  Future<StudentAuthSession?> _initialAuthState() async {
    try {
      return await _client.authStateChanges().first.timeout(
            const Duration(seconds: 3),
            onTimeout: () => null,
          );
    } catch (_) {
      return null;
    }
  }
}

abstract class StudentAuthClient {
  StudentAuthSession? get currentUser;
  Stream<StudentAuthSession?> authStateChanges();
  Future<StudentAuthSession> signInAnonymously();
}

class FirebaseStudentAuthClient implements StudentAuthClient {
  FirebaseStudentAuthClient(this._auth);

  final FirebaseAuth _auth;

  @override
  StudentAuthSession? get currentUser => _auth.currentUser == null
      ? null
      : StudentAuthSession.fromFirebaseUser(_auth.currentUser!);

  @override
  Stream<StudentAuthSession?> authStateChanges() {
    return _auth.authStateChanges().map(
          (user) =>
              user == null ? null : StudentAuthSession.fromFirebaseUser(user),
        );
  }

  @override
  Future<StudentAuthSession> signInAnonymously() async {
    final credential = await _auth.signInAnonymously();
    final user = credential.user;
    if (user == null) {
      throw const StudentAuthException(
        'StudySis could not create an anonymous student session.',
      );
    }
    return StudentAuthSession.fromFirebaseUser(user);
  }
}

class StudentAuthSession {
  const StudentAuthSession({required this.uid, required this.isAnonymous});

  final String uid;
  final bool isAnonymous;

  factory StudentAuthSession.fromFirebaseUser(User user) {
    return StudentAuthSession(
      uid: user.uid,
      isAnonymous: user.isAnonymous,
    );
  }
}

class StudentAuthException implements Exception {
  const StudentAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
