import 'package:flutter/widgets.dart';

import 'theme_controller.dart';

class ThemeControllerScope extends InheritedNotifier<ThemeController> {
  const ThemeControllerScope({
    required ThemeController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static ThemeController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<ThemeControllerScope>();
    assert(scope?.notifier != null, 'No ThemeControllerScope found.');
    return scope!.notifier!;
  }

  static ThemeController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ThemeControllerScope>()
        ?.notifier;
  }
}
