import 'package:flutter/material.dart';

import '../models/engagement.dart';
import '../models/pet_cosmetic.dart';
import '../models/study_pet.dart';
import '../repositories/engagement_repository.dart';
import '../repositories/pet_economy_repository.dart';
import '../repositories/study_pet_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/study_pet_visuals.dart';
import 'pet_shop_screen.dart';
import 'study_pet_screen.dart';

class RewardsScreen extends StatelessWidget {
  const RewardsScreen({
    this.engagementRepository,
    this.petRepository,
    this.petEconomyRepository,
    this.nowProvider,
    super.key,
  });

  final EngagementRepository? engagementRepository;
  final StudyPetRepository? petRepository;
  final PetEconomyRepository? petEconomyRepository;
  final DateTime Function()? nowProvider;

  DateTime get _now => nowProvider?.call() ?? DateTime.now();

  @override
  Widget build(BuildContext context) {
    final engagementRepository =
        this.engagementRepository ?? EngagementRepository();
    final petRepository = this.petRepository ?? StudyPetRepository();
    final petEconomyRepository =
        this.petEconomyRepository ?? PetEconomyRepository();
    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<EngagementState>(
          stream: engagementRepository.watchState(),
          initialData: EngagementState.initial('today'),
          builder: (context, engagementSnapshot) {
            final engagement =
                engagementSnapshot.data ?? EngagementState.initial('today');
            return StreamBuilder<StudyPetState>(
              stream: petRepository.watchState(),
              initialData: StudyPetState.empty,
              builder: (context, petSnapshot) {
                final pet = petSnapshot.data ?? StudyPetState.empty;
                return StreamBuilder<PetEconomyState>(
                  stream: petEconomyRepository.watchState(),
                  initialData: PetEconomyState.empty,
                  builder: (context, economySnapshot) {
                    final economy =
                        economySnapshot.data ?? PetEconomyState.empty;
                    final petView = StudyPetViewState(
                      engagement: engagement,
                      pet: pet,
                      now: _now,
                    );
                    return ListView(
                      key: const PageStorageKey<String>('rewards-tab-scroll'),
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                      children: [
                        Text('Rewards',
                            style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 6),
                        Text(
                          'Your streak, XP, Paw Coins, and Study Buddy live here.',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 18),
                        _RewardMetricCard(
                          icon: Icons.local_fire_department_rounded,
                          accent: StudySisColors.streakAccent(context),
                          surface: StudySisColors.streakSurface(context),
                          label: 'Current Streak',
                          value: '${engagement.currentStreak} days',
                          subtitle: engagement.todayStreakSecured
                              ? "Today's streak is secured."
                              : 'Complete your daily goal to keep it going.',
                        ),
                        const SizedBox(height: 12),
                        _RewardProgressCard(
                          icon: Icons.flag_rounded,
                          accent: StudySisColors.progressAccent(context),
                          label: 'Today',
                          value:
                              '${engagement.clampedTodayStudyPoints} / ${engagement.dailyStudyTarget} Study Points',
                          progress: engagement.dailyStudyTarget <= 0
                              ? 1
                              : engagement.clampedTodayStudyPoints /
                                  engagement.dailyStudyTarget,
                        ),
                        const SizedBox(height: 12),
                        _RewardProgressCard(
                          icon: Icons.star_rounded,
                          accent: StudySisColors.xpAccent(context),
                          label: 'Level ${engagement.level}',
                          value:
                              '${engagement.totalXp} / ${engagement.xpForNextLevel} XP',
                          progress: engagement.levelProgress,
                        ),
                        const SizedBox(height: 12),
                        _PawCoinsRewardCard(
                          balance: economy.pawCoins,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              settings: const RouteSettings(
                                name: PetShopScreen.routeName,
                              ),
                              builder: (_) => PetShopScreen(
                                petRepository: petRepository,
                                petEconomyRepository: petEconomyRepository,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _PetShopRewardCard(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              settings: const RouteSettings(
                                name: PetShopScreen.routeName,
                              ),
                              builder: (_) => PetShopScreen(
                                petRepository: petRepository,
                                petEconomyRepository: petEconomyRepository,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _StudyBuddyRewardCard(
                          state: petView,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              settings: const RouteSettings(
                                name: StudyPetScreen.routeName,
                              ),
                              builder: (_) => StudyPetScreen(
                                engagementRepository: engagementRepository,
                                petRepository: petRepository,
                                petEconomyRepository: petEconomyRepository,
                                nowProvider: nowProvider,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _RewardMetricCard extends StatelessWidget {
  const _RewardMetricCard({
    required this.icon,
    required this.accent,
    required this.surface,
    required this.label,
    required this.value,
    required this.subtitle,
  });

  final IconData icon;
  final Color accent;
  final Color surface;
  final String label;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: StudySisDecorations.softAccentSurface(
          context,
          accent: accent,
          surface: surface,
          radius: 24,
        ),
        child: Row(
          children: [
            Icon(icon, color: accent, size: 30),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label.toUpperCase(),
                      style: Theme.of(context).textTheme.bodySmall),
                  Text(value,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w900,
                          )),
                  const SizedBox(height: 3),
                  Text(subtitle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardProgressCard extends StatelessWidget {
  const _RewardProgressCard({
    required this.icon,
    required this.accent,
    required this.label,
    required this.value,
    required this.progress,
  });

  final IconData icon;
  final Color accent;
  final String label;
  final String value;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(label,
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
                Text(value,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progress.clamp(0, 1),
                minHeight: 8,
                color: accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PawCoinsRewardCard extends StatelessWidget {
  const _PawCoinsRewardCard({
    required this.balance,
    required this.onTap,
  });

  final int balance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        key: const ValueKey('rewards-paw-coins-card'),
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFFFD76A),
                ),
                child: const Icon(
                  Icons.pets_rounded,
                  color: Color(0xFF8B6419),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PAW COINS',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      '$balance',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: const Color(0xFFD49A32),
                                fontWeight: FontWeight.w900,
                              ),
                    ),
                    const Text('Earn by studying. Spend on pet cosmetics.'),
                  ],
                ),
              ),
              Text('Shop',
                  style: TextStyle(
                    color: StudySisColors.studyPetAccent(context),
                    fontWeight: FontWeight.w900,
                  )),
              Icon(Icons.chevron_right_rounded,
                  color: StudySisColors.studyPetAccent(context)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PetShopRewardCard extends StatelessWidget {
  const _PetShopRewardCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        key: const ValueKey('rewards-pet-shop-card'),
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(Icons.storefront_rounded,
                  color: StudySisColors.studyPetAccent(context), size: 30),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PET SHOP',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w900)),
                    SizedBox(height: 4),
                    Text('Dress up your Study Buddy with learning rewards.'),
                  ],
                ),
              ),
              SizedBox(
                width: 112,
                child: FilledButton.tonal(
                  onPressed: onTap,
                  child: const Text('Visit Shop'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudyBuddyRewardCard extends StatelessWidget {
  const _StudyBuddyRewardCard({
    required this.state,
    required this.onTap,
  });

  final StudyPetViewState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final details = _details();
    final accent = StudySisColors.studyPetAccent(context);
    return Card(
      child: InkWell(
        key: const ValueKey('rewards-study-buddy-card'),
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              SizedBox(width: 54, child: Center(child: details.visual)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'STUDY BUDDY',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(details.title,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 3),
                    Text(details.subtitle),
                  ],
                ),
              ),
              Text(details.action,
                  style: TextStyle(color: accent, fontWeight: FontWeight.w900)),
              Icon(Icons.chevron_right_rounded, color: accent),
            ],
          ),
        ),
      ),
    );
  }

  _StudyBuddyDetails _details() {
    final pet = state.pet.pet;
    final egg = state.pet.egg;
    if (!state.isUnlocked) {
      return _StudyBuddyDetails(
        visual: const Icon(Icons.lock_rounded, size: 32),
        title: 'Study Pets',
        subtitle: 'Unlock at Level 3 - ${state.xpToUnlock} XP to go',
        action: 'View',
      );
    }
    if (state.pet.stage == StudyPetStage.hatchling && pet != null) {
      final requirement = state.nextGrowthRequirement;
      return _StudyBuddyDetails(
        visual: StudyPetAvatar(
          pet: pet,
          growthStage: state.pet.growthStage,
          size: 48,
        ),
        title: state.pet.petName ?? pet.displayName,
        subtitle: state.isFinalGrowthStage
            ? '${pet.stageName(state.pet.growthStage)}. Final Form.'
            : state.readyToEvolve
                ? 'Ready to evolve!'
                : requirement == null
                    ? 'Growing with you.'
                    : '${pet.stageName(state.pet.growthStage)}. ${state.cappedGrowthXp} / ${requirement.requiredXp} growth XP.',
        action: 'Visit',
      );
    }
    if (state.pet.stage == StudyPetStage.egg && egg != null) {
      return _StudyBuddyDetails(
        visual: StudyEggAvatar(egg: egg, size: 48),
        title: egg.displayName,
        subtitle: state.readyToHatch
            ? 'Ready to hatch!'
            : '${state.cappedHatchXp} / ${state.pet.hatchXpTarget} XP - Growing',
        action: 'Visit',
      );
    }
    return const _StudyBuddyDetails(
      visual: Icon(Icons.egg_alt_rounded, size: 32),
      title: 'Study Pets Unlocked!',
      subtitle: 'Ready! Choose your mystery egg.',
      action: 'Choose',
    );
  }
}

class _StudyBuddyDetails {
  const _StudyBuddyDetails({
    required this.visual,
    required this.title,
    required this.subtitle,
    required this.action,
  });

  final Widget visual;
  final String title;
  final String subtitle;
  final String action;
}
