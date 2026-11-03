import type {
  LearningModuleInput,
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
  return type === "flashcards" || type === "practice" || type === "quiz";
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
      return "Save test module";
    case "review":
      return "Save review module";
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

export const existingTypeChangeExplanation =
  "Module type is fixed after creation to protect existing cards and questions. Create a new module to use a different type.";
