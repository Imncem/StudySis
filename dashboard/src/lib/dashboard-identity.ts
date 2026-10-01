import type { DashboardAccess, DashboardRole } from "./dashboard-access";

export type DashboardIdentity = {
  displayName: string;
  email: string;
  initials: string;
  roleLabel: "Admin" | "Editor";
};

export function buildDashboardIdentity(
  access: DashboardAccess,
  authEmail?: string | null,
): DashboardIdentity {
  const email = firstNonEmpty(access.email, authEmail) ?? "Email unavailable";
  const emailPrefix = email === "Email unavailable"
    ? undefined
    : email.split("@", 1)[0]?.trim();
  const displayName = firstNonEmpty(access.displayName, emailPrefix) ?? "User";

  return {
    displayName,
    email,
    initials: initialsFrom(access.displayName) ?? initialsFrom(emailPrefix) ?? "U",
    roleLabel: roleLabel(access.role),
  };
}

function firstNonEmpty(...values: Array<string | null | undefined>): string | undefined {
  for (const value of values) {
    const normalized = value?.trim();
    if (normalized) return normalized;
  }
  return undefined;
}

function initialsFrom(value?: string): string | undefined {
  const words = value
    ?.trim()
    .split(/[^\p{L}\p{N}]+/u)
    .filter(Boolean);
  if (!words?.length) return undefined;
  const initials = words.length === 1
    ? words[0].slice(0, 1)
    : `${words[0].slice(0, 1)}${words.at(-1)?.slice(0, 1) ?? ""}`;
  return initials.toLocaleUpperCase();
}

function roleLabel(role: DashboardRole): "Admin" | "Editor" {
  return role === "admin" ? "Admin" : "Editor";
}
