import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/pet_cosmetic.dart';

class PetEconomyRepository {
  PetEconomyRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    String Function()? uidProvider,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth,
        _uidProvider = uidProvider;

  final FirebaseFirestore _firestore;
  final FirebaseAuth? _auth;
  final String Function()? _uidProvider;

  Stream<PetEconomyState> watchState() {
    final uid = _maybeUid;
    if (uid == null) return Stream.value(PetEconomyState.empty);
    return _stateRef(uid).snapshots().map(
          (snapshot) => PetEconomyState.fromMap(snapshot.data()),
        );
  }

  Future<PetEconomyState> readState() async {
    final uid = _maybeUid;
    if (uid == null) return PetEconomyState.empty;
    return PetEconomyState.fromMap((await _stateRef(uid).get()).data());
  }

  Future<PetEconomyState> purchase(String cosmeticId) async {
    final cosmetic = petCosmeticById(cosmeticId);
    if (cosmetic == null) {
      throw ArgumentError.value(cosmeticId, 'cosmeticId', 'Unknown cosmetic');
    }
    final uid = _uid;
    final ref = _stateRef(uid);
    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      final current = PetEconomyState.fromMap(snapshot.data());
      if (current.owns(cosmetic.id)) return current;
      if (current.pawCoins < cosmetic.price) {
        throw StateError('Not enough Paw Coins.');
      }
      final owned = {...current.ownedCosmeticIds, cosmetic.id}.toList()..sort();
      final equipped = {
        ...current.equippedCosmeticIds,
        cosmetic.slot.storageId: cosmetic.id,
      };
      final payload = {
        ..._fullPayload(current),
        'pawCoins': current.pawCoins - cosmetic.price,
        'totalPawCoinsSpent': current.totalPawCoinsSpent + cosmetic.price,
        'ownedCosmeticIds': owned,
        'equippedCosmetics': equipped,
        'lastPurchasedItemId': cosmetic.id,
        'lastPurchasedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      transaction.set(ref, payload);
      return PetEconomyState.fromMap({
        ...payload,
        'lastPurchasedAt': DateTime.now(),
      });
    });
  }

  Future<void> equip(String cosmeticId) async {
    final cosmetic = petCosmeticById(cosmeticId);
    if (cosmetic == null) {
      throw ArgumentError.value(cosmeticId, 'cosmeticId', 'Unknown cosmetic');
    }
    final uid = _uid;
    final ref = _stateRef(uid);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      final current = PetEconomyState.fromMap(snapshot.data());
      if (!current.owns(cosmetic.id)) {
        throw StateError('This cosmetic is not owned yet.');
      }
      transaction.set(
        ref,
        {
          ..._fullPayload(current),
          'equippedCosmetics': {
            ...current.equippedCosmeticIds,
            cosmetic.slot.storageId: cosmetic.id,
          },
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    });
  }

  Future<void> unequip(PetCosmeticSlot slot) async {
    final uid = _uid;
    final ref = _stateRef(uid);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      final current = PetEconomyState.fromMap(snapshot.data());
      transaction.set(
        ref,
        {
          ..._fullPayload(current),
          'equippedCosmetics': {
            ...current.equippedCosmeticIds,
            slot.storageId: null,
          },
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    });
  }

  DocumentReference<Map<String, dynamic>> _stateRef(String uid) {
    return _firestore.doc('student_progress/$uid/pet_economy/state');
  }

  String get _uid {
    final uid = _maybeUid;
    if (uid != null) return uid;
    throw StateError('Student authentication is required for pet economy.');
  }

  String? get _maybeUid {
    final provided = _uidProvider?.call();
    if (provided != null && provided.trim().isNotEmpty) return provided.trim();
    final user = (_auth ?? FirebaseAuth.instance).currentUser;
    return user?.uid;
  }
}

Map<String, Object?> _fullPayload(PetEconomyState state) {
  final owned = state.ownedCosmeticIds.toList()..sort();
  return {
    'schemaVersion': 1,
    'pawCoins': state.pawCoins,
    'lifetimePawCoinsEarned': state.lifetimePawCoinsEarned,
    'totalPawCoinsSpent': state.totalPawCoinsSpent,
    'creditedCoinActivities': state.creditedCoinActivities,
    'ownedCosmeticIds': owned,
    'equippedCosmetics': state.equippedCosmeticIds,
    'lastPurchasedItemId': state.lastPurchasedItemId,
    'lastPurchasedAt': state.lastPurchasedAt == null
        ? null
        : Timestamp.fromDate(state.lastPurchasedAt!),
    'updatedAt': FieldValue.serverTimestamp(),
  };
}
