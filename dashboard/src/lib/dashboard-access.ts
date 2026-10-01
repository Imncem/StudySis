export const dashboardSubjectIds = [
  "bahasa_melayu",
  "english",
  "math",
  "science",
  "sejarah",
  "geography",
  "rbt",
  "pendidikan_islam",
  "pjk",
  "seni",
] as const;

export type DashboardSubjectId = (typeof dashboardSubjectIds)[number];
export type DashboardRole = "admin" | "editor";

export type DashboardAccess = {
  role: DashboardRole;
  active: boolean;
  displayName?: string;
  email?: string;
  subjectIds?: DashboardSubjectId[];
};

export type DashboardAccessResult =
  | { status: "active"; access: DashboardAccess }
  | { status: "inactive" | "invalid" | "missing" };

const subjectIdSet = new Set<string>(dashboardSubjectIds);

export function parseDashboardAccess(
  data: Record<string, unknown> | undefined,
): DashboardAccessResult {
  if (!data) return { status: "missing" };
  if (data.role !== "admin" && data.role !== "editor") {
    return { status: "invalid" };
  }
  if (
    typeof data.active !== "boolean" ||
    (data.subjectIds !== undefined && !Array.isArray(data.subjectIds))
  ) {
    return { status: "invalid" };
  }
  const subjectIds = data.subjectIds ?? [];
  if (
    !subjectIds.every(
      (subjectId) => typeof subjectId === "string" && subjectIdSet.has(subjectId),
    ) ||
    new Set(subjectIds).size !== subjectIds.length ||
    (data.displayName !== undefined && typeof data.displayName !== "string") ||
    (data.email !== undefined && typeof data.email !== "string")
  ) {
    return { status: "invalid" };
  }

  const access: DashboardAccess = {
    role: data.role,
    active: data.active,
    ...(data.subjectIds !== undefined
      ? { subjectIds: subjectIds as DashboardSubjectId[] }
      : {}),
    ...(typeof data.displayName === "string"
      ? { displayName: data.displayName }
      : {}),
    ...(typeof data.email === "string" ? { email: data.email } : {}),
  };
  return access.active ? { status: "active", access } : { status: "inactive" };
}

export function canEditSubject(access: DashboardAccess, subjectId: string): boolean {
  return (
    access.active &&
    (access.role === "admin" || access.role === "editor") &&
    subjectIdSet.has(subjectId)
  );
}

export function filterAccessibleSubjects<T extends { id: string }>(
  subjects: readonly T[],
  access: DashboardAccess,
): T[] {
  return subjects.filter((subject) => canEditSubject(access, subject.id));
}
