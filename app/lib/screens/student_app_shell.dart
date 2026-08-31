import 'package:flutter/material.dart';

import '../models/student.dart';
import '../models/subject.dart';
import '../repositories/engagement_repository.dart';
import '../repositories/learning_repository.dart';
import '../repositories/pet_economy_repository.dart';
import '../repositories/student_progress_repository.dart';
import '../repositories/study_pet_repository.dart';
import '../services/firestore_service.dart';
import '../services/muffin_wallet_service.dart';
import '../services/saved_flashcard_service.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'muffin_screen.dart';
import 'profile_screen.dart';
import 'rewards_screen.dart';
import 'subjects_tab_screen.dart';

class StudentAppShell extends StatefulWidget {
  const StudentAppShell({
    this.firestoreService,
    this.learningRepository,
    this.walletService,
    this.savedFlashcardService,
    this.engagementRepository,
    this.progressRepository,
    this.petRepository,
    this.petEconomyRepository,
    this.studentStream,
    this.subjectsStream,
    this.nowProvider,
    super.key,
  });

  final FirestoreService? firestoreService;
  final LearningRepository? learningRepository;
  final MuffinWalletService? walletService;
  final SavedFlashcardService? savedFlashcardService;
  final EngagementRepository? engagementRepository;
  final StudentProgressRepository? progressRepository;
  final StudyPetRepository? petRepository;
  final PetEconomyRepository? petEconomyRepository;
  final Stream<Student>? studentStream;
  final Stream<List<Subject>>? subjectsStream;
  final DateTime Function()? nowProvider;

  @override
  State<StudentAppShell> createState() => _StudentAppShellState();
}

class _StudentAppShellState extends State<StudentAppShell> {
  int _selectedIndex = 0;
  late final LearningRepository _learningRepository;
  late final MuffinWalletService _walletService;
  late final SavedFlashcardService _savedFlashcardService;
  late final EngagementRepository _engagementRepository;
  late final StudentProgressRepository _progressRepository;
  late final StudyPetRepository _petRepository;
  late final PetEconomyRepository _petEconomyRepository;
  late final Stream<Student> _studentStream;
  late final Stream<List<Subject>> _subjectsStream;

  @override
  void initState() {
    super.initState();
    _learningRepository = widget.learningRepository ?? LearningRepository();
    _walletService =
        widget.walletService ?? MuffinWalletServiceFactory.create();
    _savedFlashcardService =
        widget.savedFlashcardService ?? SavedFlashcardServiceFactory.create();
    _engagementRepository =
        widget.engagementRepository ?? EngagementRepository();
    _progressRepository =
        widget.progressRepository ?? StudentProgressRepository();
    _petRepository = widget.petRepository ?? StudyPetRepository();
    _petEconomyRepository =
        widget.petEconomyRepository ?? PetEconomyRepository();
    final firestoreService = widget.firestoreService;
    _studentStream = (widget.studentStream ??
            (firestoreService ?? FirestoreService()).watchQidah())
        .asBroadcastStream();
    _subjectsStream = (widget.subjectsStream ??
            (firestoreService ?? FirestoreService()).watchSubjects())
        .asBroadcastStream();
  }

  void _selectTab(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _selectedIndex == 0) return;
        setState(() => _selectedIndex = 0);
      },
      child: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            HomeScreen(
              learningRepository: _learningRepository,
              walletService: _walletService,
              savedFlashcardService: _savedFlashcardService,
              engagementRepository: _engagementRepository,
              progressRepository: _progressRepository,
              petRepository: _petRepository,
              studentStream: _studentStream,
              subjectsStream: _subjectsStream,
              nowProvider: widget.nowProvider,
            ),
            SubjectsTabScreen(
              subjectsStream: _subjectsStream,
              learningRepository: _learningRepository,
              progressRepository: _progressRepository,
              engagementRepository: _engagementRepository,
              petRepository: _petRepository,
            ),
            MuffinScreen(
              progressRepository: _progressRepository,
              walletService: _walletService,
            ),
            RewardsScreen(
              engagementRepository: _engagementRepository,
              petRepository: _petRepository,
              petEconomyRepository: _petEconomyRepository,
              nowProvider: widget.nowProvider,
            ),
            ProfileScreen(
              studentStream: _studentStream,
            ),
          ],
        ),
        bottomNavigationBar: _StudySisBottomNavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _selectTab,
        ),
      ),
    );
  }
}

class _StudySisBottomNavigationBar extends StatelessWidget {
  const _StudySisBottomNavigationBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = StudySisColors.isDark(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.45)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.07),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        height: 72,
        backgroundColor: Colors.transparent,
        elevation: 0,
        indicatorColor: scheme.primary.withValues(alpha: isDark ? 0.18 : 0.12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book_rounded),
            label: 'Subjects',
          ),
          NavigationDestination(
            icon: Icon(Icons.psychology_outlined),
            selectedIcon: Icon(Icons.psychology_rounded),
            label: 'Muffin',
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon: Icon(Icons.emoji_events_rounded),
            label: 'Rewards',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
