export const CURRENT_CURRICULUM_ID = "form2";
export const EDITABLE_SUBJECT_ID = "math";

export const contentPaths = {
  subjects: () => `curriculum/${CURRENT_CURRICULUM_ID}/subjects`,
  subject: (subjectId: string) =>
    `${contentPaths.subjects()}/${subjectId}`,
  chapters: (subjectId: string) =>
    `${contentPaths.subject(subjectId)}/chapters`,
  chapter: (subjectId: string, chapterId: string) =>
    `${contentPaths.chapters(subjectId)}/${chapterId}`,
  practiceQuestions: (subjectId: string, chapterId: string) =>
    `${contentPaths.chapter(subjectId, chapterId)}/practice_questions`,
  practiceQuestion: (
    subjectId: string,
    chapterId: string,
    questionId: string,
  ) =>
    `${contentPaths.practiceQuestions(subjectId, chapterId)}/${questionId}`,
  modules: (subjectId: string, chapterId: string) =>
    `${contentPaths.chapter(subjectId, chapterId)}/modules`,
  module: (subjectId: string, chapterId: string, moduleId: string) =>
    `${contentPaths.modules(subjectId, chapterId)}/${moduleId}`,
  moduleContent: (
    subjectId: string,
    chapterId: string,
    moduleId: string,
    collectionName: string,
  ) =>
    `${contentPaths.module(subjectId, chapterId, moduleId)}/${collectionName}`,
  moduleContentItem: (
    subjectId: string,
    chapterId: string,
    moduleId: string,
    collectionName: string,
    itemId: string,
  ) =>
    `${contentPaths.moduleContent(subjectId, chapterId, moduleId, collectionName)}/${itemId}`,
};
