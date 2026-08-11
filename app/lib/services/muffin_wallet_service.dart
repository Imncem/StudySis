import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/muffin_wallet.dart';

abstract class MuffinWalletService {
  Stream<MuffinWallet> watchWallet();
}

class MuffinWalletServiceFactory {
  MuffinWalletServiceFactory._();

  static MuffinWalletService? _override;

  static void override(MuffinWalletService? service) {
    _override = service;
  }

  static MuffinWalletService create() {
    if (_override != null) return _override!;
    const useMock = bool.fromEnvironment(
      'MUFFIN_USE_MOCK',
      defaultValue: true,
    );
    if (useMock) return const StaticMuffinWalletService();
    return FirestoreMuffinWalletService();
  }
}

class FirestoreMuffinWalletService implements MuffinWalletService {
  FirestoreMuffinWalletService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _state =>
      _firestore.doc('students/qidah/muffin/state');

  @override
  Stream<MuffinWallet> watchWallet() {
    return _state.snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data == null) return MuffinWallet.full;
      return MuffinWallet.fromJson(data);
    });
  }
}

class StaticMuffinWalletService implements MuffinWalletService {
  const StaticMuffinWalletService([this.wallet = MuffinWallet.full]);

  final MuffinWallet wallet;

  @override
  Stream<MuffinWallet> watchWallet() => Stream.value(wallet);
}
