import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studysis/screens/level_up_screen.dart';

void main() {
  testWidgets('generic level-up screen displays level and continue',
      (tester) async {
    await tester.pumpWidget(
      _app(const LevelUpScreen(newLevel: 4, totalXp: 460)),
    );

    expect(find.text('LEVEL UP!'), findsOneWidget);
    expect(find.text('LEVEL 4'), findsOneWidget);
    expect(find.text('460 XP'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Study Pets'), findsNothing);
  });

  testWidgets('Level 3 screen announces Study Pets unlock', (tester) async {
    await tester.pumpWidget(
      _app(const LevelUpScreen(
        newLevel: 3,
        totalXp: 250,
        unlocksStudyPets: true,
      )),
    );

    expect(find.text('LEVEL 3'), findsOneWidget);
    expect(find.text("You've reached Level 3!"), findsOneWidget);
    expect(find.text('NEW FEATURE UNLOCKED'), findsOneWidget);
    expect(find.text('Study Pets'), findsOneWidget);
    expect(find.text('Maybe Later'), findsOneWidget);
    expect(find.text('Choose My Egg'), findsOneWidget);
  });

  testWidgets('Choose My Egg returns pet action', (tester) async {
    LevelUpAction? action;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: FilledButton(
            onPressed: () async {
              action = await Navigator.of(context).push<LevelUpAction>(
                MaterialPageRoute<LevelUpAction>(
                  builder: (_) => const LevelUpScreen(
                    newLevel: 3,
                    totalXp: 250,
                    unlocksStudyPets: true,
                  ),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose My Egg'));
    await tester.pumpAndSettle();

    expect(action?.wantsChoosePet, isTrue);
  });
}

Widget _app(Widget child) {
  return MaterialApp(home: child);
}
