import type { DashboardRole } from "../dashboard-access.ts";
import type { ChapterStatus } from "../types.ts";

export type CurriculumContainerActions = {
  canPublish: boolean;
  canManageStructure: boolean;
};

export function getCurriculumContainerActions(
  _role: DashboardRole,
  status: ChapterStatus,
): CurriculumContainerActions {
  return {
    canPublish: status !== "active",
    canManageStructure: true,
  };
}

export function markContainerActive<T extends { id: string; status: ChapterStatus }>(
  items: T[],
  id: string,
): T[] {
  return items.map((item) => item.id === id ? { ...item, status: "active" } : item);
}
