import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studysis/models/engagement.dart';
import 'package:studysis/models/study_pet.dart';
import 'package:studysis/repositories/engagement_repository.dart';
import 'package:studysis/repositories/study_pet_repository.dart';
import 'package:studysis/screens/study_pet_screen.dart';
import 'package:studysis/theme/app_theme.dart';

const uid = 'anonymousUid123';

void main() {
  testWidgets('locked screen shows progress and creates no pet document',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    await _seedEngagement(firestore, xp: 180);

    await tester.pumpWidget(_app(firestore));
    await tester.pumpAndSettle();

    expect(find.text('Unlock at Level 3'), findsOneWidget);
    expect(find.text('⭐ 180 / 250 XP'), findsOneWidget);
    expect(find.text('70 XP to go!'), findsOneWidget);
    final petDoc = await firestore.doc('student_progress/$uid/pet/state').get();
    expect(petDoc.exists, isFalse);
  });

  testWidgets('each of the three eggs can be selected', (tester) async {
    for (final egg in studyEggs) {
      final firestore = FakeFirebaseFirestore();
      await _seedEngagement(firestore, xp: 300);
      await tester.pumpWidget(_app(firestore));
      await tester.pumpAndSettle();

      await tester.tap(find.text(egg.displayName));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Incubation'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Incubation').last);
      await tester.pumpAndSettle();

      final data =
          (await firestore.doc('student_progress/$uid/pet/state').get())
              .data()!;
      expect(data['eggId'], egg.storageId);
      expect(data['xpBaselineAtSelection'], 300);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('Hatch button appears only when XP and time are complete',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    await _seedEngagement(firestore, xp: 390);
    await _seedEgg(
      firestore,
      baselineXp: 290,
      selectedAt: DateTime.utc(2026, 8, 18, 10),
    );
    await tester.pumpWidget(_app(
      firestore,
      nowProvider: () => DateTime.utc(2026, 8, 19, 9, 59),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Hatch My Egg'), findsNothing);
    await tester.pumpWidget(_app(
      firestore,
      nowProvider: () => DateTime.utc(2026, 8, 19, 10),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Hatch My Egg'), findsOneWidget);
  });

  testWidgets('reduced-motion hatch flow remains usable and saves name',
      (tester) async {
    _setLargeSurface(tester);
    final firestore = FakeFirebaseFirestore();
    await _seedEngagement(firestore, xp: 390);
    await _seedEgg(
      firestore,
      eggId: 'egg_starlight',
      baselineXp: 290,
      selectedAt: DateTime.utc(2026, 8, 18, 10),
    );
    await tester.pumpWidget(_app(
      firestore,
      nowProvider: () => DateTime.utc(2026, 8, 19, 10),
      disableAnimations: true,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hatch My Egg'));
    await tester.pumpAndSettle();

    expect(find.text('You hatched a Cat!'), findsOneWidget);
    expect(find.text('Give your Study Buddy a name'), findsOneWidget);

    await tester.ensureVisible(find.text('Save Name'));
    await tester.tap(find.text('Save Name'));
    await tester.pumpAndSettle();
    expect(find.text('Name must be at least 2 characters.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), ' Luna ');
    await tester.ensureVisible(find.text('Save Name'));
    await tester.tap(find.text('Save Name'));
    await tester.pumpAndSettle();

    expect(find.text('Luna'), findsOneWidget);
    expect(find.text('Hatchling'), findsOneWidget);
    final data =
        (await firestore.doc('student_progress/$uid/pet/state').get()).data()!;
    expect(data['stage'], 'hatchling');
    expect(data['petId'], 'pet_cat');
    expect(data['petName'], 'Luna');
  });
}

void _setLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _app(
  FakeFirebaseFirestore firestore, {
  DateTime Function()? nowProvider,
  bool disableAnimations = false,
}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: StudyPetScreen(
        engagementRepository: EngagementRepository(
          firestore: firestore,
          uidProvider: () => uid,
          nowProvider: () => DateTime.utc(2026, 8, 19),
        ),
        petRepository: StudyPetRepository(
          firestore: firestore,
          uidProvider: () => uid,
          nowProvider: () => DateTime.utc(2026, 8, 19),
        ),
        nowProvider: nowProvider ?? () => DateTime.utc(2026, 8, 19),
        refreshInterval: const Duration(hours: 24),
      ),
    ),
  );
}

Future<void> _seedEngagement(
  FakeFirebaseFirestore firestore, {
  required int xp,
}) async {
  await firestore.doc('student_progress/$uid/engagement/state').set({
    'totalXp': xp,
    'level': calculateLevel(xp),
    'currentStreak': 0,
    'longestStreak': 0,
    'lastQualifiedDate': null,
    'todayDateKey': '2026-08-19',
    'todayStudyPoints': 0,
    'dailyStudyTarget': 3,
    'todayStreakSecured': false,
    'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 8, 19)),
  });
}

Future<void> _seedEgg(
  FakeFirebaseFirestore firestore, {
  String eggId = 'egg_spark',
  required int baselineXp,
  required DateTime selectedAt,
}) async {
  await firestore.doc('student_progress/$uid/pet/state').set({
    'schemaVersion': 1,
    'petUnlockAcknowledgedAt': Timestamp.fromDate(selectedAt),
    'eggId': eggId,
    'petId': null,
    'stage': 'egg',
    'selectedAt': Timestamp.fromDate(selectedAt),
    'xpBaselineAtSelection': baselineXp,
    'hatchXpTarget': 100,
    'hatchDelayHours': 24,
    'hatchedAt': null,
    'petName': null,
    'updatedAt': Timestamp.fromDate(selectedAt),
  });
}
