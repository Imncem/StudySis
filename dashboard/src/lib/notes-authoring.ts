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
  return module.content.trim().length > 0
    ? "Lesson content ready"
    : "Open to add lesson content";
}
