import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studysis/models/engagement.dart';
import 'package:studysis/models/study_pet.dart';
import 'package:studysis/repositories/engagement_repository.dart';
import 'package:studysis/repositories/pet_economy_repository.dart';
import 'package:studysis/repositories/study_pet_repository.dart';
import 'package:studysis/screens/study_pet_screen.dart';
import 'package:studysis/theme/app_theme.dart';
import 'package:studysis/widgets/pet_cosmetic_overlay.dart';

const uid = 'anonymousUid123';

void main() {
  testWidgets('locked screen shows progress and creates no pet document',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    await _seedEngagement(firestore, xp: 180);

    await tester.pumpWidget(_app(firestore));
    await tester.pumpAndSettle();

    expect(find.text('Mystery Study Buddy'), findsOneWidget);
    expect(find.text('Unlock at Level 3'), findsOneWidget);
    expect(find.text('180 / 250 XP'), findsOneWidget);
    expect(find.text('70 XP to go!'), findsOneWidget);
    final petDoc = await firestore.doc('student_progress/$uid/pet/state').get();
    expect(petDoc.exists, isFalse);
  });

  testWidgets('each of the three eggs can be selected', (tester) async {
    _setLargeSurface(tester);
    for (final egg in studyEggs) {
      final firestore = FakeFirebaseFirestore();
      await _seedEngagement(firestore, xp: 300);
      await tester.pumpWidget(_app(firestore));
      await tester.pumpAndSettle();

      await tester.tap(find.text(egg.displayName));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Start Incubation'));
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

  testWidgets('egg selection shows personality hints', (tester) async {
    _setLargeSurface(tester);
    final firestore = FakeFirebaseFirestore();
    await _seedEngagement(firestore, xp: 300);

    await tester.pumpWidget(_app(firestore));
    await tester.pumpAndSettle();

    expect(find.text('Egg Selection'), findsOneWidget);
    expect(find.text('Energetic, clever, and adventurous.'), findsOneWidget);
    expect(find.text('Gentle, calm, and caring.'), findsOneWidget);
    expect(find.text('Curious, dreamy, and magical.'), findsOneWidget);
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

  testWidgets('incubation explains partial XP and time requirements',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    await _seedEngagement(firestore, xp: 350);
    await _seedEgg(
      firestore,
      baselineXp: 290,
      selectedAt: DateTime.utc(2026, 8, 18, 8),
    );

    await tester.pumpWidget(_app(
      firestore,
      nowProvider: () => DateTime.utc(2026, 8, 19, 10),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Learning energy'), findsOneWidget);
    expect(find.text('60 / 100 XP'), findsOneWidget);
    expect(find.text('Time together'), findsOneWidget);
    expect(find.text('Ready'), findsOneWidget);
    expect(find.textContaining('Earn 40 more XP'), findsOneWidget);
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
    expect(find.textContaining('Hatchling'), findsOneWidget);
    expect(find.text('Growth'), findsOneWidget);
    final data =
        (await firestore.doc('student_progress/$uid/pet/state').get()).data()!;
    expect(data['stage'], 'hatchling');
    expect(data['petId'], 'pet_cat');
    expect(data['petName'], 'Luna');
    expect(data['growthStage'], 'hatchling');
    expect(data['xpBaselineAtHatch'], 390);
  });

  testWidgets('hatched pet shows habitat selector and renders all habitats',
      (tester) async {
    _setLargeSurface(tester);
    final firestore = FakeFirebaseFirestore();
    await _seedEngagement(firestore, xp: 390);
    await _seedHatchling(firestore, petId: 'pet_bunny', petName: 'Momo');

    await tester.pumpWidget(_app(firestore));
    await tester.pumpAndSettle();

    expect(find.text('Momo'), findsOneWidget);
    expect(find.text('Choose your habitat'), findsOneWidget);
    expect(find.text('Forest'), findsWidgets);
    expect(find.text('Farm'), findsOneWidget);
    expect(find.text('Inside House'), findsOneWidget);
    expect(find.text('Garden'), findsOneWidget);

    for (final habitat in StudyPetHabitat.values.where(
      (habitat) => habitat != StudyPetHabitat.forest,
    )) {
      await tester.tap(find.text(habitat.displayName).last);
      await tester.pumpAndSettle();
      final data =
          (await firestore.doc('student_progress/$uid/pet/state').get())
              .data()!;
      expect(data['habitatTheme'], habitat.storageId);
    }
  });

  testWidgets('habitat selector appears only for hatchling pets',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    await _seedEngagement(firestore, xp: 390);
    await _seedEgg(
      firestore,
      baselineXp: 290,
      selectedAt: DateTime.utc(2026, 8, 18, 10),
    );

    await tester.pumpWidget(_app(firestore));
    await tester.pumpAndSettle();

    expect(find.text('Choose your habitat'), findsNothing);
    expect(find.text('Incubation progress'), findsOneWidget);
  });

  testWidgets('habitat selector works at narrow mobile width without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(340, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final firestore = FakeFirebaseFirestore();
    await _seedEngagement(firestore, xp: 390);
    await _seedHatchling(firestore, habitatTheme: 'farm');

    await tester.pumpWidget(_app(firestore));
    await tester.pumpAndSettle();

    expect(find.text('Choose your habitat'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('habitats render in dark mode', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await _seedEngagement(firestore, xp: 390);
    await _seedHatchling(firestore, habitatTheme: 'house');

    await tester.pumpWidget(_app(firestore, darkMode: true));
    await tester.pumpAndSettle();

    expect(find.text('Inside House'), findsWidgets);
    expect(find.text('Choose your habitat'), findsOneWidget);
  });

  testWidgets('equipped cosmetic renders on Study Pet hero', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await _seedEngagement(firestore, xp: 500);
    await _seedHatchling(firestore, growthStage: StudyPetGrowthStage.young);
    await firestore.doc('student_progress/$uid/pet_economy/state').set({
      'schemaVersion': 1,
      'pawCoins': 30,
      'lifetimePawCoinsEarned': 120,
      'totalPawCoinsSpent': 90,
      'creditedCoinActivities': <String, bool>{},
      'ownedCosmeticIds': ['wizard_hat'],
      'equippedCosmetics': {'head': 'wizard_hat', 'face': null, 'neck': null},
      'lastPurchasedItemId': 'wizard_hat',
      'lastPurchasedAt': Timestamp.fromDate(DateTime.utc(2026, 8, 20)),
      'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 8, 20)),
    });

    await tester.pumpWidget(_app(firestore));
    await tester.pumpAndSettle();

    final overlay = tester.widget<PetCosmeticOverlay>(
      find.byType(PetCosmeticOverlay).first,
    );
    expect(overlay.equippedCosmetics['head'], 'wizard_hat');
  });

  testWidgets('hatchling displays next growth target and partial XP message',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    await _seedEngagement(firestore, xp: 530);
    await _seedHatchling(
      firestore,
      xpBaselineAtHatch: 390,
      hatchedAt: DateTime.utc(2026, 8, 17, 10),
    );

    await tester.pumpWidget(_app(
      firestore,
      nowProvider: () => DateTime.utc(2026, 8, 19, 10),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Growth'), findsOneWidget);
    expect(find.text('Young Sprout Bunny'), findsOneWidget);
    expect(find.text('140 / 200 XP'), findsOneWidget);
    expect(find.text('2 / 2 days ✓'), findsOneWidget);
    expect(find.textContaining('needs 60 more XP'), findsOneWidget);
    expect(find.text('Evolve Momo'), findsNothing);
  });

  testWidgets('XP-complete and time-incomplete growth copy is shown',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    await _seedEngagement(firestore, xp: 590);
    await _seedHatchling(
      firestore,
      xpBaselineAtHatch: 390,
      hatchedAt: DateTime.utc(2026, 8, 18, 10),
    );

    await tester.pumpWidget(_app(
      firestore,
      nowProvider: () => DateTime.utc(2026, 8, 19, 10),
    ));
    await tester.pumpAndSettle();

    expect(find.text('200 / 200 XP ✓'), findsOneWidget);
    expect(find.text('1 / 2 days'), findsOneWidget);
    expect(find.textContaining('Spend a little more time together'),
        findsOneWidget);
  });

  testWidgets('Ready to Grow evolves pet and shows celebration',
      (tester) async {
    _setLargeSurface(tester);
    final firestore = FakeFirebaseFirestore();
    await _seedEngagement(firestore, xp: 590);
    await _seedHatchling(
      firestore,
      xpBaselineAtHatch: 390,
      hatchedAt: DateTime.utc(2026, 8, 17, 10),
    );

    await tester.pumpWidget(_app(
      firestore,
      nowProvider: () => DateTime.utc(2026, 8, 19, 10),
      disableAnimations: true,
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('ready for the next stage'), findsOneWidget);
    await tester.ensureVisible(find.text('Evolve Momo'));
    await tester.tap(find.text('Evolve Momo'));
    await tester.pumpAndSettle();

    expect(find.text('MOMO EVOLVED!'), findsOneWidget);
    expect(find.text('Young Sprout Bunny'), findsOneWidget);
    expect(find.text('Your learning helped Momo grow!'), findsOneWidget);

    final data =
        (await firestore.doc('student_progress/$uid/pet/state').get()).data()!;
    expect(data['growthStage'], 'young');
    expect(data['xpBaselineAtHatch'], 390);
  });

  testWidgets('adult pet shows Final Form with no evolution button',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    await _seedEngagement(firestore, xp: 1290);
    await _seedHatchling(
      firestore,
      growthStage: StudyPetGrowthStage.adult,
      xpBaselineAtHatch: 390,
      hatchedAt: DateTime.utc(2026, 8, 9, 10),
    );

    await tester.pumpWidget(_app(
      firestore,
      nowProvider: () => DateTime.utc(2026, 8, 19, 10),
    ));
    await tester.pumpAndSettle();

    expect(find.text('FINAL FORM'), findsOneWidget);
    expect(find.text('Forest Guardian Bunny'), findsOneWidget);
    expect(find.text('Growth progress: Complete'), findsOneWidget);
    expect(find.text('Evolve Momo'), findsNothing);
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
  bool darkMode = false,
}) {
  return MaterialApp(
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
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
        petEconomyRepository: PetEconomyRepository(
          firestore: firestore,
          uidProvider: () => uid,
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

Future<void> _seedHatchling(
  FakeFirebaseFirestore firestore, {
  String eggId = 'egg_sprout',
  String petId = 'pet_bunny',
  String petName = 'Momo',
  String? habitatTheme,
  StudyPetGrowthStage growthStage = StudyPetGrowthStage.hatchling,
  DateTime? hatchedAt,
  int? xpBaselineAtHatch,
}) async {
  final hatchTime = hatchedAt ?? DateTime.utc(2026, 8, 18, 10);
  await firestore.doc('student_progress/$uid/pet/state').set({
    'schemaVersion': 1,
    'petUnlockAcknowledgedAt': Timestamp.fromDate(DateTime.utc(2026, 8, 17)),
    'eggId': eggId,
    'petId': petId,
    'stage': 'hatchling',
    'selectedAt': Timestamp.fromDate(DateTime.utc(2026, 8, 17, 10)),
    'xpBaselineAtSelection': 250,
    'hatchXpTarget': 100,
    'hatchDelayHours': 24,
    'hatchedAt': Timestamp.fromDate(hatchTime),
    'petName': petName,
    if (habitatTheme != null) 'habitatTheme': habitatTheme,
    if (xpBaselineAtHatch != null) ...{
      'growthStage': growthStage.storageId,
      'xpBaselineAtHatch': xpBaselineAtHatch,
      'lastEvolutionAt': null,
    },
    'updatedAt': Timestamp.fromDate(hatchTime),
  });
}
