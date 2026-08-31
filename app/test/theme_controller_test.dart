import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studysis/theme/theme_controller.dart';

void main() {
  test('defaults to light mode when no preference exists', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = ThemeController();

    await controller.load();

    expect(controller.themeMode, ThemeMode.light);
    expect(controller.isDark, isFalse);
  });

  test('persists dark mode across controller recreation', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = ThemeController();
    await controller.load();

    await controller.toggle();

    expect(controller.themeMode, ThemeMode.dark);

    final restored = ThemeController();
    await restored.load();

    expect(restored.themeMode, ThemeMode.dark);
  });

  test('toggles back to light mode and persists it', () async {
    SharedPreferences.setMockInitialValues({
      ThemeController.preferenceKey: 'dark',
    });
    final controller = ThemeController();
    await controller.load();

    await controller.toggle();

    expect(controller.themeMode, ThemeMode.light);

    final restored = ThemeController();
    await restored.load();
    expect(restored.themeMode, ThemeMode.light);
  });
}
