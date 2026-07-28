import 'package:flutter_test/flutter_test.dart';
import 'package:studysis/services/student_auth_service.dart';

void main() {
  test('reuses immediate current anonymous user without signing in again',
      () async {
    final client = _FakeStudentAuthClient(
      currentUser: const StudentAuthSession(
        uid: 'existing-anonymous-uid',
        isAnonymous: true,
      ),
    );
    final service = StudentAuthService(client: client);

    final user = await service.ensureSignedInAnonymously();

    expect(user.uid, 'existing-anonymous-uid');
    expect(client.signInCount, 0);
  });

  test('reuses restored auth-state user before signing in anonymously',
      () async {
    final client = _FakeStudentAuthClient(
      authStates: Stream.value(
        const StudentAuthSession(
          uid: 'restored-anonymous-uid',
          isAnonymous: true,
        ),
      ),
    );
    final service = StudentAuthService(client: client);

    final user = await service.ensureSignedInAnonymously();

    expect(user.uid, 'restored-anonymous-uid');
    expect(client.signInCount, 0);
  });

  test('signs in anonymously only when no current or restored user exists',
      () async {
    final client = _FakeStudentAuthClient(
      authStates: Stream.value(null),
      signedInUser: const StudentAuthSession(
        uid: 'new-anonymous-uid',
        isAnonymous: true,
      ),
    );
    final service = StudentAuthService(client: client);

    final user = await service.ensureSignedInAnonymously();

    expect(user.uid, 'new-anonymous-uid');
    expect(client.signInCount, 1);
  });

  test('anonymous authentication setup message names Firebase Console action',
      () {
    const error = StudentAuthException(
      'Anonymous Authentication must be enabled in Firebase Console > Authentication > Sign-in method > Anonymous.',
    );

    expect(error.toString(), contains('Anonymous Authentication'));
    expect(error.toString(), contains('Firebase Console'));
    expect(error.toString(), contains('Sign-in method'));
  });
}

class _FakeStudentAuthClient implements StudentAuthClient {
  _FakeStudentAuthClient({
    this.currentUser,
    Stream<StudentAuthSession?>? authStates,
    this.signedInUser = const StudentAuthSession(
      uid: 'signed-in-anonymous-uid',
      isAnonymous: true,
    ),
  }) : _authStates = authStates ?? Stream<StudentAuthSession?>.value(null);

  @override
  final StudentAuthSession? currentUser;
  final Stream<StudentAuthSession?> _authStates;
  final StudentAuthSession signedInUser;
  int signInCount = 0;

  @override
  Stream<StudentAuthSession?> authStateChanges() => _authStates;

  @override
  Future<StudentAuthSession> signInAnonymously() async {
    signInCount += 1;
    return signedInUser;
  }
}
