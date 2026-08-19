import 'engagement.dart';

const petUnlockLevel = 3;
const petUnlockXp = 250;
const hatchXpTargetDefault = 100;
const hatchDelayHoursDefault = 24;

enum StudyPetStage {
  unselected,
  egg,
  hatchling,
}

enum StudyEggId {
  spark,
  sprout,
  starlight,
}

enum StudyPetId {
  fox,
  bunny,
  cat,
}

class StudyEggDefinition {
  const StudyEggDefinition({
    required this.id,
    required this.storageId,
    required this.displayName,
    required this.hint,
    required this.primaryColor,
    required this.secondaryColor,
    required this.petId,
  });

  final StudyEggId id;
  final String storageId;
  final String displayName;
  final String hint;
  final int primaryColor;
  final int secondaryColor;
  final StudyPetId petId;
}

class StudyPetDefinition {
  const StudyPetDefinition({
    required this.id,
    required this.storageId,
    required this.displayName,
    required this.icon,
    required this.primaryColor,
  });

  final StudyPetId id;
  final String storageId;
  final String displayName;
  final String icon;
  final int primaryColor;
}

const studyEggs = [
  StudyEggDefinition(
    id: StudyEggId.spark,
    storageId: 'egg_spark',
    displayName: 'Spark Egg',
    hint: 'Something energetic is moving inside...',
    primaryColor: 0xFFF1A66A,
    secondaryColor: 0xFFFFE1C8,
    petId: StudyPetId.fox,
  ),
  StudyEggDefinition(
    id: StudyEggId.sprout,
    storageId: 'egg_sprout',
    displayName: 'Sprout Egg',
    hint: 'This egg feels calm and warm...',
    primaryColor: 0xFF7DBA8D,
    secondaryColor: 0xFFDDF2DF,
    petId: StudyPetId.bunny,
  ),
  StudyEggDefinition(
    id: StudyEggId.starlight,
    storageId: 'egg_starlight',
    displayName: 'Starlight Egg',
    hint: 'You hear a tiny sound from inside...',
    primaryColor: 0xFF8799D6,
    secondaryColor: 0xFFE3E8FF,
    petId: StudyPetId.cat,
  ),
];

const studyPets = [
  StudyPetDefinition(
    id: StudyPetId.fox,
    storageId: 'pet_fox',
    displayName: 'Fox',
    icon: '🦊',
    primaryColor: 0xFFF1A66A,
  ),
  StudyPetDefinition(
    id: StudyPetId.bunny,
    storageId: 'pet_bunny',
    displayName: 'Bunny',
    icon: '🐰',
    primaryColor: 0xFF7DBA8D,
  ),
  StudyPetDefinition(
    id: StudyPetId.cat,
    storageId: 'pet_cat',
    displayName: 'Cat',
    icon: '🐱',
    primaryColor: 0xFF8799D6,
  ),
];

class StudyPetState {
  const StudyPetState({
    required this.schemaVersion,
    required this.stage,
    this.petUnlockAcknowledgedAt,
    this.eggId,
    this.petId,
    this.selectedAt,
    this.xpBaselineAtSelection,
    this.hatchXpTarget = hatchXpTargetDefault,
    this.hatchDelayHours = hatchDelayHoursDefault,
    this.hatchedAt,
    this.petName,
  });

  final int schemaVersion;
  final StudyPetStage stage;
  final DateTime? petUnlockAcknowledgedAt;
  final String? eggId;
  final String? petId;
  final DateTime? selectedAt;
  final int? xpBaselineAtSelection;
  final int hatchXpTarget;
  final int hatchDelayHours;
  final DateTime? hatchedAt;
  final String? petName;

  static const empty = StudyPetState(
    schemaVersion: 1,
    stage: StudyPetStage.unselected,
  );

