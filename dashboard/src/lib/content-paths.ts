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
  modules: (subjectId: string, chapterId: string) =>
    `${contentPaths.chapter(subjectId, chapterId)}/modules`,
  module: (subjectId: string, chapterId: string, moduleId: string) =>
    `${contentPaths.modules(subjectId, chapterId)}/${moduleId}`,
};
