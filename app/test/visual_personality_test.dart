import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studysis/theme/app_theme.dart';
import 'package:studysis/widgets/studysis_decorative_background.dart';

void main() {
  test('subject identities use distinct central accent families', () {
    expect(
      StudySisSubjectTheme.forSubject(id: 'math').primary,
      const Color(0xFF2F8F6B),
    );
    expect(
      StudySisSubjectTheme.forSubject(id: 'science').primary,
      const Color(0xFF3E8EC9),
    );
    expect(
      StudySisSubjectTheme.forSubject(id: 'bahasa_melayu').primary,
      const Color(0xFFE28A45),
    );
    expect(
      StudySisSubjectTheme.forSubject(id: 'english').primary,
      const Color(0xFF8067C7),
    );
    expect(
      StudySisSubjectTheme.forSubject(id: 'sejarah').primary,
      const Color(0xFFC96E5D),
    );
    expect(
      StudySisSubjectTheme.forSubject(id: 'geography').primary,
      const Color(0xFF39998E),
    );
    expect(
      StudySisSubjectTheme.forSubject(id: 'reka_bentuk_teknologi').primary,
      const Color(0xFFD49A32),
    );
  });

  test('subject light and dark token values are distinct', () {
    const subject = StudySisSubjectTheme.mathematics;

    expect(subject.darkPrimary, isNot(subject.primary));
    expect(subject.darkSoft, isNot(subject.soft));
  });

  testWidgets('decorative background renders in light mode and allows taps',
      (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: StudySisDecorativeBackground(
            child: Center(
              child: FilledButton(
                onPressed: () => tapped = true,
                child: const Text('Tap target'),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(StudySisDecorativeBackground), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    await tester.tap(find.text('Tap target'));
    expect(tapped, isTrue);
  });

  testWidgets('decorative background renders in dark mode and allows taps',
      (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        home: Scaffold(
          body: StudySisDecorativeBackground(
            density: StudySisPatternDensity.low,
            child: Center(
              child: TextButton(
                onPressed: () => tapped = true,
                child: const Text('Dark tap target'),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(StudySisDecorativeBackground), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    await tester.tap(find.text('Dark tap target'));
    expect(tapped, isTrue);
  });
}