  factory StudyPetState.fromMap(Map<String, dynamic>? data) {
    if (data == null) return StudyPetState.empty;
    return StudyPetState(
      schemaVersion: _intValue(data['schemaVersion'], fallback: 1),
      stage: _stageFromString(data['stage']?.toString()),
      petUnlockAcknowledgedAt: timestampToDate(data['petUnlockAcknowledgedAt']),
      eggId: data['eggId']?.toString(),
      petId: data['petId']?.toString(),
      selectedAt: timestampToDate(data['selectedAt']),
      xpBaselineAtSelection: data['xpBaselineAtSelection'] == null
          ? null
          : _intValue(data['xpBaselineAtSelection']),
      hatchXpTarget:
          _intValue(data['hatchXpTarget'], fallback: hatchXpTargetDefault),
      hatchDelayHours:
          _intValue(data['hatchDelayHours'], fallback: hatchDelayHoursDefault),
      hatchedAt: timestampToDate(data['hatchedAt']),
      petName: data['petName']?.toString(),
    );
  }

  bool get hasAcknowledgedUnlock => petUnlockAcknowledgedAt != null;
  bool get hasEgg => stage == StudyPetStage.egg && eggId != null;
  bool get hasHatchling =>
      stage == StudyPetStage.hatchling && petId != null && petName != null;

  StudyEggDefinition? get egg => eggDefinitionForStorageId(eggId);
  StudyPetDefinition? get pet => petDefinitionForStorageId(petId);
}

class StudyPetViewState {
  const StudyPetViewState({
    required this.engagement,
    required this.pet,
    required this.now,
  });

  final EngagementState engagement;
  final StudyPetState pet;
  final DateTime now;

  bool get isUnlocked => engagement.level >= petUnlockLevel;
  int get xpTowardUnlock => engagement.totalXp.clamp(0, petUnlockXp);
  int get xpToUnlock =>
      (petUnlockXp - engagement.totalXp).clamp(0, petUnlockXp);
  double get unlockProgress =>
      petUnlockXp <= 0 ? 1 : xpTowardUnlock / petUnlockXp;
  bool get shouldShowUnlockCelebration =>
      isUnlocked && !pet.hasAcknowledgedUnlock;

  int get earnedPetXp {
    final baseline = pet.xpBaselineAtSelection;
    if (baseline == null) return 0;
    return (engagement.totalXp - baseline).clamp(0, 1 << 30);
  }

  int get cappedHatchXp => earnedPetXp.clamp(0, pet.hatchXpTarget);
  int get remainingHatchXp =>
      (pet.hatchXpTarget - earnedPetXp).clamp(0, pet.hatchXpTarget);
  double get hatchXpProgress =>
      pet.hatchXpTarget <= 0 ? 1 : cappedHatchXp / pet.hatchXpTarget;
  bool get xpReady => earnedPetXp >= pet.hatchXpTarget;

  Duration get elapsedSinceSelection {
    final selectedAt = pet.selectedAt;
    if (selectedAt == null) return Duration.zero;
    final elapsed = now.difference(selectedAt);
    return elapsed.isNegative ? Duration.zero : elapsed;
  }

  Duration get hatchDelay => Duration(hours: pet.hatchDelayHours);
  bool get timeReady =>
      pet.selectedAt != null && elapsedSinceSelection >= hatchDelay;
  bool get readyToHatch => pet.hasEgg && xpReady && timeReady;
  int get elapsedHours => elapsedSinceSelection.inHours;
}

StudyEggDefinition? eggDefinitionForStorageId(String? id) {
  for (final egg in studyEggs) {
    if (egg.storageId == id) return egg;
  }
  return null;
}

StudyPetDefinition? petDefinitionForStorageId(String? id) {
  for (final pet in studyPets) {
    if (pet.storageId == id) return pet;
  }
  return null;
}

StudyPetDefinition petForEgg(StudyEggDefinition egg) {
  return studyPets.firstWhere((pet) => pet.id == egg.petId);
}

StudyPetStage _stageFromString(String? value) {
  return switch (value) {
    'egg' => StudyPetStage.egg,
    'hatchling' => StudyPetStage.hatchling,
    _ => StudyPetStage.unselected,
  };
}

int _intValue(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return fallback;
}
