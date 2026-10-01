import 'package:flutter/material.dart';

import '../models/pet_cosmetic.dart';
import '../models/study_pet.dart';
import '../repositories/pet_economy_repository.dart';
import '../repositories/study_pet_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/pet_cosmetic_overlay.dart';
import '../widgets/study_pet_visuals.dart';

class PetShopScreen extends StatefulWidget {
  const PetShopScreen({
    this.petRepository,
    this.petEconomyRepository,
    super.key,
  });

  static const routeName = 'pet_shop';

  final StudyPetRepository? petRepository;
  final PetEconomyRepository? petEconomyRepository;

  @override
  State<PetShopScreen> createState() => _PetShopScreenState();
}

class _PetShopScreenState extends State<PetShopScreen> {
  late final StudyPetRepository _petRepository;
  late final PetEconomyRepository _economyRepository;
  PetCosmeticDefinition? _preview;
  bool _ownedOnly = false;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _petRepository = widget.petRepository ?? StudyPetRepository();
    _economyRepository = widget.petEconomyRepository ?? PetEconomyRepository();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pet Shop')),
      body: StreamBuilder<StudyPetState>(
        stream: _petRepository.watchState(),
        initialData: StudyPetState.empty,
        builder: (context, petSnapshot) {
          final petState = petSnapshot.data ?? StudyPetState.empty;
          return StreamBuilder<PetEconomyState>(
            stream: _economyRepository.watchState(),
            initialData: PetEconomyState.empty,
            builder: (context, economySnapshot) {
              final economy = economySnapshot.data ?? PetEconomyState.empty;
              final previewEquipped = {
                ...economy.equippedCosmeticIds,
                if (_preview != null) _preview!.slot.storageId: _preview!.id,
              };
              final items = _ownedOnly
                  ? petCosmeticsCatalog
                      .where((item) => economy.owns(item.id))
                      .toList()
                  : petCosmeticsCatalog;
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  _WalletCard(balance: economy.pawCoins),
                  const SizedBox(height: 14),
                  _ShopPreview(
                    petState: petState,
                    equippedCosmetics: previewEquipped,
                    previewName: _preview?.displayName,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Reward your learning by customizing your Study Buddy.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 14),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('All')),
                      ButtonSegment(value: true, label: Text('Owned')),
                    ],
                    selected: {_ownedOnly},
                    onSelectionChanged: (value) {
                      setState(() => _ownedOnly = value.first);
                    },
                  ),
                  const SizedBox(height: 14),
                  if (economy.pawCoins == 0)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Complete learning activities to earn Paw Coins!',
                      ),
                    ),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth < 320
                          ? 1
                          : constraints.maxWidth >= 620
                              ? 3
                              : 2;
                      final textScale =
                          MediaQuery.textScalerOf(context).scale(1);
                      final cardExtent = textScale > 1.15 ? 244.0 : 224.0;
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: items.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          mainAxisExtent: cardExtent,
                        ),
                        itemBuilder: (context, index) {
                          final cosmetic = items[index];
                          return _ShopItemCard(
                            cosmetic: cosmetic,
                            economy: economy,
                            selected: _preview?.id == cosmetic.id,
                            onTap: () => setState(() => _preview = cosmetic),
                            onBuy: _isBusy
                                ? null
                                : () => _confirmPurchase(cosmetic, economy),
                            onEquip: _isBusy
                                ? null
                                : () async {
                                    setState(() => _isBusy = true);
                                    try {
                                      await _economyRepository
                                          .equip(cosmetic.id);
                                    } finally {
                                      if (mounted) {
                                        setState(() => _isBusy = false);
                                      }
                                    }
                                  },
                            onUnequip: _isBusy
                                ? null
                                : () async {
                                    setState(() => _isBusy = true);
                                    try {
                                      await _economyRepository
                                          .unequip(cosmetic.slot);
                                    } finally {
                                      if (mounted) {
                                        setState(() => _isBusy = false);
                                      }
                                    }
                                  },
                          );
                        },
                      );
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmPurchase(
    PetCosmeticDefinition cosmetic,
    PetEconomyState economy,
  ) async {
    setState(() => _preview = cosmetic);
    final canAfford = economy.pawCoins >= cosmetic.price;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(cosmetic.displayName,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(cosmetic.description),
              const SizedBox(height: 14),
              Text('${cosmetic.price} Paw Coins',
                  style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text('Your balance: ${economy.pawCoins}'),
              Text('After purchase: ${economy.pawCoins - cosmetic.price}'),
              if (!canAfford) ...[
                const SizedBox(height: 10),
                Text(
                  'You need ${cosmetic.price - economy.pawCoins} more Paw Coins.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: canAfford
                          ? () => Navigator.of(context).pop(true)
                          : null,
                      child: Text('Buy for ${cosmetic.price}'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
    if (confirmed != true) return;
    setState(() => _isBusy = true);
    try {
      await _economyRepository.purchase(cosmetic.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('New cosmetic! ${cosmetic.displayName} was equipped.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }
}

class _WalletCard extends StatelessWidget {
  const _WalletCard({required this.balance});

  final int balance;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const _PawCoinIcon(size: 44),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PAW COINS',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                  ),
                  Text(
                    '$balance',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: const Color(0xFFD49A32),
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const Text('Earn by studying. Spend on cosmetics.'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShopPreview extends StatelessWidget {
  const _ShopPreview({
    required this.petState,
    required this.equippedCosmetics,
    required this.previewName,
  });

  final StudyPetState petState;
  final Map<String, String?> equippedCosmetics;
  final String? previewName;

  @override
  Widget build(BuildContext context) {
    final pet = petState.pet ?? studyPets.first;
    final growthStage = petState.stage == StudyPetStage.hatchling
        ? petState.growthStage
        : StudyPetGrowthStage.hatchling;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            PetCosmeticOverlay(
              pet: pet,
              growthStage: growthStage,
              equippedCosmetics: equippedCosmetics,
              previewContext: PetCosmeticPreviewContext.shopPreview,
              size: 96,
              child: StudyPetCompanionVisual(
                pet: pet,
                growthStage: growthStage,
                size: 96,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    petState.petName ?? pet.displayName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(previewName == null
                      ? 'Tap an item to try it on.'
                      : 'Trying on $previewName'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShopItemCard extends StatelessWidget {
  const _ShopItemCard({
    required this.cosmetic,
    required this.economy,
    required this.selected,
    required this.onTap,
    required this.onBuy,
    required this.onEquip,
    required this.onUnequip,
  });

  final PetCosmeticDefinition cosmetic;
  final PetEconomyState economy;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onBuy;
  final VoidCallback? onEquip;
  final VoidCallback? onUnequip;

  @override
  Widget build(BuildContext context) {
    final owned = economy.owns(cosmetic.id);
    final equipped = economy.isEquipped(cosmetic);
    final canAfford = economy.pawCoins >= cosmetic.price;
    final accent = selected
        ? StudySisColors.studyPetAccent(context)
        : Theme.of(context).colorScheme.outlineVariant;
    return Semantics(
      button: true,
      label:
          '${cosmetic.displayName}, ${cosmetic.slot.displayName}, ${cosmetic.price} Paw Coins',
      child: Card(
        child: InkWell(
          key: ValueKey('pet-shop-item-${cosmetic.id}'),
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: accent, width: selected ? 2 : 1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 26,
                    backgroundColor:
                        const Color(0xFFFFF0CF).withValues(alpha: 0.80),
                    child: Icon(cosmetic.icon, color: const Color(0xFFD49A32)),
                  ),
                ),
                const SizedBox(height: 8),
                Text(cosmetic.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(
                  cosmetic.slot.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${cosmetic.price} Paw Coins',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: _ShopItemActionButton(
                    cosmetic: cosmetic,
                    owned: owned,
                    equipped: equipped,
                    canAfford: canAfford,
                    onBuy: onBuy,
                    onEquip: onEquip,
                    onUnequip: onUnequip,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShopItemActionButton extends StatelessWidget {
  const _ShopItemActionButton({
    required this.cosmetic,
    required this.owned,
    required this.equipped,
    required this.canAfford,
    required this.onBuy,
    required this.onEquip,
    required this.onUnequip,
  });

  final PetCosmeticDefinition cosmetic;
  final bool owned;
  final bool equipped;
  final bool canAfford;
  final VoidCallback? onBuy;
  final VoidCallback? onEquip;
  final VoidCallback? onUnequip;

  @override
  Widget build(BuildContext context) {
    final style = const ButtonStyle(
      visualDensity: VisualDensity.compact,
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 10),
      ),
    );
    if (equipped) {
      return FilledButton.tonal(
        key: ValueKey('pet-shop-equipped-${cosmetic.id}'),
        style: style,
        onPressed: onUnequip,
        child: const Text(
          'Equipped',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }
    if (owned) {
      return OutlinedButton(
        key: ValueKey('pet-shop-equip-${cosmetic.id}'),
        style: style,
        onPressed: onEquip,
        child: const Text(
          'Equip',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }
    return FilledButton(
      key: ValueKey('pet-shop-buy-${cosmetic.id}'),
      style: style,
      onPressed: canAfford ? onBuy : null,
      child: Text(
        canAfford ? 'Buy' : 'Need more',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _PawCoinIcon extends StatelessWidget {
  const _PawCoinIcon({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFFFD76A),
      ),
      child: Icon(Icons.pets_rounded,
          color: const Color(0xFF8B6419), size: size * 0.56),
    );
  }
}
