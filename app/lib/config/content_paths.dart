class ContentPaths {
  static const currentCurriculumId = 'form2';
  static const mathematicsSubjectId = 'math';

  static String get subjects => 'curriculum/$currentCurriculumId/subjects';

  static String subject(String subjectId) => '$subjects/$subjectId';

  static String chapters(String subjectId) => '${subject(subjectId)}/chapters';

  static String modules(String subjectId, String chapterId) =>
      '${chapters(subjectId)}/$chapterId/modules';

  static String topics(String subjectId, String sectionId) =>
      '${chapters(subjectId)}/$sectionId/topics';

  static String topicModules(
          String subjectId, String sectionId, String topicId) =>
      '${topics(subjectId, sectionId)}/$topicId/modules';

  static String topicPracticeQuestions(
          String subjectId, String sectionId, String topicId) =>
      '${topics(subjectId, sectionId)}/$topicId/practice_questions';

  static String topicModule(String subjectId, String sectionId, String topicId,
          String moduleId) =>
      '${topicModules(subjectId, sectionId, topicId)}/$moduleId';

  static String topicModuleContent(String subjectId, String sectionId,
          String topicId, String moduleId, String collectionName) =>
      '${topicModule(subjectId, sectionId, topicId, moduleId)}/$collectionName';

  static String subchapters(String subjectId, String chapterId) =>
      '${chapters(subjectId)}/$chapterId/subchapters';

  static String subchapterModules(
          String subjectId, String chapterId, String subchapterId) =>
      '${subchapters(subjectId, chapterId)}/$subchapterId/modules';

  static String subchapterPracticeQuestions(
          String subjectId, String chapterId, String subchapterId) =>
      '${subchapters(subjectId, chapterId)}/$subchapterId/practice_questions';

  static String subchapterModule(String subjectId, String chapterId,
          String subchapterId, String moduleId) =>
      '${subchapterModules(subjectId, chapterId, subchapterId)}/$moduleId';

  static String subchapterModuleContent(String subjectId, String chapterId,
          String subchapterId, String moduleId, String collectionName) =>
      '${subchapterModule(subjectId, chapterId, subchapterId, moduleId)}/$collectionName';

  static String module(String subjectId, String chapterId, String moduleId) =>
      '${modules(subjectId, chapterId)}/$moduleId';

  static String moduleContent(String subjectId, String chapterId,
          String moduleId, String collectionName) =>
      '${module(subjectId, chapterId, moduleId)}/$collectionName';

  static String noteSections(
          String subjectId, String chapterId, String moduleId) =>
      '${module(subjectId, chapterId, moduleId)}/sections';

  static String flashcardCards(String subjectId, String chapterId) =>
      '${module(subjectId, chapterId, 'flashcards')}/cards';

  static String practiceQuestions(String subjectId, String chapterId) =>
      '${chapters(subjectId)}/$chapterId/practice_questions';

  static String quizQuestions(String subjectId, String chapterId) =>
      '${module(subjectId, chapterId, 'quiz')}/questions';
}
