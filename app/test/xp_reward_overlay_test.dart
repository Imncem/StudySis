import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studysis/widgets/xp_reward_overlay.dart';

void main() {
  testWidgets('XP overlay displays awarded amount and message', (tester) async {
    await tester.pumpWidget(_host());
    await tester.tap(find.text('Show'));
    await tester.pump();

    expect(find.text('+20 XP'), findsOneWidget);
    expect(find.text('Lesson complete!'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1900));
    expect(find.text('+20 XP'), findsNothing);
  });

  testWidgets('XP overlay does not show zero XP', (tester) async {
    await tester.pumpWidget(_host(awardedXp: 0));
    await tester.tap(find.text('Show'));
    await tester.pump();

    expect(find.text('+0 XP'), findsNothing);
    expect(find.text('Lesson complete!'), findsNothing);
  });

  testWidgets('XP overlay reduced-motion path remains usable', (tester) async {
    await tester.pumpWidget(_host(disableAnimations: true));
    await tester.tap(find.text('Show'));
    await tester.pump();

    expect(find.text('+20 XP'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(milliseconds: 1900));
  });
}

Widget _host({int awardedXp = 20, bool disableAnimations = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () {
                XpRewardOverlay.show(
                  context,
                  awardedXp: awardedXp,
                  message: 'Lesson complete!',
                );
              },
              child: const Text('Show'),
            ),
          ),
        ),
      ),
    ),
  );
}
