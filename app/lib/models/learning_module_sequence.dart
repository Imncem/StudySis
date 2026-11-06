import 'package:flutter/foundation.dart';

import '../config/curriculum_structure.dart';
import 'learning_location.dart';
import 'learning_module.dart';

enum LearningModuleParentKind { chapter, subchapter, topic }

class LearningModuleParent {
  const LearningModuleParent.chapter({
    required this.subjectId,
    required this.chapterId,
    this.subjectName,
    this.parentTitle,
    this.parentNumber,
    this.parentOrder = 0,
    String? parentKindOverride,
    String? structureLabelOverride,
  })  : kind = LearningModuleParentKind.chapter,
        subchapterId = null,
        topicId = null,
        parentKind = parentKindOverride ?? 'chapter',
        structureLabel = structureLabelOverride ?? 'Chapter',
        containerTitle = null,
        containerNumber = null;

  const LearningModuleParent.subchapter({
    required this.subjectId,
    required this.chapterId,
    required String this.subchapterId,
    this.subjectName,
    this.parentTitle,
    this.parentNumber,
    this.parentOrder = 0,
    this.containerTitle,
    this.containerNumber,
  })  : kind = LearningModuleParentKind.subchapter,
        topicId = null,
        parentKind = 'subchapter',
        structureLabel = 'Subchapter';

  const LearningModuleParent.topic({
    required this.subjectId,
    required this.chapterId,
    required String this.topicId,
    this.subjectName,
    this.parentTitle,
    this.parentNumber,
    this.parentOrder = 0,
    this.containerTitle,
    this.containerNumber,
  })  : kind = LearningModuleParentKind.topic,
        subchapterId = null,
        parentKind = 'topic',
        structureLabel = 'Topic';

  factory LearningModuleParent.fromLocation(LearningLocation location) {
    if (location.containerKind == 'section') {
      return LearningModuleParent.topic(
        subjectId: location.subjectId,
        chapterId: location.containerId!,
        subjectName: location.subjectName,
        topicId: location.parentId,
        parentTitle: location.parentTitle,
        parentNumber: location.parentNumber,
        parentOrder: location.parentOrder,
        containerTitle: location.containerTitle!,
        containerNumber: location.containerNumber!,
      );
    }
    if (location.parentKind == 'subchapter') {
      return LearningModuleParent.subchapter(
        subjectId: location.subjectId,
        chapterId: location.containerId!,
        subjectName: location.subjectName,
        subchapterId: location.parentId,
        parentTitle: location.parentTitle,
        parentNumber: location.parentNumber,
        parentOrder: location.parentOrder,
        containerTitle: location.containerTitle!,
        containerNumber: location.containerNumber!,
      );
    }
    return LearningModuleParent.chapter(
      subjectId: location.subjectId,
      chapterId: location.parentId,
      subjectName: location.subjectName,
      parentTitle: location.parentTitle,
      parentNumber: location.parentNumber,
      parentOrder: location.parentOrder,
      parentKindOverride: location.parentKind,
      structureLabelOverride: location.structureLabel,
    );
  }

  final LearningModuleParentKind kind;
  final String subjectId;
  final String chapterId;
  final String? subjectName;
  final String? subchapterId;
  final String? topicId;
  final String parentKind;
  final String structureLabel;
  final String? parentTitle;
  final String? parentNumber;
  final int parentOrder;
  final String? containerTitle;
  final String? containerNumber;

  String get parentId => switch (kind) {
        LearningModuleParentKind.chapter => chapterId,
        LearningModuleParentKind.subchapter => subchapterId!,
        LearningModuleParentKind.topic => topicId!,
      };

  String? get containerId => switch (kind) {
        LearningModuleParentKind.chapter => null,
        LearningModuleParentKind.subchapter ||
        LearningModuleParentKind.topic =>
          chapterId,
      };

  String? get containerKind => switch (kind) {
        LearningModuleParentKind.chapter => null,
        LearningModuleParentKind.subchapter => 'chapter',
        LearningModuleParentKind.topic => 'section',
      };

  LearningLocation get location {
    final structure = CurriculumStructure.forSubject(subjectId);
    return LearningLocation(
      subjectId: subjectId,
      subjectName: subjectName ?? subjectId,
      parentKind: parentKind,
      parentId: parentId,
      parentTitle: parentTitle ?? parentId,
      parentNumber: parentNumber ?? '${parentOrder == 0 ? 1 : parentOrder}',
      parentOrder: parentOrder,
      structureLabel:
          structureLabel.isEmpty ? structure.labelSingular : structureLabel,
      containerKind: containerKind,
      containerId: containerId,
      containerTitle: containerTitle,
      containerNumber: containerNumber,
    );
  }

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
  const supportedTypes = {
    'notes',
    'flashcards',
    'practice',
    'quiz',
    'review',
    'test',
  };
  final indexed = modules
      .where(
          (module) => module.isActive && supportedTypes.contains(module.type))
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
