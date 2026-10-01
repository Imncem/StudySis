import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studysis/models/muffin_wallet.dart';
import 'package:studysis/services/muffin_wallet_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final base = DateTime.utc(2026, 8, 11, 18, 20);

  MuffinWallet wallet({
    required int currentBites,
    required Duration elapsed,
  }) {
    return MuffinWallet(
      maxBites: 5,
      currentBites: currentBites,
      regenIntervalMinutes: 60,
      lastRegenAt: base,
      dailyUsedRequests: 0,
      dailySoftLimit: 17,
      dailyHardLimit: 20,
      status: currentBites == 0 ? 'recharging' : 'active',
    ).effectiveAt(base.add(elapsed));
  }

  test('effective wallet uses elapsed time without early regeneration', () {
    expect(
      wallet(currentBites: 0, elapsed: const Duration(minutes: 59))
          .currentBites,
      0,
    );
    expect(
      wallet(currentBites: 0, elapsed: const Duration(minutes: 60))
          .currentBites,
      1,
    );
    expect(
      wallet(currentBites: 0, elapsed: const Duration(hours: 3)).currentBites,
      3,
    );
    expect(
      wallet(currentBites: 2, elapsed: const Duration(hours: 2)).currentBites,
      4,
    );
  });

  test('effective wallet caps at max and does not bank excess recharge', () {
    final fromFour = wallet(currentBites: 4, elapsed: const Duration(hours: 3));
    final fromZero =
        wallet(currentBites: 0, elapsed: const Duration(hours: 10));

    expect(fromFour.currentBites, 5);
    expect(fromZero.currentBites, 5);
    expect(fromZero.lastRegenAt, base.add(const Duration(hours: 10)));

    final afterSpend = fromZero
        .copyWith(
          currentBites: 4,
          lastRegenAt: fromZero.lastRegenAt,
        )
        .effectiveAt(base.add(const Duration(hours: 10, minutes: 1)));
    expect(afterSpend.currentBites, 4);
  });

  test('effective wallet preserves partial elapsed recharge anchor', () {
    final effective =
        wallet(currentBites: 0, elapsed: const Duration(minutes: 215));

    expect(effective.currentBites, 3);
    expect(effective.lastRegenAt, base.add(const Duration(hours: 3)));
    expect(
      effective.cooldownRemaining(base.add(const Duration(minutes: 215))),
      const Duration(minutes: 25),
    );
  });

  test('Firestore wallet stream emits regenerated value after app reopen',
      () async {
    final firestore = FakeFirebaseFirestore();
    final now = base.add(const Duration(hours: 3));
    await firestore.doc('students/qidah/muffin/state').set({
      'maxBites': 5,
      'currentBites': 0,
      'regenIntervalMinutes': 60,
      'lastRegenAt': Timestamp.fromDate(base),
      'dailyUsedRequests': 0,
      'dailySoftLimit': 17,
      'dailyHardLimit': 20,
      'status': 'recharging',
    });
    final service = FirestoreMuffinWalletService(
      firestore: firestore,
      nowProvider: () => now,
    );

    final emitted = await service.watchWallet().first;

    expect(emitted.currentBites, 3);
    expect(emitted.status, 'active');
  });
}
