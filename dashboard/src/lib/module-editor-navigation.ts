import type {
  LearningModule,
  ModuleDifficulty,
  ModuleStatus,
  ModuleType,
} from "./types.ts";

export type ModuleFormValues = {
  title: string;
  type: ModuleType;
  content: string;
  summary: string;
  estimatedMinutes: number;
  difficulty: ModuleDifficulty;
  order: number;
  status: ModuleStatus;
};

export function initialModuleFormValues(
  module?: LearningModule,
): ModuleFormValues {
  return {
    title: module?.title ?? "",
    type: module?.type ?? "notes",
    content: module?.content ?? "",
    summary: module?.summary ?? "",
    estimatedMinutes: module?.estimatedMinutes ?? 10,
    difficulty: module?.difficulty ?? "medium",
    order: module?.order ?? 1,
    status: module?.status ?? "draft",
  };
}

export function moduleFormIsDirty(
  initial: ModuleFormValues,
  current: ModuleFormValues,
): boolean {
  return (Object.keys(initial) as Array<keyof ModuleFormValues>).some(
    (key) => initial[key] !== current[key],
  );
}

export function moduleEditorBreadcrumb({
  subjectName,
  structureLabel,
  chapterNumber,
  topicTitle,
  subchapterNumber,
}: {
  subjectName: string;
  structureLabel: string;
  chapterNumber: number;
  topicTitle?: string;
  subchapterNumber?: string;
}): string {
  return [
    "CONTENT STUDIO",
    "FORM 2",
    subjectName,
    `${structureLabel} ${chapterNumber}`,
    subchapterNumber ? `Subchapter ${subchapterNumber}` : undefined,
    topicTitle ? `Topic ${topicTitle}` : undefined,
  ]
    .filter(Boolean)
    .join(" / ");
}
