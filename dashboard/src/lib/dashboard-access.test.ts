import assert from "node:assert/strict";
import test from "node:test";
import {
  canEditSubject,
  dashboardSubjectIds,
  filterAccessibleSubjects,
  parseDashboardAccess,
} from "./dashboard-access.ts";

test("active admin can edit every verified subject", () => {
  const result = parseDashboardAccess({ role: "admin", active: true, subjectIds: [] });
  assert.equal(result.status, "active");
  if (result.status !== "active") return;
  assert.ok(dashboardSubjectIds.every((id) => canEditSubject(result.access, id)));
  assert.equal(canEditSubject(result.access, "invented_subject"), false);
});

test("active editor sees and edits every verified subject regardless of legacy assignments", () => {
  const result = parseDashboardAccess({
    role: "editor",
    active: true,
    subjectIds: ["science", "rbt"],
  });
  assert.equal(result.status, "active");
  if (result.status !== "active") return;
  assert.ok(dashboardSubjectIds.every((id) => canEditSubject(result.access, id)));
  assert.equal(canEditSubject(result.access, "invented_subject"), false);
  assert.deepEqual(
    filterAccessibleSubjects(
      [{ id: "math" }, { id: "science" }, { id: "rbt" }],
      result.access,
    ),
    [{ id: "math" }, { id: "science" }, { id: "rbt" }],
  );
});

for (const accessData of [
  { role: "editor", active: true, subjectIds: [] },
  { role: "editor", active: true },
]) {
  test(`active editor with ${"subjectIds" in accessData ? "empty" : "missing"} legacy assignments sees all subjects`, () => {
    const result = parseDashboardAccess(accessData);
    assert.equal(result.status, "active");
    if (result.status !== "active") return;
    assert.deepEqual(
      result.access.subjectIds,
      "subjectIds" in accessData ? [] : undefined,
    );
    assert.ok(dashboardSubjectIds.every((id) => canEditSubject(result.access, id)));
  });
}

test("missing, inactive and malformed access records fail closed", () => {
  assert.equal(parseDashboardAccess(undefined).status, "missing");
  assert.equal(
    parseDashboardAccess({ role: "editor", active: false, subjectIds: ["math"] }).status,
    "inactive",
  );
  for (const data of [
    { role: "owner", active: true, subjectIds: [] },
    { role: "editor", active: "yes", subjectIds: [] },
    { role: "editor", active: true, subjectIds: "math" },
    { role: "editor", active: true, subjectIds: ["unknown"] },
    { role: "editor", active: true, subjectIds: ["math", "math"] },
    { role: "editor", active: true, subjectIds: [], email: 42 },
  ]) {
    assert.equal(parseDashboardAccess(data).status, "invalid");
  }
});
