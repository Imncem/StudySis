import { moduleStatuses, type ModuleStatus } from "./types.ts";

const editorDraftStatuses = ["draft"] as const;
const editorExistingDraftStatuses = ["draft", "active"] as const;
const editorActiveStatuses = ["active"] as const;
const editorArchivedStatuses = ["archived"] as const;

export function contentStatusOptions(
  role: "admin" | "editor",
  existingStatus?: ModuleStatus,
): readonly ModuleStatus[] {
  if (role === "admin") return moduleStatuses;
  if (existingStatus === "draft") return editorExistingDraftStatuses;
  if (existingStatus === "active") return editorActiveStatuses;
  if (existingStatus === "archived") return editorArchivedStatuses;
  return editorDraftStatuses;
}

export function canActivateContent(status: ModuleStatus): boolean {
  return status === "draft";
}
