import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/study_pet.dart';

class StudyPetRepository {
  StudyPetRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    String Function()? uidProvider,
    DateTime Function()? nowProvider,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth,
        _uidProvider = uidProvider,
        _nowProvider = nowProvider ?? DateTime.now;

  final FirebaseFirestore _firestore;
  final FirebaseAuth? _auth;
  final String Function()? _uidProvider;
  final DateTime Function() _nowProvider;

  Stream<StudyPetState> watchState() {
    final uid = _maybeUid;
    if (uid == null) return Stream.value(StudyPetState.empty);
    return _stateRef(uid).snapshots().map(
          (snapshot) => StudyPetState.fromMap(snapshot.data()),
        );
  }

  Future<StudyPetState> readState() async {
    final uid = _maybeUid;
    if (uid == null) return StudyPetState.empty;
    return StudyPetState.fromMap((await _stateRef(uid).get()).data());
  }

  Future<void> acknowledgeUnlock() async {
    final uid = _uid;
    await _stateRef(uid).set(_unselectedPayload(), SetOptions(merge: true));
  }

  Future<StudyPetState> selectEgg({
    required StudyEggDefinition egg,
    required int currentTotalXp,
  }) async {
    final uid = _uid;
    final ref = _stateRef(uid);
    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      final current = StudyPetState.fromMap(snapshot.data());
      if (current.stage != StudyPetStage.unselected) {
        return current;
      }
      transaction.set(ref, _eggPayload(egg, currentTotalXp));
      return StudyPetState(
        schemaVersion: 1,
        stage: StudyPetStage.egg,
        petUnlockAcknowledgedAt: _nowProvider(),
        eggId: egg.storageId,
        selectedAt: _nowProvider(),
        xpBaselineAtSelection: currentTotalXp,
        hatchXpTarget: hatchXpTargetDefault,
        hatchDelayHours: hatchDelayHoursDefault,
      );
    });
  }

  Future<StudyPetState> hatchEgg({
    required String petName,
    required int currentTotalXp,
    required DateTime now,
  }) async {
    final trimmedName = validatePetName(petName);
    final uid = _uid;
    final ref = _stateRef(uid);
    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      final current = StudyPetState.fromMap(snapshot.data());
      if (current.stage == StudyPetStage.hatchling) return current;
      final egg = current.egg;
      if (current.stage != StudyPetStage.egg ||
          egg == null ||
          current.selectedAt == null ||
          current.xpBaselineAtSelection == null) {
        throw StateError('No egg is ready to hatch.');
      }
      final earnedXp =
          (currentTotalXp - current.xpBaselineAtSelection!).clamp(0, 1 << 30);
      final elapsed = now.difference(current.selectedAt!);
      final ready = earnedXp >= current.hatchXpTarget &&
          !elapsed.isNegative &&
          elapsed >= Duration(hours: current.hatchDelayHours);
      if (!ready) {
        throw StateError('This egg is not ready to hatch yet.');
      }
      final pet = petForEgg(egg);
      transaction.set(ref, {
        ..._statePayload(current),
        'stage': 'hatchling',
        'petId': pet.storageId,
        'petName': trimmedName,
        'hatchedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return StudyPetState(
        schemaVersion: current.schemaVersion,
        stage: StudyPetStage.hatchling,
        petUnlockAcknowledgedAt: current.petUnlockAcknowledgedAt,
        eggId: current.eggId,
        petId: pet.storageId,
        selectedAt: current.selectedAt,
        xpBaselineAtSelection: current.xpBaselineAtSelection,
        hatchXpTarget: current.hatchXpTarget,
        hatchDelayHours: current.hatchDelayHours,
        hatchedAt: now,
        petName: trimmedName,
      );
    });
  }

  DocumentReference<Map<String, dynamic>> _stateRef(String uid) {
    return _firestore.doc('student_progress/$uid/pet/state');
  }

  String get debugStatePath =>
      'student_progress/${_maybeUid ?? '{uid}'}/pet/state';

  String get _uid {
    final uid = _maybeUid;
    if (uid != null) return uid;
    throw StateError('Student authentication is required for Study Pet.');
  }

  String? get _maybeUid {
    final provided = _uidProvider?.call();
    if (provided != null && provided.trim().isNotEmpty) return provided.trim();
    final user = (_auth ?? FirebaseAuth.instance).currentUser;
    return user?.uid;
  }
}

String validatePetName(String value) {
  final trimmed = value.trim();
  if (trimmed.length < 2) {
    throw const FormatException('Name must be at least 2 characters.');
  }
  if (trimmed.length > 15) {
    throw const FormatException('Name must be 15 characters or fewer.');
  }
  return trimmed;
}

Map<String, Object?> _unselectedPayload() {
  return {
    'schemaVersion': 1,
    'petUnlockAcknowledgedAt': FieldValue.serverTimestamp(),
    'eggId': null,
    'petId': null,
    'stage': 'unselected',
    'selectedAt': null,
    'xpBaselineAtSelection': null,
    'hatchXpTarget': hatchXpTargetDefault,
    'hatchDelayHours': hatchDelayHoursDefault,
    'hatchedAt': null,
    'petName': null,
    'updatedAt': FieldValue.serverTimestamp(),
  };
}

Map<String, Object?> _eggPayload(StudyEggDefinition egg, int currentTotalXp) {
  return {
    'schemaVersion': 1,
    'petUnlockAcknowledgedAt': FieldValue.serverTimestamp(),
    'eggId': egg.storageId,
    'petId': null,
    'stage': 'egg',
    'selectedAt': FieldValue.serverTimestamp(),
    'xpBaselineAtSelection': currentTotalXp,
    'hatchXpTarget': hatchXpTargetDefault,
    'hatchDelayHours': hatchDelayHoursDefault,
    'hatchedAt': null,
    'petName': null,
    'updatedAt': FieldValue.serverTimestamp(),
  };
}

Map<String, Object?> _statePayload(StudyPetState state) {
  return {
    'schemaVersion': state.schemaVersion,
    'petUnlockAcknowledgedAt': state.petUnlockAcknowledgedAt == null
        ? FieldValue.serverTimestamp()
        : Timestamp.fromDate(state.petUnlockAcknowledgedAt!),
    'eggId': state.eggId,
    'petId': state.petId,
    'stage': state.stage.name,
    'selectedAt':
        state.selectedAt == null ? null : Timestamp.fromDate(state.selectedAt!),
    'xpBaselineAtSelection': state.xpBaselineAtSelection,
    'hatchXpTarget': state.hatchXpTarget,
    'hatchDelayHours': state.hatchDelayHours,
    'hatchedAt':
        state.hatchedAt == null ? null : Timestamp.fromDate(state.hatchedAt!),
    'petName': state.petName,
  };
}
