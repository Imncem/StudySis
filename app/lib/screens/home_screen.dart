import 'package:flutter/material.dart';

import '../models/learning_content.dart';
import '../models/muffin_wallet.dart';
import '../models/page_translation.dart';
import '../models/saved_flashcard.dart';
import '../models/student.dart';
import '../models/subject.dart';
import '../repositories/learning_repository.dart';
import '../services/firestore_service.dart';
import '../services/muffin_context_registry.dart';
import '../services/muffin_wallet_service.dart';
import '../services/saved_flashcard_service.dart';
import '../widgets/info_chip.dart';
import '../widgets/muffin_mascot_icon.dart';
import '../widgets/page_translation_scope.dart';
import '../widgets/subject_card.dart';
import 'progress_screen.dart';
import 'saved_flashcards_screen.dart';
import 'subject_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    this.firestoreService,
    this.learningRepository,
    this.walletService,
    this.savedFlashcardService,
    this.studentStream,
    this.subjectsStream,
    super.key,
  });

  final FirestoreService? firestoreService;
  final LearningRepository? learningRepository;
  final MuffinWalletService? walletService;
  final SavedFlashcardService? savedFlashcardService;
  final Stream<Student>? studentStream;
  final Stream<List<Subject>>? subjectsStream;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _translationOwner = Object();
  late final LearningRepository _learningRepository;
  late final MuffinWalletService _walletService;
  late final SavedFlashcardService _savedFlashcardService;
  late Future<LearningContent?> _nextContent;
  bool _isOpeningModule = false;

  @override
  void initState() {
    super.initState();
    _learningRepository = widget.learningRepository ?? LearningRepository();
    _walletService =
        widget.walletService ?? MuffinWalletServiceFactory.create();
    _savedFlashcardService =
        widget.savedFlashcardService ?? SavedFlashcardServiceFactory.create();
    MuffinContextRegistry.instance.resetToHome();
    _nextContent = _learningRepository.getFirstAvailableContent();
  }

  Future<void> _refresh() async {
    final nextContent = _learningRepository.getFirstAvailableContent();
    setState(() {
      _nextContent = nextContent;
    });
    await nextContent;
  }

  Future<void> _continueLearning() async {
    if (_isOpeningModule) return;
    setState(() => _isOpeningModule = true);
    try {
      final content = await _learningRepository.getFirstAvailableContent();
      if (!mounted) return;
      setState(() {
        _nextContent = Future.value(content);
      });
      if (content == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Learning modules are being prepared.'),
          ),
        );
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SubjectScreen(
            subject: Subject(
              id: 'math',
              displayName: content.subjectName,
              shortName: content.subjectName,
              contentStatus: 'available',
              iconName: 'math',
              themeColor: '#496A5A',
              order: 1,
            ),
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open the module: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isOpeningModule = false);
    }
  }

  void _registerTranslationContent(BuildContext context) {
    final controller = PageTranslationScope.maybeOf(context);
    if (controller == null) return;
    final route = ModalRoute.of(context);
    if (route?.isCurrent != true) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      controller.registerPage(
        ownerToken: _translationOwner,
        routeName: ModalRoute.of(context)?.settings.name,
        content: const TranslatablePageContent(
          pageType: 'home',
          pageId: 'home_dashboard',
          sourceLanguage: TranslationLanguage.english,
          fields: [
            PageTranslationField(
              id: 'greeting',
              type: 'heading',
              text: 'Hi Qidah',
            ),
            PageTranslationField(
              id: 'encouragement',
              type: 'paragraph',
              text: "Let's take one gentle step today.",
            ),
            PageTranslationField(
              id: 'dailyTargetLabel',
              type: 'label',
              text: 'Daily target',
            ),
            PageTranslationField(
              id: 'languageLabel',
              type: 'label',
              text: 'Language',
            ),
            PageTranslationField(
              id: 'continueTitle',
              type: 'heading',
              text: 'Continue learning',
            ),
            PageTranslationField(
              id: 'progressTitle',
              type: 'heading',
              text: 'Progress',
            ),
            PageTranslationField(
              id: 'progressDescription',
              type: 'paragraph',
              text: 'See your saved learning progress.',
            ),
            PageTranslationField(
              id: 'muffinBitesTitle',
              type: 'heading',
              text: 'Muffin Bites',
            ),
            PageTranslationField(
              id: 'savedFlashcardsTitle',
              type: 'heading',
              text: 'Saved Flashcards',
            ),
            PageTranslationField(
              id: 'subjects',
              type: 'heading',
              text: 'Subjects',
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<Student>(
          stream: widget.studentStream ??
              (widget.firestoreService ?? FirestoreService()).watchQidah(),
          builder: (context, studentSnapshot) {
            if (studentSnapshot.hasError) {
              return _ErrorState(message: studentSnapshot.error.toString());
            }
            if (!studentSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final student = studentSnapshot.data!;
            _registerTranslationContent(context);
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                children: [
                  const PageTranslationBanner(),
                  Text(
                    PageTranslationScope.text(context, 'greeting', 'Hi Qidah'),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    PageTranslationScope.text(
                      context,
                      'encouragement',
                      "Let's take one gentle step today.",
                    ),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      InfoChip(
                        icon: Icons.timer_outlined,
                        label: PageTranslationScope.text(
                          context,
                          'dailyTargetLabel',
                          'Daily target',
                        ),
                        value: '${student.dailyTargetMinutes} min',
                      ),
                      const SizedBox(width: 12),
                      InfoChip(
                        icon: Icons.translate_rounded,
                        label: PageTranslationScope.text(
                          context,
                          'languageLabel',
                          'Language',
                        ),
                        value: student.preferredLanguage,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _ContinueCard(
                    content: _nextContent,
                    isOpening: _isOpeningModule,
                    onContinue: _continueLearning,
                  ),
                  const SizedBox(height: 14),
                  _ProgressEntryCard(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ProgressScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  _MuffinBitesDashboardCard(walletService: _walletService),
                  const SizedBox(height: 14),
                  _SavedFlashcardsDashboardSection(
                    savedFlashcardService: _savedFlashcardService,
                    learningRepository: _learningRepository,
                  ),
                  const SizedBox(height: 28),
                  Text(
                    PageTranslationScope.text(context, 'subjects', 'Subjects'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<List<Subject>>(
                    stream: widget.subjectsStream ??
                        (widget.firestoreService ?? FirestoreService())
                            .watchSubjects(),
                    builder: (context, subjectSnapshot) {
                      if (subjectSnapshot.hasError) {
                        return _InlineError(
                            message: subjectSnapshot.error.toString());
                      }
                      if (!subjectSnapshot.hasData) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final subjects = subjectSnapshot.data!;
                      if (subjects.isEmpty) {
                        return const _InlineError(
                          message: 'No subjects have been added yet.',
                        );
                      }
                      return Column(
                        children: [
                          for (final subject in subjects) ...[
                            SubjectCard(
                              subject: subject,
                              onTap: subject.isComingSoon
                                  ? null
                                  : () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              SubjectScreen(subject: subject),
                                        ),
                                      );
                                    },
                            ),
                            const SizedBox(height: 10),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ProgressEntryCard extends StatelessWidget {
  const _ProgressEntryCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5EEE8),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  color: Color(0xFF496A5A),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      PageTranslationScope.text(
                        context,
                        'progressTitle',
                        'Progress',
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      PageTranslationScope.text(
                        context,
                        'progressDescription',
                        'See your saved learning progress.',
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _MuffinBitesDashboardCard extends StatelessWidget {
  const _MuffinBitesDashboardCard({required this.walletService});

  final MuffinWalletService walletService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MuffinWallet>(
      stream: walletService.watchWallet(),
      initialData: MuffinWallet.full,
      builder: (context, snapshot) {
        final wallet = snapshot.data ?? MuffinWallet.full;
        final status = _statusText(wallet);
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const MuffinMascotIcon(),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        PageTranslationScope.text(
                          context,
                          'muffinBitesTitle',
                          'Muffin Bites',
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\u{1F36A} ${wallet.currentBites} / ${wallet.maxBites}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(status),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _statusText(MuffinWallet wallet) {
    final now = DateTime.now();
    if (wallet.isDailyLimitReached) {
      return 'Muffin is resting for today. More help will be available after the daily reset.';
    }
    if (!wallet.hasBites) {
      return 'Muffin is recharging. ${wallet.cooldownText(now)}';
    }
    if (wallet.currentBites < wallet.maxBites) {
      return wallet.cooldownText(now);
    }
    return 'Muffin is ready to help!';
  }
}

class _SavedFlashcardsDashboardSection extends StatelessWidget {
  const _SavedFlashcardsDashboardSection({
    required this.savedFlashcardService,
    required this.learningRepository,
  });

  final SavedFlashcardService savedFlashcardService;
  final LearningRepository learningRepository;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SavedFlashcardRef>>(
      stream: savedFlashcardService.watchSavedFlashcards(),
      initialData: const <SavedFlashcardRef>[],
      builder: (context, snapshot) {
        final refs = snapshot.data ?? const <SavedFlashcardRef>[];
        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SavedFlashcardsScreen(
                    learningRepository: learningRepository,
                    savedFlashcardService: savedFlashcardService,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          PageTranslationScope.text(
                            context,
                            'savedFlashcardsTitle',
                            'Saved Flashcards',
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const Text(
                        'View all',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(
                        Icons.bookmark_rounded,
                        color: Color(0xFFA45E37),
                      ),
                      const SizedBox(width: 8),
                      Text('${refs.length} saved flashcards'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (refs.isEmpty)
                    const Text(
                      "Save useful cards while studying and they'll appear here.",
                    )
                  else
                    _SavedFlashcardPreview(
                      ref: refs.first,
                      learningRepository: learningRepository,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SavedFlashcardPreview extends StatelessWidget {
  const _SavedFlashcardPreview({
    required this.ref,
    required this.learningRepository,
  });

  final SavedFlashcardRef ref;
  final LearningRepository learningRepository;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_SavedFlashcardPreviewData>(
      future: _load(),
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) {
          return const Text('Saved flashcards are ready to review.');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data.chapterTitle,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text('${data.subjectName} - ${data.chapterLabel}'),
          ],
        );
      },
    );
  }

  Future<_SavedFlashcardPreviewData> _load() async {
    final subjectName = await learningRepository.getSubjectName(ref.subjectId);
    final chapter = await learningRepository.getChapter(
      subjectId: ref.subjectId,
      chapterId: ref.chapterId,
    );
    return _SavedFlashcardPreviewData(
      subjectName: subjectName,
      chapterTitle: chapter?.title ?? 'Saved flashcard',
      chapterLabel:
          chapter == null ? ref.chapterId : 'Chapter ${chapter.chapterNumber}',
    );
  }
}

class _SavedFlashcardPreviewData {
  const _SavedFlashcardPreviewData({
    required this.subjectName,
    required this.chapterTitle,
    required this.chapterLabel,
  });

  final String subjectName;
  final String chapterTitle;
  final String chapterLabel;
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({
    required this.content,
    required this.isOpening,
    required this.onContinue,
  });

  final Future<LearningContent?> content;
  final bool isOpening;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFE5EEE8),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: FutureBuilder<LearningContent?>(
          future: content,
          builder: (context, snapshot) {
            final learningContent = snapshot.data;
            final hasError = snapshot.hasError;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  PageTranslationScope.text(
                    context,
                    'continueTitle',
                    'Continue learning',
                  ),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Text('Finding your next learning module...')
                else if (learningContent == null)
                  Text(
                    hasError
                        ? 'We could not check the learning modules right now.'
                        : 'Learning modules are being prepared.',
                  )
                else ...[
                  Text(
                    'Chapter ${learningContent.chapter.chapterNumber} - '
                    '${learningContent.module.title}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${learningContent.module.typeLabel} - '
                    '${learningContent.module.estimatedMinutes} min',
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: isOpening ? null : onContinue,
                  child: Text(isOpening ? 'Opening...' : 'Continue'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48),
            const SizedBox(height: 16),
            Text('We could not load StudySis',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(message),
      ),
    );
  }
}
