import 'package:flutter/material.dart';

import '../models/learning_module.dart';

class LearningModuleMetadata extends StatelessWidget {
  const LearningModuleMetadata({required this.module, super.key});

  final LearningModule module;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('learning-module-metadata'),
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(module.title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 3),
          Text(
            '${module.typeLabel} · ${_titleCase(module.difficulty)} · '
            '${module.estimatedMinutes} min',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

String _titleCase(String value) =>
    value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
