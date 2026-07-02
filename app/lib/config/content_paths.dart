class ContentPaths {
  static const currentCurriculumId = 'form2';
  static const mathematicsSubjectId = 'math';

  static String get subjects => 'curriculum/$currentCurriculumId/subjects';

  static String subject(String subjectId) => '$subjects/$subjectId';

  static String chapters(String subjectId) => '${subject(subjectId)}/chapters';

  static String modules(String subjectId, String chapterId) =>
      '${chapters(subjectId)}/$chapterId/modules';

  static String module(String subjectId, String chapterId, String moduleId) =>
      '${modules(subjectId, chapterId)}/$moduleId';

  static String noteSections(
          String subjectId, String chapterId, String moduleId) =>
      '${module(subjectId, chapterId, moduleId)}/sections';

  static String flashcardCards(String subjectId, String chapterId) =>
      '${module(subjectId, chapterId, 'flashcards')}/cards';
}
