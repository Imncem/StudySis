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

enum StudyPetGrowthStage {
  hatchling,
  young,
  evolved,
  adult,
}

extension StudyPetGrowthStageLabels on StudyPetGrowthStage {
  String get storageId => name;

  String get displayName {
    return switch (this) {
      StudyPetGrowthStage.hatchling => 'Hatchling',
      StudyPetGrowthStage.young => 'Young',
      StudyPetGrowthStage.evolved => 'Evolved',
      StudyPetGrowthStage.adult => 'Adult',
    };
  }
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

enum StudyPetHabitat {
  forest,
  farm,
  house,
  garden,
}

extension StudyPetHabitatLabel on StudyPetHabitat {
  String get storageId => name;

  String get displayName {
    return switch (this) {
      StudyPetHabitat.forest => 'Forest',
      StudyPetHabitat.farm => 'Farm',
      StudyPetHabitat.house => 'Inside House',
      StudyPetHabitat.garden => 'Garden',
    };
  }
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

  String stageName(StudyPetGrowthStage growthStage) {
    return switch (id) {
      StudyPetId.fox => switch (growthStage) {
          StudyPetGrowthStage.hatchling => 'Spark Fox Hatchling',
          StudyPetGrowthStage.young => 'Young Spark Fox',
          StudyPetGrowthStage.evolved => 'Flare Fox',
          StudyPetGrowthStage.adult => 'Ember Guardian Fox',
        },
      StudyPetId.bunny => switch (growthStage) {
          StudyPetGrowthStage.hatchling => 'Sprout Bunny Hatchling',
          StudyPetGrowthStage.young => 'Young Sprout Bunny',
          StudyPetGrowthStage.evolved => 'Bloom Bunny',
          StudyPetGrowthStage.adult => 'Forest Guardian Bunny',
        },
      StudyPetId.cat => switch (growthStage) {
          StudyPetGrowthStage.hatchling => 'Starlight Cat Hatchling',
          StudyPetGrowthStage.young => 'Young Starlight Cat',
          StudyPetGrowthStage.evolved => 'Astral Cat',
          StudyPetGrowthStage.adult => 'Celestial Guardian Cat',
        },
    };
  }
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
    this.habitatTheme = StudyPetHabitat.forest,
    this.growthStage = StudyPetGrowthStage.hatchling,
    this.xpBaselineAtHatch,
    this.lastEvolutionAt,
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
  final StudyPetHabitat habitatTheme;
  final StudyPetGrowthStage growthStage;
  final int? xpBaselineAtHatch;
  final DateTime? lastEvolutionAt;

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
      habitatTheme: habitatFromStorageId(data['habitatTheme']?.toString()),
      growthStage: growthStageFromStorageId(data['growthStage']?.toString()),
      xpBaselineAtHatch: data['xpBaselineAtHatch'] == null
          ? null
          : _intValue(data['xpBaselineAtHatch']),
      lastEvolutionAt: timestampToDate(data['lastEvolutionAt']),
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

  int get growthXp => StudyPetGrowthRules.growthXp(
        currentTotalXp: engagement.totalXp,
        baselineAtHatch: pet.xpBaselineAtHatch,
      );

  Duration get elapsedSinceHatch {
    final hatchedAt = pet.hatchedAt;
    if (hatchedAt == null) return Duration.zero;
    final elapsed = now.difference(hatchedAt);
    return elapsed.isNegative ? Duration.zero : elapsed;
  }

  int get daysSinceHatch => elapsedSinceHatch.inDays;
  StudyPetGrowthRequirement? get nextGrowthRequirement =>
      StudyPetGrowthRules.nextRequirementFor(pet.growthStage);
  bool get hasGrowthBaseline => pet.xpBaselineAtHatch != null;
  bool get isFinalGrowthStage => pet.growthStage == StudyPetGrowthStage.adult;
  bool get readyToEvolve =>
      pet.hasHatchling &&
      hasGrowthBaseline &&
      StudyPetGrowthRules.canEvolve(
        currentStage: pet.growthStage,
        growthXp: growthXp,
        elapsedSinceHatch: elapsedSinceHatch,
      );

