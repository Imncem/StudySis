import 'learning_location.dart';
import 'learning_module.dart';
import 'chapter_progress.dart';

class LearningContinueContext {
  const LearningContinueContext({
    required this.location,
    required this.modules,
    required this.initialModuleId,
  });

  final LearningLocation location;
  final List<LearningModule> modules;
  final String initialModuleId;
}

LearningLocation? mostRecentLearningLocation({
  required List<LearningLocation> locations,
  required List<ChapterProgress> progress,
}) {
  final ordered = prioritizeLearningLocations(
    locations: locations,
    progress: progress,
  );
  return ordered.isEmpty ? null : ordered.first;
}

List<LearningLocation> prioritizeLearningLocations({
  required List<LearningLocation> locations,
  required List<ChapterProgress> progress,
}) {
  if (locations.isEmpty) return const [];
  final progressByIdentity = {
    for (final item in progress) item.identityKey: item,
  };
  final indexed = locations.indexed.toList();
  indexed.sort((left, right) {
    final leftProgress = progressByIdentity[left.$2.identityKey];
    final rightProgress = progressByIdentity[right.$2.identityKey];
    final leftDate = leftProgress?.lastActivityAt;
    final rightDate = rightProgress?.lastActivityAt;
    if (leftDate != null && rightDate != null) {
      final recent = rightDate.compareTo(leftDate);
      if (recent != 0) return recent;
    } else if (leftDate != null) {
      return -1;
    } else if (rightDate != null) {
      return 1;
    }
    return left.$1.compareTo(right.$1);
  });
  return indexed.map((entry) => entry.$2).toList(growable: false);
}

LearningModule? nextIncompleteLearningModule({
  required List<LearningModule> modules,
  required ChapterProgress? progress,
}) {
  for (final module in modules) {
    final complete = switch (module.type) {
      'notes' => progress?.learnCompleted ?? false,
      'flashcards' => progress?.flashcardsCompleted ?? false,
      'practice' => progress?.practiceCompleted ?? false,
      'quiz' || 'test' => progress?.quizCompleted ?? false,
      _ => false,
    };
    if (!complete) return module;
  }
  return modules.isEmpty ? null : modules.first;
}
