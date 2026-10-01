import 'chapter.dart';
import 'learning_module.dart';
import 'note_section.dart';

class LearningContent {
  const LearningContent({
    required this.subjectName,
    required this.chapter,
    required this.module,
    required this.noteSections,
  });

  final String subjectName;
  final Chapter chapter;
  final LearningModule module;
  final List<NoteSection> noteSections;
}
