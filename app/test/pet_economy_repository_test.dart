import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studysis/models/pet_cosmetic.dart';
import 'package:studysis/repositories/engagement_repository.dart';
import 'package:studysis/repositories/pet_economy_repository.dart';

const uid = 'anonymousUid123';

void main() {
  test('missing economy document defaults to zero balance', () async {
    final repository = _repo(FakeFirebaseFirestore());

    final state = await repository.readState();

    expect(state.pawCoins, 0);
    expect(state.ownedCosmeticIds, isEmpty);
    expect(state.equippedCosmetics[PetCosmeticSlot.head], isNull);
  });

  test('learn credit earns Paw Coins once with anti-farming', () async {
    final firestore = FakeFirebaseFirestore();
    final engagement = _engagement(firestore);

    final first = await engagement.creditLearnCompletion(
      subjectId: 'math',
      chapterId: 'chapter-1',
    );
    final duplicate = await engagement.creditLearnCompletion(
      subjectId: 'math',
      chapterId: 'chapter-1',
    );
    final economy = await _repo(firestore).readState();

    expect(first.pawCoinsAwarded, 10);
    expect(duplicate.pawCoinsAwarded, 0);
    expect(economy.pawCoins, 10);
    expect(economy.lifetimePawCoinsEarned, 10);
    expect(
        economy.creditedCoinActivities, contains('learn_math_chapter-1_notes'));
  });

  test('configured activities earn configured Paw Coin amounts', () async {
    final firestore = FakeFirebaseFirestore();
    final engagement = _engagement(firestore);

    final flashcards = await engagement.creditFlashcardReview(
      subjectId: 'math',
      chapterId: 'chapter-1',
      reviewedCardIds: {'a', 'b', 'c', 'd', 'e'},
    );
    final practice = await engagement.creditPracticeQuestions(
      subjectId: 'math',
      chapterId: 'chapter-1',
      completedQuestionCount: 5,
      sessionId: 'session-1',
    );
    final quiz = await engagement.creditQuizCompletion(
      subjectId: 'math',
      chapterId: 'chapter-1',
    );
    final saved = await engagement.creditSavedFlashcardReview(
      reviewedSavedCardIds: {'a', 'b', 'c'},
    );
    final economy = await _repo(firestore).readState();

    expect(flashcards.pawCoinsAwarded, 5);
    expect(practice.pawCoinsAwarded, 10);
    expect(quiz.pawCoinsAwarded, 20);
    expect(saved.pawCoinsAwarded, 5);
    expect(economy.pawCoins, 40);
  });

  test('purchase deducts Paw Coins, owns item, and auto-equips', () async {
    final firestore = FakeFirebaseFirestore();
    await _seedEconomy(firestore, pawCoins: 120, earned: 120);
    final repository = _repo(firestore);

    await repository.purchase('wizard_hat');
    final state = await repository.readState();

    expect(state.pawCoins, 30);
    expect(state.totalPawCoinsSpent, 90);
    expect(state.ownedCosmeticIds, contains('wizard_hat'));
    expect(state.equippedCosmetics[PetCosmeticSlot.head], 'wizard_hat');
    expect(state.lastPurchasedItemId, 'wizard_hat');
  });

  test('insufficient balance does not purchase', () async {
    final firestore = FakeFirebaseFirestore();
    await _seedEconomy(firestore, pawCoins: 20, earned: 20);
    final repository = _repo(firestore);

    expect(() => repository.purchase('wizard_hat'), throwsStateError);
    final state = await repository.readState();
    expect(state.pawCoins, 20);
    expect(state.ownedCosmeticIds, isNot(contains('wizard_hat')));
  });

  test('duplicate purchase does not deduct again', () async {
    final firestore = FakeFirebaseFirestore();
    await _seedEconomy(
      firestore,
      pawCoins: 30,
      earned: 120,
      spent: 90,
      owned: ['wizard_hat'],
      equipped: {'head': 'wizard_hat', 'face': null, 'neck': null},
    );
    final repository = _repo(firestore);

    await repository.purchase('wizard_hat');
    final state = await repository.readState();

    expect(state.pawCoins, 30);
    expect(state.totalPawCoinsSpent, 90);
  });

  test('equip, unequip, and slot replacement are free', () async {
    final firestore = FakeFirebaseFirestore();
    await _seedEconomy(
      firestore,
      pawCoins: 50,
      earned: 170,
      spent: 120,
      owned: ['leaf_bow', 'graduation_cap', 'round_glasses'],
      equipped: {'head': 'leaf_bow', 'face': null, 'neck': null},
    );
    final repository = _repo(firestore);

    await repository.equip('graduation_cap');
    await repository.equip('round_glasses');
    var state = await repository.readState();
    expect(state.pawCoins, 50);
    expect(state.equippedCosmetics[PetCosmeticSlot.head], 'graduation_cap');
    expect(state.equippedCosmetics[PetCosmeticSlot.face], 'round_glasses');

    await repository.unequip(PetCosmeticSlot.head);
    state = await repository.readState();
    expect(state.equippedCosmetics[PetCosmeticSlot.head], isNull);
    expect(state.equippedCosmetics[PetCosmeticSlot.face], 'round_glasses');
  });
}

PetEconomyRepository _repo(FakeFirebaseFirestore firestore) {
  return PetEconomyRepository(
    firestore: firestore,
    uidProvider: () => uid,
  );
}

EngagementRepository _engagement(FakeFirebaseFirestore firestore) {
  return EngagementRepository(
    firestore: firestore,
    uidProvider: () => uid,
    nowProvider: () => DateTime.utc(2026, 8, 17, 2),
  );
}

Future<void> _seedEconomy(
  FakeFirebaseFirestore firestore, {
  required int pawCoins,
  required int earned,
  int spent = 0,
  List<String> owned = const [],
  Map<String, String?> equipped = const {
    'head': null,
    'face': null,
    'neck': null,
  },
}) {
  return firestore.doc('student_progress/$uid/pet_economy/state').set({
    'schemaVersion': 1,
    'pawCoins': pawCoins,
    'lifetimePawCoinsEarned': earned,
    'totalPawCoinsSpent': spent,
    'creditedCoinActivities': <String, bool>{},
    'ownedCosmeticIds': owned,
    'equippedCosmetics': equipped,
    'lastPurchasedItemId': null,
    'lastPurchasedAt': null,
    'updatedAt': DateTime.utc(2026, 8, 17),
  });
}
