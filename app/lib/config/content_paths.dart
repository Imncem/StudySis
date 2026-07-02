class ContentPaths {
  static const currentCurriculumId = 'form2';
  static const mathematicsSubjectId = 'math';

  static String get subjects => 'curriculum/$currentCurriculumId/subjects';

  static String subject(String subjectId) => '$subjects/$subjectId';

  static String chapters(String subjectId) => '${subject(subjectId)}/chapters';

  static String modules(String subjectId, String chapterId) =>
      '${chapters(subjectId)}/$chapterId/modules';
}
