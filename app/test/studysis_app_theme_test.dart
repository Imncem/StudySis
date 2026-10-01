import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studysis/main.dart';
import 'package:studysis/theme/theme_controller.dart';
import 'package:studysis/theme/theme_controller_scope.dart';
import 'package:studysis/widgets/theme_toggle_button.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
      'root theme toggle is bounded and can switch without covering app',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = ThemeController();
    await controller.load();
    await tester.pumpWidget(
      ThemeControllerScope(
        controller: controller,
        child: StudySisApp(
          startupError: Object(),
          themeController: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Connect StudySis to Firebase'), findsOneWidget);
    expect(find.byType(ThemeToggleButton), findsOneWidget);
    expect(find.byIcon(Icons.wb_sunny_rounded), findsOneWidget);
    expect(tester.getSize(find.byType(ThemeToggleButton)), const Size(44, 44));

    await tester.tap(find.byType(ThemeToggleButton));
    await tester.pumpAndSettle();

    expect(find.text('Connect StudySis to Firebase'), findsOneWidget);
    expect(find.byIcon(Icons.dark_mode_rounded), findsOneWidget);
    expect(tester.getSize(find.byType(ThemeToggleButton)), const Size(44, 44));
  });
}
