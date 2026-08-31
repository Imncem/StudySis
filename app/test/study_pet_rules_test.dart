import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Firestore rules contain owned Study Pet state access', () {
    final rules = File('../firestore.rules').readAsStringSync();

    expect(rules, contains('match /student_progress/{uid}/pet/{stateId}'));
    expect(rules, contains('request.auth.uid == uid'));
    expect(rules, contains('validStudyPetCreate(stateId)'));
    expect(rules, contains('validStudyPetUpdate(stateId)'));
    expect(rules, contains('validStudyPetEvolutionUpdate(stateId)'));
    expect(rules, contains("validEggPetMapping(data.eggId, data.petId)"));
    expect(rules, contains('validPetHabitat(data)'));
    expect(rules, contains("'forest', 'farm', 'house', 'garden'"));
    expect(
        rules, contains('engagement.totalXp - before.xpBaselineAtSelection'));
    expect(rules, contains("duration.value(before.hatchDelayHours, 'h')"));
  });

  group('Study Pet habitat Firestore rules', () {
    late String rules;

    setUpAll(() {
      rules = File('../firestore.rules').readAsStringSync();
    });

    test('owner can change forest to farm', () {
      expect(rules, contains('validStudyPetHabitatUpdate(stateId)'));
      expect(rules, contains('validPetHabitatValue(data.habitatTheme)'));
      expect(rules, contains("'forest', 'farm', 'house', 'garden'"));
      expect(rules, contains("'farm'"));
    });

    test('owner can change farm to house', () {
      expect(rules, contains('validStudyPetHabitatUpdate(stateId)'));
      expect(rules, contains("'farm'"));
      expect(rules, contains("'house'"));
    });

    test('owner can change house to garden', () {
      expect(rules, contains('validStudyPetHabitatUpdate(stateId)'));
      expect(rules, contains("'house'"));
      expect(rules, contains("'garden'"));
    });

    test('invalid habitat is rejected', () {
      expect(rules, contains('function validPetHabitatValue(value)'));
      expect(rules, isNot(contains("'moon'")));
      expect(rules, contains('validPetHabitat(data)'));
    });

    test('another user cannot modify habitat', () {
      expect(rules, contains('allow update: if isSignedIn()'));
      expect(rules, contains('request.auth.uid == uid'));
    });

    test('habitat update cannot illegally alter stage', () {
      expect(
        rules,
        contains(
          "affectedKeys()\n          .hasOnly(['habitatTheme', 'updatedAt'])",
        ),
      );
      expect(rules, contains('validStudyPetState()'));
      expect(rules, contains('petStageRank(after.stage)'));
    });

    test('habitat update cannot alter hatch requirements', () {
      expect(
        rules,
        contains(
          "affectedKeys()\n          .hasOnly(['habitatTheme', 'updatedAt'])",
        ),
      );
      expect(rules, contains('after.hatchXpTarget == before.hatchXpTarget'));
      expect(
          rules, contains('after.hatchDelayHours == before.hatchDelayHours'));
      expect(
          rules, contains('engagement.totalXp - before.xpBaselineAtSelection'));
    });

    test('old document without habitatTheme remains valid', () {
      expect(rules, contains("!data.keys().hasAny(['habitatTheme'])"));
      expect(rules, contains('|| validPetHabitatValue(data.habitatTheme)'));
    });
  });

  group('Study Pet evolution Firestore rules', () {
    late String rules;

    setUpAll(() {
      rules = File('../firestore.rules').readAsStringSync();
    });

    test('owner can evolve when XP and time are valid', () {
      expect(rules, contains('validStudyPetEvolutionUpdate(stateId)'));
      expect(rules, contains('validStudyPetEvolutionState'));
      expect(rules, contains('validPetGrowthRequirement'));
      expect(rules, contains('engagement.totalXp - after.xpBaselineAtHatch'));
      expect(rules, contains("request.time >= after.hatchedAt"));
      expect(rules, contains('request.auth.uid == uid'));
    });

    test('exact Momo 430 total XP and 230 hatch baseline case is supported',
        () {
      final evolutionRule = _functionBody(
        rules,
        'function validStudyPetEvolutionUpdate(stateId)',
      );
      expect(evolutionRule, contains('validStudyPetEvolutionState'));
      expect(evolutionRule, isNot(contains('validStudyPetState()')));
      expect(rules, contains('data.stage == \'hatchling\''));
      expect(rules, contains('validEggPetMapping(data.eggId, data.petId)'));
      expect(rules, contains('data.xpBaselineAtHatch is int'));
      expect(rules, contains("to == 'young'"));
      expect(rules, contains('>= 200'));
      expect(rules, contains("duration.value(48, 'h')"));
    });

    test('owner cannot evolve with insufficient XP', () {
      expect(rules, contains('>= 200'));
      expect(rules, contains('>= 500'));
      expect(rules, contains('>= 900'));
      expect(rules, contains('validCount(engagement.totalXp)'));
    });

    test('owner cannot evolve before required time', () {
      expect(rules, contains("duration.value(48, 'h')"));
      expect(rules, contains("duration.value(120, 'h')"));
      expect(rules, contains("duration.value(240, 'h')"));
    });

    test('owner cannot skip stages or regress', () {
      expect(rules, contains("from == 'hatchling' && to == 'young'"));
      expect(rules, contains("from == 'young' && to == 'evolved'"));
      expect(rules, contains("from == 'evolved' && to == 'adult'"));
      expect(rules, isNot(contains("from == 'hatchling' && to == 'adult'")));
      expect(rules, isNot(contains("from == 'adult' && to == 'evolved'")));
    });

    test('other user cannot evolve pet', () {
      expect(rules, contains('allow update: if isSignedIn()'));
      expect(rules, contains('request.auth.uid == uid'));
    });

    test('habitat update still works separately', () {
      expect(rules, contains('validStudyPetHabitatUpdate(stateId)'));
      expect(
        rules,
        contains(
          "affectedKeys()\n          .hasOnly(['habitatTheme', 'updatedAt'])",
        ),
      );
    });

    test('changing xpBaselineAtHatch during evolution is rejected', () {
      final evolutionRule = _functionBody(
        rules,
        'function validStudyPetEvolutionUpdate(stateId)',
      );
      expect(
        evolutionRule,
        contains(".hasOnly(['growthStage', 'lastEvolutionAt', 'updatedAt'])"),
      );
      expect(
        evolutionRule,
        contains(
          'request.resource.data.xpBaselineAtHatch == resource.data.xpBaselineAtHatch',
        ),
      );
    });

    test('changing hatchedAt during evolution is rejected', () {
      final evolutionRule = _functionBody(
        rules,
        'function validStudyPetEvolutionUpdate(stateId)',
      );
      expect(
        evolutionRule,
        contains(".hasOnly(['growthStage', 'lastEvolutionAt', 'updatedAt'])"),
      );
      expect(evolutionRule, isNot(contains("'hatchedAt'")));
    });

    test('pet name and hatch protections remain valid', () {
      expect(rules, contains('validPetName(data.petName)'));
      expect(rules, contains('after.petName == before.petName'));
      expect(
          rules, contains('engagement.totalXp - before.xpBaselineAtSelection'));
      expect(rules, contains("duration.value(before.hatchDelayHours, 'h')"));
    });

    test('old hatchling can receive a growth baseline without evolving', () {
      expect(rules, contains('validStudyPetGrowthBaselineUpdate(stateId)'));
      expect(
        rules,
        contains(
          ".hasOnly(['growthStage', 'xpBaselineAtHatch', 'updatedAt'])",
        ),
      );
      expect(
          rules, contains("request.resource.data.growthStage == 'hatchling'"));
    });
  });
}

String _functionBody(String rules, String signature) {
  final start = rules.indexOf(signature);
  expect(start, isNot(-1), reason: 'Missing $signature');
  final next = rules.indexOf('\n    function ', start + signature.length);
  return rules.substring(start, next == -1 ? rules.length : next);
}
