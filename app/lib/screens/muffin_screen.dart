import 'package:flutter/material.dart';

import '../models/chapter_progress.dart';
import '../models/muffin.dart';
import '../models/muffin_wallet.dart';
import '../repositories/student_progress_repository.dart';
import '../services/muffin_service.dart';
import '../services/muffin_wallet_service.dart';
import '../theme/app_theme.dart';
import '../widgets/muffin_assist_sheet.dart';
import '../widgets/muffin_mascot_icon.dart';

class MuffinScreen extends StatefulWidget {
  const MuffinScreen({
    this.progressRepository,
    this.muffinService,
    this.walletService,
    super.key,
  });

  final StudentProgressRepository? progressRepository;
  final MuffinService? muffinService;
  final MuffinWalletService? walletService;

  @override
  State<MuffinScreen> createState() => _MuffinScreenState();
}

class _MuffinScreenState extends State<MuffinScreen> {
  late final StudentProgressRepository _progressRepository;
  late Future<List<ChapterProgress>> _progressFuture;

  @override
  void initState() {
    super.initState();
    _progressRepository =
        widget.progressRepository ?? StudentProgressRepository();
    _progressFuture = _progressRepository.getAllChapterProgress();
  }

  void _retry() {
    setState(() {
      _progressFuture = _progressRepository.getAllChapterProgress();
    });
  }

  void _openGeneralMuffin(MuffinAction action) {
    const context = MuffinContext(
      studentProfileId: 'qidah',
      preferredLanguage: 'Mixed',
      subjectId: 'general',
      subjectTitle: 'StudySis',
      mode: MuffinMode.learn,
      currentScreen: 'muffin_hub',
      originalScreenContent: 'General StudySis Muffin hub',
      contextKey: 'muffin_hub_general',
    );
    showModalBottomSheet<void>(
      context: this.context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => MuffinAssistSheet(
        title: 'Muffin',
        subtitle: 'Your AI learning companion.',
        mode: MuffinMode.learn,
        context: context,
        service: widget.muffinService,
        actions: [
          MuffinActionConfig(
            action: action,
            label: _labelForAction(action),
          ),
        ],
      ),
    );
  }

  void _openMuffin(ChapterProgress progress, MuffinAction action) {
    final context = MuffinContext(
      studentProfileId: 'qidah',
      preferredLanguage: 'Mixed',
      subjectId: progress.subjectId,
      subjectTitle:
          progress.subjectId == 'math' ? 'Mathematics' : progress.subjectId,
      chapterId: progress.chapterId,
      chapterTitle: progress.chapterId,
      mode: MuffinMode.practice,
      currentScreen: 'muffin_home',
      practiceBestScore: progress.practiceBestPercentage,
      quizBestScore: progress.quizBestPercentage,
      quizPassed: progress.quizPassed,
      masteredFlashcardCount: progress.flashcardsMasteredCount,
    );
    showModalBottomSheet<void>(
      context: this.context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => MuffinAssistSheet(
        title: 'Muffin',
        subtitle: 'I can use your latest chapter as light context.',
        mode: MuffinMode.practice,
        context: context,
        service: widget.muffinService,
        actions: [
          MuffinActionConfig(
            action: action,
            label: _labelForAction(action),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final walletService =
        widget.walletService ?? MuffinWalletServiceFactory.create();
    return Scaffold(
      body: SafeArea(
        child: StreamBuilder(
          stream: walletService.watchWallet(),
          initialData: MuffinWallet.full,
          builder: (context, walletSnapshot) {
            final wallet = walletSnapshot.data ?? MuffinWallet.full;
            return FutureBuilder<List<ChapterProgress>>(
              future: _progressFuture,
              builder: (context, snapshot) {
                final progress = [
                  ...snapshot.data ?? const <ChapterProgress>[]
                ];
                progress.sort((a, b) {
                  final aActivity = a.lastActivityAt;
                  final bActivity = b.lastActivityAt;
                  if (aActivity == null && bActivity == null) return 0;
                  if (aActivity == null) return 1;
                  if (bActivity == null) return -1;
                  return bActivity.compareTo(aActivity);
                });
                final latest = progress.isEmpty ? null : progress.first;
                return ListView(
                  key: const PageStorageKey<String>('muffin-tab-scroll'),
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                  children: [
                    Text('Muffin',
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 18),
                    Card(
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: StudySisDecorations.softAccentSurface(
                          context,
                          accent: StudySisColors.muffinAccent(context),
                          surface: StudySisColors.muffinSurface(context),
                          radius: 24,
                        ),
                        child: Column(
                          children: [
                            const MuffinMascotIcon(size: 62),
                            const SizedBox(height: 10),
                            Text(
                              'Your AI learning companion',
                              style: Theme.of(context).textTheme.titleLarge,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Muffin can explain concepts, give hints, guide questions, and translate content.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              '\u{1F36A} ${wallet.currentBites} / ${wallet.maxBites} Muffin Bites',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: () => latest == null
                                  ? _openGeneralMuffin(MuffinAction.askMuffin)
                                  : _openMuffin(
                                      latest,
                                      MuffinAction.askMuffin,
                                    ),
                              icon: const Icon(Icons.psychology_rounded),
                              label: const Text('Ask Muffin'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (snapshot.hasError)
                      _MuffinState(
                        icon: Icons.cloud_off_rounded,
                        title: 'Muffin could not load progress right now.',
                        message: 'You can still ask a general study question.',
                        actionLabel: 'Retry',
                        onAction: _retry,
                      )
                    else ...[
                      _MuffinActionCard(
                        title: 'Explain my current chapter',
                        subtitle: latest == null
                            ? 'Start a lesson for chapter-aware help.'
                            : 'A simple explanation using your latest progress.',
                        onTap: latest == null
                            ? () => _openGeneralMuffin(
                                  MuffinAction.explainConcept,
                                )
                            : () => _openMuffin(
                                  latest,
                                  MuffinAction.explainConcept,
                                ),
                      ),
                      _MuffinActionCard(
                        title: 'What should I revise?',
                        subtitle: 'A gentle suggestion from saved scores.',
                        onTap: latest == null
                            ? () => _openGeneralMuffin(MuffinAction.smallHint)
                            : () => _openMuffin(
                                  latest,
                                  MuffinAction.smallHint,
                                ),
                      ),
                      _MuffinActionCard(
                        title: 'Create a quick practice question',
                        subtitle: 'One temporary generated question.',
                        onTap: latest == null
                            ? () => _openGeneralMuffin(
                                  MuffinAction.generateSimilarQuestion,
                                )
                            : () => _openMuffin(
                                  latest,
                                  MuffinAction.generateSimilarQuestion,
                                ),
                      ),
                    ],
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _labelForAction(MuffinAction action) {
    switch (action) {
      case MuffinAction.askMuffin:
        return 'Ask Muffin';
      case MuffinAction.explainConcept:
        return 'Explain this chapter';
      case MuffinAction.smallHint:
        return 'Suggest what to revise';
      case MuffinAction.generateSimilarQuestion:
        return 'Create a quick practice question';
      case MuffinAction.explainSimply:
      case MuffinAction.translate:
      case MuffinAction.anotherExample:
      case MuffinAction.stillConfused:
      case MuffinAction.identifyPattern:
      case MuffinAction.guideQuestion:
        return 'Ask Muffin';
    }
  }
}

class _MuffinActionCard extends StatelessWidget {
  const _MuffinActionCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.psychology_rounded, color: Color(0xFF496A5A)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(subtitle),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MuffinState extends StatelessWidget {
  const _MuffinState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: const Color(0xFF496A5A)),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
