export const CURRENT_CURRICULUM_ID = "form2";

export type CurriculumContentLocation = {
  subjectId: string;
  chapterId: string;
  topicId?: string;
  subchapterId?: string;
};

export const contentPaths = {
  subjects: () => `curriculum/${CURRENT_CURRICULUM_ID}/subjects`,
  subject: (subjectId: string) => `${contentPaths.subjects()}/${subjectId}`,
  chapters: (subjectId: string) =>
    `${contentPaths.subject(subjectId)}/chapters`,
  chapter: (subjectId: string, chapterId: string) =>
    `${contentPaths.chapters(subjectId)}/${chapterId}`,
  topics: (subjectId: string, chapterId: string) =>
    `${contentPaths.chapter(subjectId, chapterId)}/topics`,
  topic: (subjectId: string, chapterId: string, topicId: string) =>
    `${contentPaths.topics(subjectId, chapterId)}/${topicId}`,
  subchapters: (subjectId: string, chapterId: string) =>
    `${contentPaths.chapter(subjectId, chapterId)}/subchapters`,
  subchapter: (subjectId: string, chapterId: string, subchapterId: string) =>
    `${contentPaths.subchapters(subjectId, chapterId)}/${subchapterId}`,
  contentParent: ({
    subjectId,
    chapterId,
    topicId,
    subchapterId,
  }: CurriculumContentLocation) =>
    topicId
      ? contentPaths.topic(subjectId, chapterId, topicId)
      : subchapterId
        ? contentPaths.subchapter(subjectId, chapterId, subchapterId)
        : contentPaths.chapter(subjectId, chapterId),
  practiceQuestions: (location: CurriculumContentLocation) =>
    `${contentPaths.contentParent(location)}/practice_questions`,
  practiceQuestion: (location: CurriculumContentLocation, questionId: string) =>
    `${contentPaths.practiceQuestions(location)}/${questionId}`,
  modules: (location: CurriculumContentLocation) =>
    `${contentPaths.contentParent(location)}/modules`,
  module: (location: CurriculumContentLocation, moduleId: string) =>
    `${contentPaths.modules(location)}/${moduleId}`,
  moduleContent: (
    location: CurriculumContentLocation,
    moduleId: string,
    collectionName: string,
  ) => `${contentPaths.module(location, moduleId)}/${collectionName}`,
  moduleContentItem: (
    location: CurriculumContentLocation,
    moduleId: string,
    collectionName: string,
    itemId: string,
  ) =>
    `${contentPaths.moduleContent(location, moduleId, collectionName)}/${itemId}`,
};
