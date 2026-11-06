import 'chapter.dart';
import 'learning_module.dart';
import 'note_section.dart';

class LearningContent {
  const LearningContent({
    this.subjectId = 'math',
    required this.subjectName,
    required this.chapter,
    required this.module,
    required this.noteSections,
  });

  final String subjectId;
  final String subjectName;
  final Chapter chapter;
  final LearningModule module;
  final List<NoteSection> noteSections;

  bool get hasModuleLessonContent => isMeaningfulLessonContent(module.content);
  bool get hasLegacyNoteSections => noteSections.isNotEmpty;
  bool get hasLessonContent => hasModuleLessonContent || hasLegacyNoteSections;
}

bool isMeaningfulLessonContent(String value) {
  final normalized = value.trim();
  return normalized.isNotEmpty &&
      normalized != '-' &&
      normalized != '–' &&
      normalized != '—';
}
