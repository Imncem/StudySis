import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studysis/models/study_pet.dart';
import 'package:studysis/repositories/study_pet_repository.dart';
import 'package:studysis/widgets/pixel_study_pet.dart';
import 'package:studysis/widgets/roaming_study_pet_companion.dart';

void main() {
  const uid = 'student-1';

  test('pixel sprite sets use species-specific movement', () {
    expect(pixelSpriteSetFor(StudyPetId.fox).movement, PixelPetMotion.walk);
    expect(pixelSpriteSetFor(StudyPetId.bunny).movement, PixelPetMotion.hop);
    expect(pixelSpriteSetFor(StudyPetId.cat).movement, PixelPetMotion.walk);
    expect(pixelSpriteSetFor(StudyPetId.fox).moveFrames, hasLength(4));
    expect(pixelSpriteSetFor(StudyPetId.bunny).moveFrames, hasLength(4));
    expect(pixelSpriteSetFor(StudyPetId.cat).moveFrames, hasLength(4));
  });

  test('pixel sprite sets have readable growth-stage variants', () {
    final hatchling = pixelSpriteSetFor(StudyPetId.bunny);
    final young = pixelSpriteSetFor(
      StudyPetId.bunny,
      growthStage: StudyPetGrowthStage.young,
    );
    final evolved = pixelSpriteSetFor(
      StudyPetId.bunny,
      growthStage: StudyPetGrowthStage.evolved,
    );
    final adult = pixelSpriteSetFor(
      StudyPetId.bunny,
      growthStage: StudyPetGrowthStage.adult,
    );

    expect(young.idleFrames.first.rows, isNot(hatchling.idleFrames.first.rows));
    expect(
        evolved.idleFrames.first.rows, isNot(hatchling.idleFrames.first.rows));
    expect(adult.idleFrames.first.rows, isNot(hatchling.idleFrames.first.rows));
    expect(adult.moveFrames, hasLength(hatchling.moveFrames.length));
  });

  test('bunny pixel sprite has tall ears and inner-ear pixels', () {
    final bunny = pixelSpriteSetFor(StudyPetId.bunny);
    final firstRows = bunny.idleFrames.first.rows;

    expect(firstRows, hasLength(greaterThan(12)));
    expect(firstRows.take(4).join(), contains('i'));
    expect(firstRows[1].replaceAll('.', ''), 'gggg');
    expect(firstRows[2].replaceAll('.', ''), 'iiii');
    expect(firstRows[3].replaceAll('.', ''), 'gggggg');
  });

  test('bunny growth stages keep rabbit ears and add stage details', () {
    for (final stage in StudyPetGrowthStage.values) {
      final rows = pixelSpriteSetFor(StudyPetId.bunny, growthStage: stage)
          .idleFrames
          .first
          .rows;

      expect(rows.take(4).join(), contains('i'));
      expect(rows[1].replaceAll('.', ''), contains('g'));
      expect(rows[2].replaceAll('.', ''), contains('i'));
    }

    final youngRows = pixelSpriteSetFor(
      StudyPetId.bunny,
      growthStage: StudyPetGrowthStage.young,
    ).idleFrames.first.rows;
    expect(youngRows[8].substring(13, 14), 'c');

    final evolvedRows = pixelSpriteSetFor(
      StudyPetId.bunny,
      growthStage: StudyPetGrowthStage.evolved,
    ).idleFrames.first.rows;
    expect(evolvedRows[0], contains('b'));
  });

  test('roaming lane and quantized positions stay inside bounds', () {
    final size = roamingPixelPetSizeForWidth(390);
    final lane = roamingLaneForWidth(390, size);
    expect(size, 48);
    expect(lane.left, greaterThanOrEqualTo(18));
    expect(lane.right + size, lessThanOrEqualTo(390 - 18));
    expect(quantizeRoamingX(41), 42);

    final wideLane = roamingLaneForWidth(1200, size);
    expect(wideLane.width + size, lessThanOrEqualTo(520));
    expect(wideLane.left, greaterThan(300));
  });

  testWidgets('does not show a roaming companion before a pet is hatched',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    final repository = _repository(firestore, uid);

    await firestore.doc('student_progress/$uid/pet/state').set({
      'schemaVersion': 1,
      'stage': 'egg',
      'eggId': 'egg_spark',
      'petId': null,
      'petName': null,
    });

    await tester.pumpWidget(_host(repository));
    await tester.pumpAndSettle();

    expect(find.byType(PixelStudyPet), findsNothing);
  });

  testWidgets('does not show a roaming companion for missing locked pet state',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    final repository = _repository(firestore, uid);

    await tester.pumpWidget(_host(repository));
    await tester.pumpAndSettle();

    expect(find.byType(PixelStudyPet), findsNothing);
  });

  for (final entry in const [
    ('pet_fox', StudyPetId.fox, 'Nara'),
    ('pet_bunny', StudyPetId.bunny, 'Milo'),
    ('pet_cat', StudyPetId.cat, 'Luna'),
  ]) {
    testWidgets('shows the correct roaming companion for ${entry.$1}',
        (tester) async {
      final firestore = FakeFirebaseFirestore();
      final repository = _repository(firestore, uid);
      await _seedHatchling(firestore, uid, petId: entry.$1, petName: entry.$3);

      await tester.pumpWidget(_host(repository));
      await tester.pumpAndSettle();

      final visual = tester.widget<PixelStudyPet>(
        find.byType(PixelStudyPet),
      );
      expect(visual.pet.id, entry.$2);
      expect(visual.growthStage, StudyPetGrowthStage.hatchling);
      expect(visual.motion, PixelPetMotion.idle);
      expect(find.bySemanticsLabel('${entry.$3} roaming Study Buddy'),
          findsOneWidget);
    });
  }

  testWidgets('roaming companion reflects growth stage', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final repository = _repository(firestore, uid);
    await _seedHatchling(
      firestore,
      uid,
      petId: 'pet_bunny',
      growthStage: StudyPetGrowthStage.evolved,
    );

    await tester.pumpWidget(_host(repository));
    await tester.pumpAndSettle();

    final visual = tester.widget<PixelStudyPet>(find.byType(PixelStudyPet));
    expect(visual.pet.id, StudyPetId.bunny);
    expect(visual.growthStage, StudyPetGrowthStage.evolved);
  });

  testWidgets('stationary mode keeps the pixel pet idle on focused screens',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    final repository = _repository(firestore, uid);
    await _seedHatchling(firestore, uid, petId: 'pet_bunny');

    await tester.pumpWidget(_host(
      repository,
      mode: RoamingStudyPetMode.stationary,
    ));
    await tester.pumpAndSettle();

    final visual = tester.widget<PixelStudyPet>(find.byType(PixelStudyPet));
    expect(visual.pet.id, StudyPetId.bunny);
    expect(visual.motion, PixelPetMotion.idle);
  });

  testWidgets('hides the roaming companion when the host route opts out',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    final repository = _repository(firestore, uid);
    await _seedHatchling(firestore, uid);

    await tester.pumpWidget(_host(repository, hidden: true));
    await tester.pumpAndSettle();

    expect(find.byType(PixelStudyPet), findsNothing);
  });

  testWidgets('reduced motion renders a static pixel companion',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    final repository = _repository(firestore, uid);
    await _seedHatchling(firestore, uid, petId: 'pet_cat');

    await tester.pumpWidget(_host(repository, disableAnimations: true));
    await tester.pumpAndSettle();

    final visual = tester.widget<PixelStudyPet>(find.byType(PixelStudyPet));
    expect(visual.pet.id, StudyPetId.cat);
    expect(visual.motion, PixelPetMotion.idle);
  });

  testWidgets('roaming companion remains above bottom navigation',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final firestore = FakeFirebaseFirestore();
    final repository = _repository(firestore, uid);
    await _seedHatchling(firestore, uid);

    await tester.pumpWidget(_hostWithBottomNavigation(repository));
    await tester.pumpAndSettle();

    final petRect = tester.getRect(find.byType(PixelStudyPet));
    final navRect = tester.getRect(find.byType(NavigationBar));
    expect(petRect.bottom, lessThan(navRect.top));
  });

  testWidgets('does not block taps on dashboard content beneath it',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    final repository = _repository(firestore, uid);
    await _seedHatchling(firestore, uid);
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Center(
                child: TextButton(
                  onPressed: () => taps += 1,
                  child: const Text('Open Subjects'),
                ),
              ),
              RoamingStudyPetCompanion(petRepository: repository),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Subjects'));
    expect(taps, 1);
  });

  testWidgets('bottom navigation remains tappable beneath roaming companion',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    final repository = _repository(firestore, uid);
    await _seedHatchling(firestore, uid);
    var selected = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Stack(
              children: [
                Scaffold(
                  body: const SizedBox.expand(),
                  bottomNavigationBar: NavigationBar(
                    selectedIndex: selected,
                    onDestinationSelected: (index) {
                      setState(() => selected = index);
                    },
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.home_outlined),
                        label: 'Home',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.book_outlined),
                        label: 'Subjects',
                      ),
                    ],
                  ),
                ),
                RoamingStudyPetCompanion(petRepository: repository),
              ],
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Subjects'));
    expect(selected, 1);
  });

  testWidgets('roaming companion does not write pet state', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final repository = _repository(firestore, uid);
    await _seedHatchling(firestore, uid);
    final ref = firestore.doc('student_progress/$uid/pet/state');
    final before = (await ref.get()).data();

    await tester.pumpWidget(_host(repository));
    await tester.pumpAndSettle();

    expect((await ref.get()).data(), before);
  });

  testWidgets('pixel companion renders in light and dark mode', (tester) async {
    final pet = studyPets.first;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        home: Scaffold(
          body: Center(
            child: PixelStudyPet(
              pet: pet,
              motion: PixelPetMotion.walk,
              frame: 1,
            ),
          ),
        ),
      ),
    );
    expect(find.byType(PixelStudyPet), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        themeMode: ThemeMode.dark,
        home: Scaffold(
          body: Center(
            child: PixelStudyPet(
              pet: pet,
              motion: PixelPetMotion.walk,
              frame: 1,
              facingRight: false,
            ),
          ),
        ),
      ),
    );
    expect(find.byType(PixelStudyPet), findsOneWidget);
    expect(tester.widget<PixelStudyPet>(find.byType(PixelStudyPet)).facingRight,
        isFalse);
  });
}