  int get cappedGrowthXp {
    final requirement = nextGrowthRequirement;
    if (requirement == null) return growthXp;
    return growthXp.clamp(0, requirement.requiredXp);
  }

  int get remainingGrowthXp {
    final requirement = nextGrowthRequirement;
    if (requirement == null) return 0;
    return (requirement.requiredXp - growthXp).clamp(0, requirement.requiredXp);
  }

  int get cappedGrowthDays {
    final requirement = nextGrowthRequirement;
    if (requirement == null) return daysSinceHatch;
    return daysSinceHatch.clamp(0, requirement.requiredDays);
  }

  int get remainingGrowthDays {
    final requirement = nextGrowthRequirement;
    if (requirement == null) return 0;
    return (requirement.requiredDays - daysSinceHatch)
        .clamp(0, requirement.requiredDays);
  }

  double get growthXpProgress {
    final requirement = nextGrowthRequirement;
    if (requirement == null || requirement.requiredXp <= 0) return 1;
    return cappedGrowthXp / requirement.requiredXp;
  }

  double get growthTimeProgress {
    final requirement = nextGrowthRequirement;
    if (requirement == null || requirement.requiredDuration.inMinutes <= 0) {
      return 1;
    }
    return (elapsedSinceHatch.inMinutes /
            requirement.requiredDuration.inMinutes)
        .clamp(0, 1);
  }
}

class StudyPetGrowthRequirement {
  const StudyPetGrowthRequirement({
    required this.stage,
    required this.requiredXp,
    required this.requiredDays,
  });

  final StudyPetGrowthStage stage;
  final int requiredXp;
  final int requiredDays;

  Duration get requiredDuration => Duration(days: requiredDays);
}

class StudyPetGrowthRules {
  const StudyPetGrowthRules._();

  static const requirements = [
    StudyPetGrowthRequirement(
      stage: StudyPetGrowthStage.young,
      requiredXp: 200,
      requiredDays: 2,
    ),
    StudyPetGrowthRequirement(
      stage: StudyPetGrowthStage.evolved,
      requiredXp: 500,
      requiredDays: 5,
    ),
    StudyPetGrowthRequirement(
      stage: StudyPetGrowthStage.adult,
      requiredXp: 900,
      requiredDays: 10,
    ),
  ];

  static int growthXp({
    required int currentTotalXp,
    required int? baselineAtHatch,
  }) {
    if (baselineAtHatch == null) return 0;
    return (currentTotalXp - baselineAtHatch).clamp(0, 1 << 30);
  }

  static StudyPetGrowthRequirement? nextRequirementFor(
    StudyPetGrowthStage currentStage,
  ) {
    return switch (currentStage) {
      StudyPetGrowthStage.hatchling => requirements[0],
      StudyPetGrowthStage.young => requirements[1],
      StudyPetGrowthStage.evolved => requirements[2],
      StudyPetGrowthStage.adult => null,
    };
  }

  static bool canEvolve({
    required StudyPetGrowthStage currentStage,
    required int growthXp,
    required Duration elapsedSinceHatch,
  }) {
    final requirement = nextRequirementFor(currentStage);
    if (requirement == null) return false;
    return growthXp >= requirement.requiredXp &&
        elapsedSinceHatch >= requirement.requiredDuration;
  }

  static bool isValidTransition({
    required StudyPetGrowthStage from,
    required StudyPetGrowthStage to,
  }) {
    return nextRequirementFor(from)?.stage == to;
  }
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

StudyPetHabitat habitatFromStorageId(String? value) {
  return switch (value) {
    'farm' => StudyPetHabitat.farm,
    'house' => StudyPetHabitat.house,
    'garden' => StudyPetHabitat.garden,
    _ => StudyPetHabitat.forest,
  };
}

StudyPetGrowthStage growthStageFromStorageId(String? value) {
  return switch (value) {
    'young' => StudyPetGrowthStage.young,
    'evolved' => StudyPetGrowthStage.evolved,
    'adult' => StudyPetGrowthStage.adult,
    _ => StudyPetGrowthStage.hatchling,
  };
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
