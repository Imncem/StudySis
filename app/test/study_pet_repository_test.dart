import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studysis/models/engagement.dart';
import 'package:studysis/models/study_pet.dart';
import 'package:studysis/repositories/engagement_repository.dart';
import 'package:studysis/repositories/study_pet_repository.dart';

const uid = 'anonymousUid123';

void main() {
  test('Level 1 and Level 2 students see locked pet state', () {
    final today = '2026-08-19';
    final level1 = StudyPetViewState(
      engagement: EngagementState.fromMap({'totalXp': 99}, todayDateKey: today),
      pet: StudyPetState.empty,
      now: DateTime.utc(2026, 8, 19),
    );
    final level2 = StudyPetViewState(
      engagement:
          EngagementState.fromMap({'totalXp': 249}, todayDateKey: today),
      pet: StudyPetState.empty,
      now: DateTime.utc(2026, 8, 19),
    );

    expect(level1.isUnlocked, isFalse);
    expect(level2.isUnlocked, isFalse);
    expect(level2.xpTowardUnlock, 249);
    expect(level2.xpToUnlock, 1);
  });

  test('Level 3 existing student unlocks pets without a pet document', () {
    final state = StudyPetViewState(
      engagement:
          EngagementState.fromMap({'totalXp': 250}, todayDateKey: '2026-08-19'),
      pet: StudyPetState.empty,
      now: DateTime.utc(2026, 8, 19),
    );

    expect(state.isUnlocked, isTrue);
    expect(state.shouldShowUnlockCelebration, isTrue);
  });

  test('dismissing unlock celebration does not relock feature', () {
    final state = StudyPetViewState(
      engagement:
          EngagementState.fromMap({'totalXp': 300}, todayDateKey: '2026-08-19'),
      pet: StudyPetState(
        schemaVersion: 1,
        stage: StudyPetStage.unselected,
        petUnlockAcknowledgedAt: DateTime.utc(2026, 8, 19),
      ),
      now: DateTime.utc(2026, 8, 19),
    );

    expect(state.isUnlocked, isTrue);
    expect(state.shouldShowUnlockCelebration, isFalse);
  });

  test('each egg has deterministic pet mapping and no dog pet', () {
    expect(petForEgg(studyEggs[0]).storageId, 'pet_fox');
    expect(petForEgg(studyEggs[1]).storageId, 'pet_bunny');
    expect(petForEgg(studyEggs[2]).storageId, 'pet_cat');
    expect(studyPets.map((pet) => pet.storageId), isNot(contains('pet_dog')));
  });

  test('egg selection persists baseline and prevents duplicate selection',
      () async {
    final firestore = FakeFirebaseFirestore();
    final repository = _repo(firestore);

    await repository.selectEgg(
      egg: studyEggs[0],
      currentTotalXp: 290,
    );
    await repository.selectEgg(
      egg: studyEggs[1],
      currentTotalXp: 310,
    );

    final data =
        (await firestore.doc('student_progress/$uid/pet/state').get()).data()!;
    expect(data['eggId'], 'egg_spark');
    expect(data['stage'], 'egg');
    expect(data['xpBaselineAtSelection'], 290);
    expect(data['hatchXpTarget'], hatchXpTargetDefault);
    expect(data['hatchDelayHours'], hatchDelayHoursDefault);
  });

  test('existing XP before selection counts as zero hatch XP', () {
    final selectedAt = DateTime.utc(2026, 8, 18, 10);
    final view = _view(
      totalXp: 290,
      pet: StudyPetState(
        schemaVersion: 1,
        stage: StudyPetStage.egg,
        eggId: 'egg_spark',
        selectedAt: selectedAt,
        xpBaselineAtSelection: 290,
      ),
      now: selectedAt.add(const Duration(hours: 1)),
    );

    expect(view.earnedPetXp, 0);
    expect(view.cappedHatchXp, 0);
  });

  test('new XP and elapsed time derive hatch readiness', () {
    final selectedAt = DateTime.utc(2026, 8, 18, 10);
    final pet = StudyPetState(
      schemaVersion: 1,
      stage: StudyPetStage.egg,
      eggId: 'egg_spark',
      selectedAt: selectedAt,
      xpBaselineAtSelection: 290,
    );

    expect(
      _view(
        totalXp: 390,
        pet: pet,
        now: selectedAt.add(const Duration(hours: 23, minutes: 59)),
      ).readyToHatch,
      isFalse,
    );
    expect(
      _view(
        totalXp: 350,
        pet: pet,
        now: selectedAt.add(const Duration(hours: 24)),
      ).readyToHatch,
      isFalse,
    );
    final ready = _view(
      totalXp: 470,
      pet: pet,
      now: selectedAt.add(const Duration(hours: 48)),
    );
    expect(ready.readyToHatch, isTrue);
    expect(ready.cappedHatchXp, 100);
  });

  test('hatch can occur only once and persists hatchling profile', () async {
    final firestore = FakeFirebaseFirestore();
    final repository = _repo(firestore);
    await firestore.doc('student_progress/$uid/pet/state').set({
      'schemaVersion': 1,
      'petUnlockAcknowledgedAt': Timestamp.fromDate(DateTime.utc(2026, 8, 17)),
      'eggId': 'egg_sprout',
      'petId': null,
      'stage': 'egg',
      'selectedAt': Timestamp.fromDate(DateTime.utc(2026, 8, 17, 10)),
      'xpBaselineAtSelection': 250,
      'hatchXpTarget': 100,
      'hatchDelayHours': 24,
      'hatchedAt': null,
      'petName': null,
      'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 8, 17, 10)),
    });

    await repository.hatchEgg(
      petName: ' Mochi ',
      currentTotalXp: 350,
      now: DateTime.utc(2026, 8, 18, 10),
    );
    await repository.hatchEgg(
      petName: 'Other',
      currentTotalXp: 500,
      now: DateTime.utc(2026, 8, 19, 10),
    );

    final data =
        (await firestore.doc('student_progress/$uid/pet/state').get()).data()!;
    expect(data['stage'], 'hatchling');
    expect(data['petId'], 'pet_bunny');
    expect(data['petName'], 'Mochi');
  });

  test('pet name validation trims and rejects invalid names', () {
    expect(validatePetName(' Mochi '), 'Mochi');
    expect(() => validatePetName(' A '), throwsFormatException);
    expect(
        () => validatePetName('VeryLongStudyBuddyName'), throwsFormatException);
  });

  test('viewing and choosing pet does not change Study Points, XP, or Bites',
      () async {
    final firestore = FakeFirebaseFirestore();
    await _seedEngagement(firestore, xp: 300, studyPoints: 2);
    final engagement = EngagementRepository(
      firestore: firestore,
      uidProvider: () => uid,
      nowProvider: () => DateTime.utc(2026, 8, 19),
    );
    final before = await engagement.readState();

    await _repo(firestore).selectEgg(
      egg: studyEggs[2],
      currentTotalXp: before.totalXp,
    );
    final after = await engagement.readState();
    final wallet = await firestore.doc('students/qidah/muffin/state').get();

    expect(after.totalXp, before.totalXp);
    expect(after.todayStudyPoints, before.todayStudyPoints);
    expect(wallet.exists, isFalse);
  });
}

StudyPetRepository _repo(FakeFirebaseFirestore firestore) {
  return StudyPetRepository(
    firestore: firestore,
    uidProvider: () => uid,
    nowProvider: () => DateTime.utc(2026, 8, 19),
  );
}

StudyPetViewState _view({
  required int totalXp,
  required StudyPetState pet,
  required DateTime now,
}) {
  return StudyPetViewState(
    engagement: EngagementState.fromMap(
      {'totalXp': totalXp},
      todayDateKey: '2026-08-19',
    ),
    pet: pet,
    now: now,
  );
}

Future<void> _seedEngagement(
  FakeFirebaseFirestore firestore, {
  required int xp,
  required int studyPoints,
}) async {
  await firestore.doc('student_progress/$uid/engagement/state').set({
    'totalXp': xp,
    'level': calculateLevel(xp),
    'currentStreak': 0,
    'longestStreak': 0,
    'lastQualifiedDate': null,
    'todayDateKey': '2026-08-19',
    'todayStudyPoints': studyPoints,
    'dailyStudyTarget': 3,
    'todayStreakSecured': false,
    'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 8, 19)),
  });
}
