import 'package:flutter/material.dart';

class LearningModuleNavigation extends StatelessWidget {
  const LearningModuleNavigation({
    required this.currentIndex,
    required this.totalModules,
    required this.onPrevious,
    required this.onNext,
    required this.onFinish,
    super.key,
  });

  final int currentIndex;
  final int totalModules;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    if (totalModules <= 1) return const SizedBox.shrink();
    final isLast = currentIndex == totalModules - 1;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Module ${currentIndex + 1} of $totalModules',
              key: const Key('module-sequence-progress'),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (onPrevious != null) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('previous-module-button'),
                      onPressed: onPrevious,
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('Previous'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: FilledButton.icon(
                    key: Key(isLast
                        ? 'back-to-module-list-button'
                        : 'next-module-button'),
                    onPressed: isLast ? onFinish : onNext,
                    icon: Icon(isLast
                        ? Icons.list_alt_rounded
                        : Icons.arrow_forward_rounded),
                    label: Text(
                      isLast ? 'Back to module list' : 'Next module',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
