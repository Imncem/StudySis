import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Firestore rules contain owned Study Pet state access', () {
    final rules = File('../firestore.rules').readAsStringSync();

    expect(rules, contains('match /student_progress/{uid}/pet/{stateId}'));
    expect(rules, contains('request.auth.uid == uid'));
    expect(rules, contains('validStudyPetCreate(stateId)'));
    expect(rules, contains('validStudyPetUpdate(stateId)'));
    expect(rules, contains("validEggPetMapping(data.eggId, data.petId)"));
    expect(
        rules, contains('engagement.totalXp - before.xpBaselineAtSelection'));
    expect(rules, contains("duration.value(before.hatchDelayHours, 'h')"));
  });
}
