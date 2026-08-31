import 'package:flutter/material.dart';

import '../theme/theme_controller.dart';
import '../theme/theme_controller_scope.dart';

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({this.controller, super.key});

  final ThemeController? controller;

  @override
  Widget build(BuildContext context) {
    final controller = this.controller ?? ThemeControllerScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final isDark = controller.isDark;
    final label = isDark
        ? 'Dark mode. Tap to switch to light mode.'
        : 'Light mode. Tap to switch to dark mode.';

    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: scheme.surface,
        shape: const CircleBorder(),
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.45 : 0.18),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: controller.toggle,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, animation) {
                  return ScaleTransition(
                    scale: CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutBack,
                    ),
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: Icon(
                  isDark ? Icons.dark_mode_rounded : Icons.wb_sunny_rounded,
                  key: ValueKey(isDark),
                  color: isDark ? scheme.secondary : scheme.primary,
                  size: 22,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
