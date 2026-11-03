import 'package:flutter/foundation.dart';

import 'learning_module.dart';

enum LearningModuleParentKind { chapter, subchapter, topic }

class LearningModuleParent {
  const LearningModuleParent.chapter({
    required this.subjectId,
    required this.chapterId,
  })  : kind = LearningModuleParentKind.chapter,
        subchapterId = null,
        topicId = null;

  const LearningModuleParent.subchapter({
    required this.subjectId,
    required this.chapterId,
    required String this.subchapterId,
  })  : kind = LearningModuleParentKind.subchapter,
        topicId = null;

  const LearningModuleParent.topic({
    required this.subjectId,
    required this.chapterId,
    required String this.topicId,
  })  : kind = LearningModuleParentKind.topic,
        subchapterId = null;

  final LearningModuleParentKind kind;
  final String subjectId;
  final String chapterId;
  final String? subchapterId;
  final String? topicId;

  String get diagnosticLabel => switch (kind) {
        LearningModuleParentKind.chapter => '$subjectId/$chapterId',
        LearningModuleParentKind.subchapter =>
          '$subjectId/$chapterId/subchapters/$subchapterId',
        LearningModuleParentKind.topic =>
          '$subjectId/$chapterId/topics/$topicId',
      };
}

List<LearningModule> sequenceActiveLearningModules(
  Iterable<LearningModule> modules, {
  String? parentLabel,
}) {
  final indexed = modules
      .where((module) => module.isActive)
      .toList(growable: false)
      .indexed
      .map((entry) => (index: entry.$1, module: entry.$2))
      .toList();

  final duplicateOrders = <int, List<String>>{};
  for (final entry in indexed.where((entry) => entry.module.hasValidOrder)) {
    duplicateOrders
        .putIfAbsent(entry.module.order, () => <String>[])
        .add(entry.module.id);
  }
  duplicateOrders.removeWhere((_, ids) => ids.length < 2);
  if (duplicateOrders.isNotEmpty) {
    debugPrint(
      '[StudySis][modules] Duplicate order values for '
      '${parentLabel ?? 'curriculum parent'}: $duplicateOrders. '
      'Keeping source order as the stable fallback.',
    );
  }

  final unordered = indexed
      .where((entry) => !entry.module.hasValidOrder)
      .map((entry) => entry.module.id)
      .toList(growable: false);
  if (unordered.isNotEmpty) {
    debugPrint(
      '[StudySis][modules] Missing or invalid order for '
      '${parentLabel ?? 'curriculum parent'}: $unordered. '
      'Placing these modules after explicitly ordered modules.',
    );
  }

  indexed.sort((left, right) {
    final leftOrdered = left.module.hasValidOrder;
    final rightOrdered = right.module.hasValidOrder;
    if (leftOrdered != rightOrdered) return leftOrdered ? -1 : 1;
    if (leftOrdered) {
      final byOrder = left.module.order.compareTo(right.module.order);
      if (byOrder != 0) return byOrder;
    }
    return left.index.compareTo(right.index);
  });
  return indexed.map((entry) => entry.module).toList(growable: false);
}
