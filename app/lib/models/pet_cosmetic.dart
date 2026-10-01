import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum PetCosmeticSlot {
  head,
  face,
  neck;

  String get storageId => name;

  String get displayName {
    return switch (this) {
      PetCosmeticSlot.head => 'Head',
      PetCosmeticSlot.face => 'Face',
      PetCosmeticSlot.neck => 'Neck',
    };
  }

  static PetCosmeticSlot? fromStorageId(String? value) {
    return switch (value) {
      'head' => PetCosmeticSlot.head,
      'face' => PetCosmeticSlot.face,
      'neck' => PetCosmeticSlot.neck,
      _ => null,
    };
  }
}

class PetCosmeticDefinition {
  const PetCosmeticDefinition({
    required this.id,
    required this.displayName,
    required this.description,
    required this.slot,
    required this.price,
    required this.icon,
  });

  final String id;
  final String displayName;
  final String description;
  final PetCosmeticSlot slot;
  final int price;
  final IconData icon;
}

const petCosmeticsCatalog = [
  PetCosmeticDefinition(
    id: 'leaf_bow',
    displayName: 'Leaf Bow',
    description: 'A soft botanical bow for gentle study days.',
    slot: PetCosmeticSlot.head,
    price: 30,
    icon: Icons.eco_rounded,
  ),
  PetCosmeticDefinition(
    id: 'round_glasses',
    displayName: 'Round Glasses',
    description: 'Tiny round glasses for focused reading.',
    slot: PetCosmeticSlot.face,
    price: 40,
    icon: Icons.remove_red_eye_rounded,
  ),
  PetCosmeticDefinition(
    id: 'star_scarf',
    displayName: 'Star Scarf',
    description: 'A cozy scarf with a little starlight.',
    slot: PetCosmeticSlot.neck,
    price: 50,
    icon: Icons.stars_rounded,
  ),
  PetCosmeticDefinition(
    id: 'study_headphones',
    displayName: 'Study Headphones',
    description: 'Comfy headphones for deep focus.',
    slot: PetCosmeticSlot.head,
    price: 70,
    icon: Icons.headphones_rounded,
  ),
  PetCosmeticDefinition(
    id: 'wizard_hat',
    displayName: 'Wizard Hat',
    description: 'A little magic for tricky questions.',
    slot: PetCosmeticSlot.head,
    price: 90,
    icon: Icons.auto_awesome_rounded,
  ),
  PetCosmeticDefinition(
    id: 'graduation_cap',
    displayName: 'Graduation Cap',
    description: 'Celebrate your study journey in style.',
    slot: PetCosmeticSlot.head,
    price: 120,
    icon: Icons.school_rounded,
  ),
];

PetCosmeticDefinition? petCosmeticById(String? id) {
  if (id == null) return null;
  for (final cosmetic in petCosmeticsCatalog) {
    if (cosmetic.id == id) return cosmetic;
  }
  return null;
}

class PetEconomyState {
  const PetEconomyState({
    required this.schemaVersion,
    required this.pawCoins,
    required this.lifetimePawCoinsEarned,
    required this.totalPawCoinsSpent,
    required this.creditedCoinActivities,
    required this.ownedCosmeticIds,
    required this.equippedCosmetics,
    required this.lastPurchasedItemId,
    required this.lastPurchasedAt,
  });

  final int schemaVersion;
  final int pawCoins;
  final int lifetimePawCoinsEarned;
  final int totalPawCoinsSpent;
  final Map<String, bool> creditedCoinActivities;
  final Set<String> ownedCosmeticIds;
  final Map<PetCosmeticSlot, String?> equippedCosmetics;
  final String? lastPurchasedItemId;
  final DateTime? lastPurchasedAt;

  static const empty = PetEconomyState(
    schemaVersion: 1,
    pawCoins: 0,
    lifetimePawCoinsEarned: 0,
    totalPawCoinsSpent: 0,
    creditedCoinActivities: {},
    ownedCosmeticIds: {},
    equippedCosmetics: {
      PetCosmeticSlot.head: null,
      PetCosmeticSlot.face: null,
      PetCosmeticSlot.neck: null,
    },
    lastPurchasedItemId: null,
    lastPurchasedAt: null,
  );

  factory PetEconomyState.fromMap(Map<String, dynamic>? data) {
    if (data == null) return PetEconomyState.empty;
    final equippedRaw = data['equippedCosmetics'];
    final equipped = <PetCosmeticSlot, String?>{
      PetCosmeticSlot.head: null,
      PetCosmeticSlot.face: null,
      PetCosmeticSlot.neck: null,
    };
    if (equippedRaw is Map) {
      for (final slot in PetCosmeticSlot.values) {
        final value = equippedRaw[slot.storageId];
        equipped[slot] = value?.toString();
      }
    }
    return PetEconomyState(
      schemaVersion: _intValue(data['schemaVersion'], fallback: 1),
      pawCoins: _intValue(data['pawCoins']),
      lifetimePawCoinsEarned: _intValue(data['lifetimePawCoinsEarned']),
      totalPawCoinsSpent: _intValue(data['totalPawCoinsSpent']),
      creditedCoinActivities: _boolMap(data['creditedCoinActivities']),
      ownedCosmeticIds: _stringSet(data['ownedCosmeticIds']),
      equippedCosmetics: equipped,
      lastPurchasedItemId: data['lastPurchasedItemId']?.toString(),
      lastPurchasedAt: _dateValue(data['lastPurchasedAt']),
    );
  }

  Map<String, String?> get equippedCosmeticIds {
    return {
      for (final entry in equippedCosmetics.entries)
        entry.key.storageId: entry.value,
    };
  }

  bool owns(String cosmeticId) => ownedCosmeticIds.contains(cosmeticId);

  bool isEquipped(PetCosmeticDefinition cosmetic) {
    return equippedCosmetics[cosmetic.slot] == cosmetic.id;
  }
}

Map<String, Object?> defaultPetEconomyPayload() {
  return {
    'schemaVersion': 1,
    'pawCoins': 0,
    'lifetimePawCoinsEarned': 0,
    'totalPawCoinsSpent': 0,
    'creditedCoinActivities': <String, bool>{},
    'ownedCosmeticIds': <String>[],
    'equippedCosmetics': {
      'head': null,
      'face': null,
      'neck': null,
    },
    'lastPurchasedItemId': null,
    'lastPurchasedAt': null,
    'updatedAt': FieldValue.serverTimestamp(),
  };
}

int pawCoinRewardForActivityKey(String activityKey) {
  if (activityKey.startsWith('learn_')) return 10;
  if (activityKey.startsWith('flashcards_')) return 5;
  if (activityKey.startsWith('practice_')) return 10;
  if (activityKey.startsWith('quiz_')) return 20;
  if (activityKey.startsWith('saved_flashcards_review_')) return 5;
  return 0;
}

int _intValue(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return fallback;
}

Map<String, bool> _boolMap(Object? value) {
  if (value is! Map) return <String, bool>{};
  return value.map((key, value) => MapEntry(key.toString(), value == true));
}

Set<String> _stringSet(Object? value) {
  if (value is! Iterable) return <String>{};
  return value.map((item) => item.toString()).toSet();
}

DateTime? _dateValue(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}
