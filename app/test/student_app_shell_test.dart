import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studysis/config/content_paths.dart';
import 'package:studysis/models/muffin_wallet.dart';
import 'package:studysis/models/student.dart';
import 'package:studysis/models/subject.dart';
import 'package:studysis/repositories/engagement_repository.dart';
import 'package:studysis/repositories/learning_repository.dart';
import 'package:studysis/repositories/pet_economy_repository.dart';
import 'package:studysis/repositories/student_progress_repository.dart';
import 'package:studysis/repositories/study_pet_repository.dart';
import 'package:studysis/screens/student_app_shell.dart';
import 'package:studysis/services/muffin_wallet_service.dart';
import 'package:studysis/services/saved_flashcard_service.dart';
import 'package:studysis/theme/app_theme.dart';
import 'package:studysis/theme/theme_controller.dart';
import 'package:studysis/theme/theme_controller_scope.dart';
import 'package:studysis/widgets/theme_toggle_button.dart';

const uid = 'anonymousUid123';

void main() {
  testWidgets('bottom navigation has exactly five tabs and Home is initial',
      (tester) async {
    await tester.pumpWidget(await _app());
    await tester.pumpAndSettle();

    expect(find.byType(NavigationDestination), findsNWidgets(5));
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Subjects'), findsOneWidget);
    expect(find.text('Muffin'), findsOneWidget);
    expect(find.text('Rewards'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0);
    expect(find.text('Hi Qidah'), findsOneWidget);
  });

  testWidgets('tabs open Subjects, Muffin, Rewards, Profile, and Home',
      (tester) async {
    await tester.pumpWidget(await _app());
    await tester.pumpAndSettle();

    await _tapTab(tester, 'Subjects');
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1);
    expect(find.text('Choose what you want to learn today.'), findsOneWidget);

    await _tapTab(tester, 'Muffin');
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        2);
    expect(find.text('Your AI learning companion'), findsOneWidget);

    await _tapTab(tester, 'Rewards');
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        3);
    expect(find.text('Your streak, XP, Paw Coins, and Study Buddy live here.'),
        findsOneWidget);

    await _tapTab(tester, 'Profile');
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        4);
    expect(find.text('Preferences'), findsOneWidget);

    await _tapTab(tester, 'Home');
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0);
    expect(find.text('My Day'), findsOneWidget);
  });

  testWidgets('Home is compact and Subjects tab contains subject list',
      (tester) async {
    await tester.pumpWidget(await _app());
    await tester.pumpAndSettle();

    expect(find.text('Daily target'), findsNothing);
    expect(find.text('Language'), findsNothing);
    expect(find.text('My Day'), findsOneWidget);
    expect(find.text('Continue Learning'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -450));
    await tester.pumpAndSettle();
    expect(find.text('Saved Flashcards'), findsOneWidget);
    expect(find.text('Mathematics'), findsNothing);

    await _tapTab(tester, 'Subjects');
    expect(find.text('Mathematics'), findsOneWidget);
    expect(find.text('Science'), findsWidgets);
  });

  testWidgets('Mathematics opens from Subjects without stacking tabs',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    await _seedCurriculum(firestore);
    await tester.pumpWidget(await _app(firestore: firestore));
    await tester.pumpAndSettle();

    await _tapTab(tester, 'Subjects');
    await tester.tap(find.text('Mathematics'));
    await tester.pumpAndSettle();

    expect(find.text('Choose a chapter to begin the learning journey.'),
        findsOneWidget);
    expect(find.text('Patterns and Sequences'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1);
  });

  testWidgets('Rewards opens existing Study Pet flow', (tester) async {
    await tester.pumpWidget(await _app());
    await tester.pumpAndSettle();

    await _tapTab(tester, 'Rewards');
    await tester.drag(
      find.byKey(const PageStorageKey<String>('rewards-tab-scroll')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rewards-study-buddy-card')));
    await tester.pumpAndSettle();

    expect(find.text('Study Pets'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('Muffin tab does not consume Muffin Bites', (tester) async {
    await tester.pumpWidget(await _app(
      walletService: const StaticMuffinWalletService(
        MuffinWallet(
          maxBites: 5,
          currentBites: 3,
          regenIntervalMinutes: 60,
          dailyUsedRequests: 2,
          dailySoftLimit: 17,
          dailyHardLimit: 20,
          status: 'active',
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await _tapTab(tester, 'Muffin');
    expect(find.textContaining('3 / 5 Muffin Bites'), findsOneWidget);
    await _tapTab(tester, 'Home');
    expect(find.textContaining('3 / 5'), findsOneWidget);
  });

  testWidgets(
      'theme switching preserves selected tab and Profile reflects mode',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final controller = ThemeController();
    await controller.load();
    await tester.pumpWidget(await _app(themeController: controller));
    await tester.pumpAndSettle();

    await _tapTab(tester, 'Profile');
    expect(find.text('Light'), findsOneWidget);

    await tester.tap(find.byType(ThemeToggleButton));
    await tester.pumpAndSettle();

    expect(controller.themeMode, ThemeMode.dark);
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        4);
    expect(find.text('Dark'), findsOneWidget);
  });

  testWidgets('tab navigation does not award engagement progress',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    await _seedEngagementState(firestore, studyPoints: 1, xp: 20);
    await tester.pumpWidget(await _app(firestore: firestore));
    await tester.pumpAndSettle();

    await _tapTab(tester, 'Subjects');
    await _tapTab(tester, 'Muffin');
    await _tapTab(tester, 'Rewards');
    await _tapTab(tester, 'Profile');
    await _tapTab(tester, 'Home');

    final data =
        (await firestore.doc('student_progress/$uid/engagement/state').get())
            .data()!;
    expect(data['todayStudyPoints'], 1);
    expect(data['totalXp'], 20);
    expect(data['currentStreak'], 2);
  });

  testWidgets('startup preserves existing engagement pet and economy state',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    await _seedEngagementState(firestore, studyPoints: 3, xp: 520);
    await firestore.doc('student_progress/$uid/pet/state').set({
      'schemaVersion': 1,
      'petUnlockAcknowledgedAt': Timestamp.fromDate(DateTime.utc(2026, 8, 17)),
      'eggId': 'egg_spark',
      'petId': 'pet_fox',
      'petName': 'Ghazi',
      'stage': 'hatchling',
      'growthStage': 'young',
      'habitatTheme': 'farm',
      'selectedAt': Timestamp.fromDate(DateTime.utc(2026, 8, 17)),
      'xpBaselineAtSelection': 260,
      'hatchXpTarget': 100,
      'hatchDelayHours': 24,
      'hatchedAt': Timestamp.fromDate(DateTime.utc(2026, 8, 18)),
      'xpBaselineAtHatch': 360,
      'lastEvolutionAt': Timestamp.fromDate(DateTime.utc(2026, 8, 20)),
      'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 8, 20)),
    });
    await firestore.doc('student_progress/$uid/pet_economy/state').set({
      'schemaVersion': 1,
      'pawCoins': 65,
      'lifetimePawCoinsEarned': 120,
      'totalPawCoinsSpent': 55,
      'creditedCoinActivities': {'learn_math_chapter-1_notes': true},
      'ownedCosmeticIds': ['star_scarf'],
      'equippedCosmetics': {'head': null, 'face': null, 'neck': 'star_scarf'},
      'lastPurchasedItemId': 'star_scarf',
      'lastPurchasedAt': Timestamp.fromDate(DateTime.utc(2026, 8, 20)),
      'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 8, 20)),
    });

    await tester.pumpWidget(await _app(firestore: firestore));
    await tester.pumpAndSettle();

    final engagement =
        (await firestore.doc('student_progress/$uid/engagement/state').get())
            .data()!;
    final pet =
        (await firestore.doc('student_progress/$uid/pet/state').get()).data()!;
    final economy =
        (await firestore.doc('student_progress/$uid/pet_economy/state').get())
            .data()!;

    expect(engagement['totalXp'], 520);
    expect(engagement['todayStudyPoints'], 3);
    expect(pet['petName'], 'Ghazi');
    expect(pet['growthStage'], 'young');
    expect(economy['pawCoins'], 65);
    expect((economy['equippedCosmetics'] as Map)['neck'], 'star_scarf');
  });

  testWidgets('bottom navigation renders safely in dark mode', (tester) async {
    SharedPreferences.setMockInitialValues({
      ThemeController.preferenceKey: 'dark',
    });
    final controller = ThemeController();
    await controller.load();
    await tester.pumpWidget(await _app(themeController: controller));
    await tester.pumpAndSettle();

    expect(controller.themeMode, ThemeMode.dark);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
  });
}

Future<void> _tapTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<Widget> _app({
  FakeFirebaseFirestore? firestore,
  MuffinWalletService walletService = const StaticMuffinWalletService(),
  ThemeController? themeController,
}) async {
  final db = firestore ?? FakeFirebaseFirestore();
  final controller = themeController ?? ThemeController();
  return ThemeControllerScope(
    controller: controller,
    child: AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: controller.themeMode,
          home: Stack(
            children: [
              StudentAppShell(
                learningRepository: LearningRepository(firestore: db),
                walletService: walletService,
                savedFlashcardService: const StaticSavedFlashcardService(),
                engagementRepository: EngagementRepository(
                  firestore: db,
                  uidProvider: () => uid,
                  nowProvider: () => DateTime.utc(2026, 8, 17, 2),
                ),
                progressRepository: StudentProgressRepository(
                  firestore: db,
                  uidProvider: () => uid,
                ),
                petRepository: StudyPetRepository(
                  firestore: db,
                  uidProvider: () => uid,
                  nowProvider: () => DateTime.utc(2026, 8, 17, 2),
                ),
                petEconomyRepository: PetEconomyRepository(
                  firestore: db,
                  uidProvider: () => uid,
                ),
                studentStream: Stream.value(
                  const Student(
                    id: 'qidah',
                    name: 'Qidah',
                    preferredLanguage: 'Mixed',
                    dailyTargetMinutes: 30,
                    status: 'active',
                  ),
                ).asBroadcastStream(),
                subjectsStream: Stream.value(_subjects).asBroadcastStream(),
                nowProvider: () => DateTime.utc(2026, 8, 17, 2),
              ),
              Positioned(
                top: 12,
                right: 14,
                child: SafeArea(
                  child: ThemeToggleButton(controller: controller),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

const _subjects = [
  Subject(
    id: 'math',
    displayName: 'Mathematics',
    shortName: 'Math',
    contentStatus: 'available',
    iconName: 'math',
    themeColor: '#496A5A',
    order: 1,
  ),
  Subject(
    id: 'science',
    displayName: 'Science',
    shortName: 'Science',
    contentStatus: 'coming_soon',
    iconName: 'science',
    themeColor: '#3E8EC9',
    order: 2,
  ),
];

Future<void> _seedEngagementState(
  FakeFirebaseFirestore firestore, {
  required int studyPoints,
  required int xp,
}) async {
  await firestore.doc('student_progress/$uid/engagement/state').set({
    'totalXp': xp,
    'level': 1,
    'currentStreak': 2,
    'longestStreak': 2,
    'lastQualifiedDate': null,
    'todayDateKey': '2026-08-17',
    'todayStudyPoints': studyPoints,
    'dailyStudyTarget': 3,
    'todayStreakSecured': false,
    'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 8, 17)),
  });
}

Future<void> _seedCurriculum(FakeFirebaseFirestore firestore) async {
  await firestore.doc(ContentPaths.subject('math')).set({
    'displayName': 'Mathematics',
    'shortName': 'Math',
    'contentStatus': 'available',
    'iconName': 'math',
    'themeColor': '#496A5A',
    'order': 1,
  });
  await firestore.doc('${ContentPaths.chapters('math')}/chapter-1').set({
    'chapterNumber': 1,
    'title': 'Patterns and Sequences',
    'textbookChapterTitle': '',
    'learningObjectives': <String>[],
    'estimatedMinutes': 30,
    'status': 'active',
    'order': 1,
    'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
  });
}
