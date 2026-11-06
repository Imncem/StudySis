class CurriculumStructure {
  const CurriculumStructure({
    required this.subjectId,
    required this.parentKind,
    required this.labelSingular,
    required this.labelPlural,
    this.containerKind,
  });

  final String subjectId;
  final String parentKind;
  final String labelSingular;
  final String labelPlural;
  final String? containerKind;

  bool get usesTopics => containerKind == 'section';
  bool get usesSubchapters => containerKind == 'chapter';

  static const _definitions = <String, CurriculumStructure>{
    'bahasa_melayu': CurriculumStructure(
      subjectId: 'bahasa_melayu',
      parentKind: 'topic',
      labelSingular: 'Section',
      labelPlural: 'Sections',
      containerKind: 'section',
    ),
    'english': CurriculumStructure(
      subjectId: 'english',
      parentKind: 'topic',
      labelSingular: 'Section',
      labelPlural: 'Sections',
      containerKind: 'section',
    ),
    'math': CurriculumStructure(
      subjectId: 'math',
      parentKind: 'chapter',
      labelSingular: 'Chapter',
      labelPlural: 'Chapters',
    ),
    'science': CurriculumStructure(
      subjectId: 'science',
      parentKind: 'chapter',
      labelSingular: 'Chapter',
      labelPlural: 'Chapters',
    ),
    'sejarah': CurriculumStructure(
      subjectId: 'sejarah',
      parentKind: 'chapter',
      labelSingular: 'Chapter',
      labelPlural: 'Chapters',
      containerKind: 'chapter',
    ),
    'geography': CurriculumStructure(
      subjectId: 'geography',
      parentKind: 'chapter',
      labelSingular: 'Chapter',
      labelPlural: 'Chapters',
    ),
    'rbt': CurriculumStructure(
      subjectId: 'rbt',
      parentKind: 'chapter',
      labelSingular: 'Chapter',
      labelPlural: 'Chapters',
    ),
    'pendidikan_islam': CurriculumStructure(
      subjectId: 'pendidikan_islam',
      parentKind: 'lesson',
      labelSingular: 'Lesson',
      labelPlural: 'Lessons',
    ),
    'pjk': CurriculumStructure(
      subjectId: 'pjk',
      parentKind: 'unit',
      labelSingular: 'Unit',
      labelPlural: 'Units',
    ),
    'seni': CurriculumStructure(
      subjectId: 'seni',
      parentKind: 'topic',
      labelSingular: 'Topic',
      labelPlural: 'Topics',
    ),
  };

  static CurriculumStructure forSubject(String subjectId) =>
      _definitions[subjectId] ??
      CurriculumStructure(
        subjectId: subjectId,
        parentKind: 'chapter',
        labelSingular: 'Chapter',
        labelPlural: 'Chapters',
      );
}
