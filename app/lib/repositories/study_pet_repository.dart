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

  Future<void> updateHabitat(StudyPetHabitat habitat) async {
    final uid = _uid;
    await _stateRef(uid).update({
      'habitatTheme': habitat.storageId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> ensureGrowthBaseline({
    required int currentTotalXp,
  }) async {
    final uid = _uid;
    final ref = _stateRef(uid);
    final engagementRef = _engagementRef(uid);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      final engagementSnapshot = await transaction.get(engagementRef);
      final current = StudyPetState.fromMap(snapshot.data());
      if (!current.hasHatchling || current.xpBaselineAtHatch != null) {
        return;
      }
      final totalXp = _totalXpFromMap(
        engagementSnapshot.data(),
        fallback: currentTotalXp,
      );
      transaction.update(ref, {
        'growthStage': current.growthStage.storageId,
        'xpBaselineAtHatch': totalXp,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
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
        habitatTheme: current.habitatTheme,
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
    final engagementRef = _engagementRef(uid);
    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      final engagementSnapshot = await transaction.get(engagementRef);
      final totalXpAtHatch =
          _totalXpFromMap(engagementSnapshot.data(), fallback: currentTotalXp);
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
        'growthStage': StudyPetGrowthStage.hatchling.storageId,
        'xpBaselineAtHatch': totalXpAtHatch,
        'lastEvolutionAt': null,
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
        habitatTheme: current.habitatTheme,
        growthStage: StudyPetGrowthStage.hatchling,
        xpBaselineAtHatch: totalXpAtHatch,
      );
    });
  }

  Future<StudyPetState> evolvePet({
    required DateTime now,
  }) async {
    final uid = _uid;
    final ref = _stateRef(uid);
    final engagementRef = _engagementRef(uid);
    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      final engagementSnapshot = await transaction.get(engagementRef);
      final current = StudyPetState.fromMap(snapshot.data());
      if (!current.hasHatchling || current.hatchedAt == null) {
        throw StateError('No Study Buddy is ready to grow.');
      }
      final baseline = current.xpBaselineAtHatch;
      if (baseline == null) {
        throw StateError(
            'Growth baseline is being prepared. Please try again.');
      }
      final requirement =
          StudyPetGrowthRules.nextRequirementFor(current.growthStage);
      if (requirement == null) return current;
      final totalXp = _totalXpFromMap(engagementSnapshot.data());
      final growthXp = StudyPetGrowthRules.growthXp(
        currentTotalXp: totalXp,
        baselineAtHatch: baseline,
      );
      final elapsed = now.difference(current.hatchedAt!);
      final canEvolve = StudyPetGrowthRules.canEvolve(
        currentStage: current.growthStage,
        growthXp: growthXp,
        elapsedSinceHatch: elapsed.isNegative ? Duration.zero : elapsed,
      );
      if (!canEvolve) {
        throw StateError('Your Study Buddy is not ready to grow yet.');
      }
      transaction.update(ref, {
        'growthStage': requirement.stage.storageId,
        'lastEvolutionAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return StudyPetState(
        schemaVersion: current.schemaVersion,
        stage: current.stage,
        petUnlockAcknowledgedAt: current.petUnlockAcknowledgedAt,
        eggId: current.eggId,
        petId: current.petId,
        selectedAt: current.selectedAt,
        xpBaselineAtSelection: current.xpBaselineAtSelection,
        hatchXpTarget: current.hatchXpTarget,
        hatchDelayHours: current.hatchDelayHours,
        hatchedAt: current.hatchedAt,
        petName: current.petName,
        habitatTheme: current.habitatTheme,
        growthStage: requirement.stage,
        xpBaselineAtHatch: baseline,
        lastEvolutionAt: now,
      );
    });
  }

  DocumentReference<Map<String, dynamic>> _stateRef(String uid) {
    return _firestore.doc('student_progress/$uid/pet/state');
  }

  DocumentReference<Map<String, dynamic>> _engagementRef(String uid) {
    return _firestore.doc('student_progress/$uid/engagement/state');
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
    'habitatTheme': StudyPetHabitat.forest.storageId,
    'growthStage': null,
    'xpBaselineAtHatch': null,
    'lastEvolutionAt': null,
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
    'habitatTheme': StudyPetHabitat.forest.storageId,
    'growthStage': null,
    'xpBaselineAtHatch': null,
    'lastEvolutionAt': null,
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
    'habitatTheme': state.habitatTheme.storageId,
    'growthStage': state.stage == StudyPetStage.hatchling
        ? state.growthStage.storageId
        : null,
    'xpBaselineAtHatch': state.xpBaselineAtHatch,
    'lastEvolutionAt': state.lastEvolutionAt == null
        ? null
        : Timestamp.fromDate(state.lastEvolutionAt!),
  };
}

int _totalXpFromMap(Map<String, dynamic>? data, {int fallback = 0}) {
  final value = data?['totalXp'];
  if (value is int) return value;
  if (value is num) return value.toInt();
  return fallback;
}
