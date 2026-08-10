import 'package:flutter/foundation.dart';

import '../models/muffin.dart';
import '../widgets/muffin_assist_sheet.dart';

class MuffinScreenContext {
  const MuffinScreenContext({
    required this.mode,
    required this.context,
    required this.actions,
    required this.subtitle,
    this.showDedicatedMuffinScreen = true,
  });

  final MuffinMode mode;
  final MuffinContext context;
  final List<MuffinActionConfig> actions;
  final String subtitle;
  final bool showDedicatedMuffinScreen;
}

class MuffinContextRegistry {
  MuffinContextRegistry._();

  static final instance = MuffinContextRegistry._();

  final ValueNotifier<MuffinScreenContext?> current =
      ValueNotifier<MuffinScreenContext?>(home());

  static MuffinScreenContext home() {
    return const MuffinScreenContext(
      mode: MuffinMode.practice,
      subtitle: 'Choose a focused Muffin action.',
      context: MuffinContext(
        mode: MuffinMode.practice,
        currentScreen: 'home',
        preferredLanguage: 'Mixed',
      ),
      actions: [
        MuffinActionConfig(
          action: MuffinAction.askMuffin,
          label: 'Ask Muffin',
        ),
        MuffinActionConfig(
          action: MuffinAction.smallHint,
          label: 'What should I revise?',
        ),
        MuffinActionConfig(
          action: MuffinAction.generateSimilarQuestion,
          label: 'Create a quick practice question',
        ),
      ],
    );
  }

  void set(MuffinScreenContext context) {
    current.value = context;
  }

  void resetToHome() {
    current.value = home();
  }

  void clear() {
    current.value = null;
  }
}
