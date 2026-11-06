import type {
  LearningModule,
  ModuleType,
  NoteSection,
  NoteSectionInput,
} from "./types.ts";

export function moduleContentLabel(type: ModuleType): string {
  return type === "notes" ? "Lesson content" : "Content";
}

export function moduleCompletionLabel(module: LearningModule): string {
  if (module.type !== "notes") return "";
  return hasMeaningfulLessonContent(module.content)
    ? "Lesson content ready"
    : "Open to add lesson content";
}

export function hasMeaningfulLessonContent(content: string): boolean {
  const normalized = content.trim();
  return (
    normalized.length > 0 &&
    normalized !== "-" &&
    normalized !== "–" &&
    normalized !== "—"
  );
}

export function notesContentPresentation(
  module: LearningModule,
  sections: readonly NoteSection[],
) {
  return {
    inlineContent: hasMeaningfulLessonContent(module.content)
      ? module.content
      : null,
    structuredSections: [...sections],
  };
}

export function noteSectionInputForSave(values: {
  heading: string;
  body: string;
  example: string;
  order: number;
}): NoteSectionInput {
  return {
    heading: values.heading.trim(),
    body: values.body.trim(),
    example: values.example.trim(),
    order: values.order,
  };
}

export function withoutNoteSection(
  sections: readonly NoteSection[],
  deletedId: string,
): NoteSection[] {
  return sections.filter((section) => section.id !== deletedId);
}
