import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studysis/theme/app_theme.dart';
import 'package:studysis/theme/theme_controller.dart';
import 'package:studysis/theme/theme_controller_scope.dart';
import 'package:studysis/widgets/floating_muffin_shell.dart';
import 'package:studysis/widgets/theme_toggle_button.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows sun icon in light mode and switches to moon in dark mode',
      (tester) async {
    final controller = ThemeController();
    await controller.load();
    await tester.pumpWidget(_themeToggleApp(controller));

    expect(find.byIcon(Icons.wb_sunny_rounded), findsOneWidget);
    expect(find.byIcon(Icons.dark_mode_rounded), findsNothing);
    expect(
      find.bySemanticsLabel('Light mode. Tap to switch to dark mode.'),
      findsOneWidget,
    );

    await tester.tap(find.byType(ThemeToggleButton));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.dark_mode_rounded), findsOneWidget);
    expect(find.byIcon(Icons.wb_sunny_rounded), findsNothing);
    expect(
      find.bySemanticsLabel('Dark mode. Tap to switch to light mode.'),
      findsOneWidget,
    );
  });

  testWidgets('switches back to light mode from dark mode', (tester) async {
    final controller = ThemeController();
    await controller.load();
    await controller.setThemeMode(ThemeMode.dark);
    await tester.pumpWidget(_themeToggleApp(controller));

    await tester.tap(find.byType(ThemeToggleButton));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.wb_sunny_rounded), findsOneWidget);
    expect(controller.themeMode, ThemeMode.light);
  });

  testWidgets('renders above the floating Muffin button without overlap',
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
        child: MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: controller.themeMode,
          home: Scaffold(
            body: FloatingMuffinShell(
              child: Stack(
                children: [
                  const SizedBox.expand(),
                  Positioned(
                    top: 12,
                    right: 14,
                    width: 44,
                    height: 44,
                    child: ThemeToggleButton(controller: controller),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final toggleRect = tester.getRect(find.byType(ThemeToggleButton));
    final muffinRect = tester.getRect(
      find.bySemanticsLabel('Open Muffin learning assistant'),
    );

    expect(toggleRect.overlaps(muffinRect), isFalse);
    expect(toggleRect.top, lessThan(muffinRect.top));
  });

  testWidgets(
      'theme toggle remains bounded and does not paint a full-screen layer',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = ThemeController();
    await controller.load();
    await tester.pumpWidget(_themeToggleApp(controller));
    await tester.pumpAndSettle();

    final rect = tester.getRect(find.byType(ThemeToggleButton));
    expect(rect.width, 44);
    expect(rect.height, 44);
    expect(
      AppTheme.light.scaffoldBackgroundColor,
      const Color(0xFFF7F5F0),
    );
    expect(AppTheme.dark.scaffoldBackgroundColor, const Color(0xFF151A18));
    expect(AppTheme.dark.scaffoldBackgroundColor, isNot(Colors.red));
    expect(AppTheme.dark.colorScheme.surface, isNot(Colors.red));
    expect(AppTheme.dark.colorScheme.error,
        isNot(AppTheme.dark.colorScheme.surface));
  });
}

Widget _themeToggleApp(ThemeController controller) {
  return ThemeControllerScope(
    controller: controller,
    child: AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: controller.themeMode,
          home: const Scaffold(
            body: Center(child: ThemeToggleButton()),
          ),
        );
      },
    ),
  );
}
