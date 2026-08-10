import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studysis/screens/quick_translate_screen.dart';
import 'package:studysis/theme/app_theme.dart';

void main() {
  testWidgets('Quick Translate supports Bahasa Melayu translation',
      (tester) async {
    _setLargeSurface(tester);
    await tester.pumpWidget(_app());

    await tester.enterText(find.byType(TextField), '2, 4, 6, 8 pattern');
    await tester.tap(find.text('Translate'));
    await tester.pumpAndSettle();

    expect(find.text('Original'), findsOneWidget);
    expect(find.text('Translation'), findsOneWidget);
    expect(find.textContaining('bertambah'), findsOneWidget);
  });

  testWidgets('Quick Translate supports English translation and swap',
      (tester) async {
    _setLargeSurface(tester);
    await tester.pumpWidget(_app());

    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Terjemahan: corak');
    await tester.tap(find.text('Translate'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Translation:'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.swap_vert_rounded));
    await tester.pumpAndSettle();
    expect(find.text('English'), findsWidgets);
  });

  testWidgets('Quick Translate shows retryable error for empty input',
      (tester) async {
    _setLargeSurface(tester);
    await tester.pumpWidget(_app());

    await tester.tap(find.text('Translate'));
    await tester.pumpAndSettle();

    expect(
        find.text('Type or paste a word or sentence first.'), findsOneWidget);
  });
}

void _setLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _app() {
  return MaterialApp(
    theme: AppTheme.light,
    home: const QuickTranslateScreen(),
  );
}
