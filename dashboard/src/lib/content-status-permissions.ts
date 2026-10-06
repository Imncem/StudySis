import { moduleStatuses, type ModuleStatus } from "./types.ts";

export function contentStatusOptions(
  role: "admin" | "editor",
  existingStatus?: ModuleStatus,
): readonly ModuleStatus[] {
  void role;
  void existingStatus;
  return moduleStatuses;
}

export function canActivateContent(status: ModuleStatus): boolean {
  return status === "draft";
}
