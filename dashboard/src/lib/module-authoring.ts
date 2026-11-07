import type {
  LearningModule,
  LearningModuleInput,
  LearningModulePatch,
  ModuleType,
} from "./types.ts";
import type { ModuleFormValues } from "./module-editor-navigation.ts";

export type ModuleAuthoringDestination = "module-list" | "structured";

export type ModulePostSaveState = {
  structuredModuleId: string | null;
  startStructuredItem: boolean;
};

export function usesInlineLessonContent(type: ModuleType): boolean {
  return type === "notes";
}

export function hasStructuredContentEditor(type: ModuleType): boolean {
  return type !== "notes";
}

export function structuredContentCountLabel(
  type: ModuleType,
  count: number,
): string {
  const labels: Record<ModuleType, [string, string]> = {
    notes: ["section", "sections"],
    flashcards: ["card", "cards"],
    practice: ["question", "questions"],
    quiz: ["question", "questions"],
    test: ["question", "questions"],
    review: ["item", "items"],
  };
  const [singular, plural] = labels[type];
  return `${count} ${count === 1 ? singular : plural}`;
}

export function canChangeModuleType(existing: boolean): boolean {
  return !existing;
}

export function moduleSaveLabel(
  type: ModuleType,
  existing: boolean,
): string {
  if (existing) {
    if (type === "notes") return "Save notes module";
    if (hasStructuredContentEditor(type)) return "Save & open content editor";
    return "Save module";
  }
  switch (type) {
    case "notes":
      return "Save notes module";
    case "flashcards":
      return "Save & add flashcards";
    case "practice":
      return "Save & add practice questions";
    case "quiz":
      return "Save & add quiz questions";
    case "test":
      return "Save & add test questions";
    case "review":
      return "Save & add review items";
  }
}

export function moduleDestinationAfterSave(
  type: ModuleType,
): ModuleAuthoringDestination {
  return type === "notes" ? "module-list" : "structured";
}

export function modulePostSaveState(
  type: ModuleType,
  moduleId: string,
  isNew: boolean,
): ModulePostSaveState {
  if (moduleDestinationAfterSave(type) !== "structured") {
    return { structuredModuleId: null, startStructuredItem: false };
  }
  return {
    structuredModuleId: moduleId,
    startStructuredItem: isNew && hasStructuredContentEditor(type),
  };
}

export function moduleInputForSave(
  values: ModuleFormValues,
  existing: boolean,
): LearningModuleInput {
  return {
    ...values,
    title: values.title.trim(),
    content:
      usesInlineLessonContent(values.type) || existing
        ? values.content.trim()
        : "",
    summary: values.summary.trim(),
  };
}

const editableModuleFields = [
  "title",
  "type",
  "content",
  "summary",
  "estimatedMinutes",
  "difficulty",
  "order",
  "status",
] as const satisfies readonly (keyof LearningModuleInput)[];

export function modulePatchForUpdate(
  input: LearningModuleInput,
  original: LearningModule,
): LearningModulePatch {
  const normalizedOriginal = moduleInputForSave(
    {
      title: original.title,
      type: original.type,
      content: original.content,
      summary: original.summary,
      estimatedMinutes: original.estimatedMinutes,
      difficulty: original.difficulty,
      order: original.order,
      status: original.status,
    },
    true,
  );
  const patch: LearningModulePatch = {};
  for (const field of editableModuleFields) {
    if (input[field] !== normalizedOriginal[field]) {
      Object.assign(patch, { [field]: input[field] });
    }
  }
  return patch;
}

export const existingTypeChangeExplanation =
  "Module type is fixed after creation to protect existing cards and questions. Create a new module to use a different type.";
