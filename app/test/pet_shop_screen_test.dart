import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studysis/repositories/pet_economy_repository.dart';
import 'package:studysis/repositories/study_pet_repository.dart';
import 'package:studysis/screens/pet_shop_screen.dart';
import 'package:studysis/theme/app_theme.dart';
import 'package:studysis/widgets/pet_cosmetic_overlay.dart';

const uid = 'anonymousUid123';

void main() {
  testWidgets('shop shows balance and all six cosmetics', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await _seedPet(firestore);
    await _seedEconomy(firestore, pawCoins: 120);

    await tester.pumpWidget(_app(firestore));
    await tester.pumpAndSettle();

    expect(find.text('120'), findsOneWidget);
    expect(find.text('Leaf Bow'), findsOneWidget);
    expect(find.text('Round Glasses'), findsOneWidget);
    expect(find.text('Star Scarf'), findsOneWidget);
    expect(find.text('Study Headphones'), findsOneWidget);
    expect(find.text('Wizard Hat'), findsOneWidget);
    expect(find.text('Graduation Cap'), findsOneWidget);
  });

  testWidgets('preview does not write before purchase', (tester) async {
    _setLargeSurface(tester);
    final firestore = FakeFirebaseFirestore();
    await _seedPet(firestore);
    await _seedEconomy(firestore, pawCoins: 120);

    await tester.pumpWidget(_app(firestore));
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.byKey(const ValueKey('pet-shop-item-wizard_hat')));
    await tester.tap(find.byKey(const ValueKey('pet-shop-item-wizard_hat')));
    await tester.pumpAndSettle();

    expect(find.text('Trying on Wizard Hat'), findsOneWidget);
    final data =
        (await firestore.doc('student_progress/$uid/pet_economy/state').get())
            .data()!;
    expect(data['ownedCosmeticIds'], isEmpty);
    expect((data['equippedCosmetics'] as Map)['head'], isNull);
  });

  testWidgets('successful purchase auto-equips and overlay renders',
      (tester) async {
    _setLargeSurface(tester);
    final firestore = FakeFirebaseFirestore();
    await _seedPet(firestore);
    await _seedEconomy(firestore, pawCoins: 120);

    await tester.pumpWidget(_app(firestore));
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.byKey(const ValueKey('pet-shop-item-wizard_hat')));
    await tester.tap(find.byKey(const ValueKey('pet-shop-item-wizard_hat')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pet-shop-buy-wizard_hat')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buy for 90'));
    await tester.pumpAndSettle();

    final data =
        (await firestore.doc('student_progress/$uid/pet_economy/state').get())
            .data()!;
    expect(data['pawCoins'], 30);
    expect(data['ownedCosmeticIds'], contains('wizard_hat'));
    expect((data['equippedCosmetics'] as Map)['head'], 'wizard_hat');
    expect(find.byType(PetCosmeticOverlay), findsOneWidget);
  });

  testWidgets('insufficient balance prevents purchase', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await _seedPet(firestore);
    await _seedEconomy(firestore, pawCoins: 20);

    await tester.pumpWidget(_app(firestore));
    await tester.pumpAndSettle();

    expect(find.text('Need more'), findsWidgets);
    expect(find.text('Complete learning activities to earn Paw Coins!'),
        findsNothing);
  });

  testWidgets('cosmetic cards do not overflow at narrow mobile widths',
      (tester) async {
    for (final width in <double>[360, 375, 390, 412]) {
      _setSurface(tester, width: width, height: 900);
      final firestore = FakeFirebaseFirestore();
      await _seedPet(firestore);
      await _seedEconomy(
        firestore,
        pawCoins: 35,
        ownedCosmeticIds: ['round_glasses', 'graduation_cap'],
        equippedCosmetics: {
          'head': 'graduation_cap',
          'face': null,
          'neck': null,
        },
      );

      await tester.pumpWidget(_app(firestore));
      await tester.pumpAndSettle();

      expect(find.text('Leaf Bow'), findsOneWidget);
      expect(find.text('Round Glasses'), findsOneWidget);
      expect(find.text('Study Headphones'), findsOneWidget);
      expect(find.text('Graduation Cap'), findsOneWidget);
      expect(
          find.byKey(const ValueKey('pet-shop-buy-leaf_bow')), findsOneWidget);
      expect(find.byKey(const ValueKey('pet-shop-buy-study_headphones')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('pet-shop-equip-round_glasses')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('pet-shop-equipped-graduation_cap')),
          findsOneWidget);
      expect(find.text('Buy'), findsWidgets);
      expect(find.text('Need more'), findsWidgets);
      expect(find.text('Equip'), findsWidgets);
      expect(find.text('Equipped'), findsWidgets);
      expect(tester.takeException(), isNull);
    }
  });
}

void _setLargeSurface(WidgetTester tester) {
  _setSurface(tester, width: 1000, height: 1200);
}

void _setSurface(
  WidgetTester tester, {
  required double width,
  required double height,
}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _app(FakeFirebaseFirestore firestore) {
  return MaterialApp(
    theme: AppTheme.light,
    home: PetShopScreen(
      petRepository: StudyPetRepository(
        firestore: firestore,
        uidProvider: () => uid,
      ),
      petEconomyRepository: PetEconomyRepository(
        firestore: firestore,
        uidProvider: () => uid,
      ),
    ),
  );
}

Future<void> _seedPet(FakeFirebaseFirestore firestore) {
  return firestore.doc('student_progress/$uid/pet/state').set({
    'schemaVersion': 1,
    'petUnlockAcknowledgedAt': DateTime.utc(2026, 8, 17),
    'eggId': 'egg_sprout',
    'petId': 'pet_bunny',
    'petName': 'Momo',
    'stage': 'hatchling',
    'growthStage': 'young',
    'habitatTheme': 'forest',
    'selectedAt': DateTime.utc(2026, 8, 17),
    'xpBaselineAtSelection': 250,
    'hatchXpTarget': 100,
    'hatchDelayHours': 24,
    'hatchedAt': DateTime.utc(2026, 8, 18),
    'xpBaselineAtHatch': 350,
    'lastEvolutionAt': null,
    'updatedAt': DateTime.utc(2026, 8, 18),
  });
}

Future<void> _seedEconomy(
  FakeFirebaseFirestore firestore, {
  required int pawCoins,
  List<String> ownedCosmeticIds = const [],
  Map<String, String?> equippedCosmetics = const {
    'head': null,
    'face': null,
    'neck': null,
  },
}) {
  return firestore.doc('student_progress/$uid/pet_economy/state').set({
    'schemaVersion': 1,
    'pawCoins': pawCoins,
    'lifetimePawCoinsEarned': pawCoins,
    'totalPawCoinsSpent': 0,
    'creditedCoinActivities': <String, bool>{},
    'ownedCosmeticIds': ownedCosmeticIds,
    'equippedCosmetics': equippedCosmetics,
    'lastPurchasedItemId': null,
    'lastPurchasedAt': null,
    'updatedAt': DateTime.utc(2026, 8, 18),
  });
}