StudyPetRepository _repository(FakeFirebaseFirestore firestore, String uid) {
  return StudyPetRepository(
    firestore: firestore,
    uidProvider: () => uid,
  );
}

Widget _host(
  StudyPetRepository repository, {
  bool hidden = false,
  bool disableAnimations = false,
  RoamingStudyPetMode mode = RoamingStudyPetMode.normal,
}) {
  return MaterialApp(
    home: Scaffold(
      body: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Stack(
          children: [
            const SizedBox.expand(),
            RoamingStudyPetCompanion(
              petRepository: repository,
              hidden: hidden,
              mode: mode,
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _hostWithBottomNavigation(StudyPetRepository repository) {
  return MaterialApp(
    home: Stack(
      children: [
        Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: NavigationBar(
            selectedIndex: 0,
            onDestinationSelected: (_) {},
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.book_outlined),
                label: 'Subjects',
              ),
            ],
          ),
        ),
        RoamingStudyPetCompanion(petRepository: repository),
      ],
    ),
  );
}

Future<void> _seedHatchling(
  FakeFirebaseFirestore firestore,
  String uid, {
  String petId = 'pet_fox',
  String petName = 'Nara',
  StudyPetGrowthStage growthStage = StudyPetGrowthStage.hatchling,
}) async {
  final now = Timestamp.fromDate(DateTime(2026, 1, 2, 12));
  await firestore.doc('student_progress/$uid/pet/state').set({
    'schemaVersion': 1,
    'petUnlockAcknowledgedAt': now,
    'stage': 'hatchling',
    'eggId': 'egg_spark',
    'petId': petId,
    'selectedAt': now,
    'xpBaselineAtSelection': 250,
    'hatchXpTarget': hatchXpTargetDefault,
    'hatchDelayHours': hatchDelayHoursDefault,
    'hatchedAt': now,
    'petName': petName,
    'growthStage': growthStage.storageId,
    'xpBaselineAtHatch': 350,
    'lastEvolutionAt': null,
    'updatedAt': now,
  });
}
