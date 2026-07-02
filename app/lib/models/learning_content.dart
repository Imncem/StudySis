import 'chapter.dart';
import 'learning_module.dart';

class LearningContent {
  const LearningContent({
    required this.subjectName,
    required this.chapter,
    required this.module,
  });

  final String subjectName;
  final Chapter chapter;
  final LearningModule module;
}
