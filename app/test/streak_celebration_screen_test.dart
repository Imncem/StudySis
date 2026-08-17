import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studysis/screens/streak_celebration_screen.dart';
import 'package:studysis/widgets/muffin_mascot_icon.dart';

void main() {
  testWidgets('Day 1 uses starter copy and displays streak value',
      (tester) async {
    await tester.pumpWidget(_app(const StreakCelebrationScreen(streakDays: 1)));

    expect(find.text('1 DAY STREAK'), findsOneWidget);
    expect(find.text('Your streak starts today!'), findsOneWidget);
    expect(find.text("Nice start! Let's come back tomorrow."), findsOneWidget);
    expect(find.byType(MuffinMascotIcon), findsOneWidget);
  });

  testWidgets('Day 7 uses milestone copy', (tester) async {
    await tester.pumpWidget(_app(const StreakCelebrationScreen(streakDays: 7)));

    expect(find.text('7 DAY STREAK'), findsOneWidget);
    expect(find.text('One whole week!'), findsOneWidget);
    expect(
      find.text("Seven days of showing up. That's something to be proud of!"),
      findsOneWidget,
    );
  });

  testWidgets('XP reward displays only when valid reward data is available',
      (tester) async {
    await tester.pumpWidget(
      _app(const StreakCelebrationScreen(streakDays: 2, xpReward: 40)),
    );
    expect(find.text('\u{2B50} +40 XP'), findsOneWidget);

    await tester.pumpWidget(
      _app(const StreakCelebrationScreen(streakDays: 2)),
    );
    expect(find.textContaining('XP'), findsNothing);

    await tester.pumpWidget(
      _app(const StreakCelebrationScreen(streakDays: 2, xpReward: 0)),
    );
    expect(find.textContaining('XP'), findsNothing);
  });

  testWidgets('Continue closes the celebration without extra reward logic',
      (tester) async {
    await tester.pumpWidget(_hostedCelebration());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('3 DAY STREAK'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Closed'), findsOneWidget);
  });

  testWidgets('reduced-motion path remains usable', (tester) async {
    await tester.pumpWidget(
      _app(
        const StreakCelebrationScreen(streakDays: 14, xpReward: 10),
        disableAnimations: true,
      ),
    );

    expect(find.text('14 DAY STREAK'), findsOneWidget);
    expect(find.text('Two weeks strong!'), findsOneWidget);
    expect(find.text('\u{2B50} +10 XP'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('animation controllers dispose cleanly', (tester) async {
    await tester
        .pumpWidget(_app(const StreakCelebrationScreen(streakDays: 30)));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

Widget _app(Widget child, {bool disableAnimations = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: child,
    ),
  );
}

Widget _hostedCelebration() {
  return MaterialApp(
    home: Builder(
      builder: (context) {
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Closed'),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const StreakCelebrationScreen(
                          streakDays: 3,
                          xpReward: 20,
                        ),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
