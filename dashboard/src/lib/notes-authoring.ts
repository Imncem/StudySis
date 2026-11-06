import type { LearningModule, ModuleType } from "./types.ts";

export function moduleContentLabel(type: ModuleType): string {
  return type === "notes" ? "Lesson content" : "Content";
}

export function moduleCardDestination(
  type: ModuleType,
): "details" | "structured" {
  return type === "notes" ? "details" : "structured";
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
