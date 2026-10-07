import assert from "node:assert/strict";
import test from "node:test";
import { getCurriculumContainerActions } from "./containerActivation.ts";
import { resolveSejarahWorkspace } from "./sejarahWorkspace.ts";
import type { Subchapter } from "../types.ts";

const subchapters: Subchapter[] = [
  {
    id: "subchapter_01_01",
    number: "1.1",
    title: "Konsep Alam Melayu",
    order: 1,
    status: "active",
  },
  {
    id: "subchapter_01_04",
    number: "1.4",
    title: "Kerajaan Alam Melayu dan Kerajaan Luar yang Sezaman",
    order: 4,
    status: "draft",
  },
];

test("Sejarah chapter view does not open a module workspace implicitly", () => {
  assert.deepEqual(resolveSejarahWorkspace("sejarah", null, subchapters), {
    view: "chapter",
    subchapter: null,
  });
});

test("selecting a Sejarah subchapter opens its dedicated workspace", () => {
  const workspace = resolveSejarahWorkspace(
    "sejarah",
    "subchapter_01_04",
    subchapters,
  );

  assert.equal(workspace.view, "subchapter");
  assert.equal(workspace.subchapter?.number, "1.4");
  assert.equal(
    workspace.subchapter?.title,
    "Kerajaan Alam Melayu dan Kerajaan Luar yang Sezaman",
  );
});

test("back or a removed selection returns to the chapter list", () => {
  assert.equal(
    resolveSejarahWorkspace("sejarah", null, subchapters).view,
    "chapter",
  );
  assert.equal(
    resolveSejarahWorkspace(
      "sejarah",
      "subchapter_missing",
      subchapters,
    ).view,
    "chapter",
  );
});

test("the workspace policy applies only to Sejarah", () => {
  assert.equal(
    resolveSejarahWorkspace("science", "subchapter_01_04", subchapters).view,
    "chapter",
  );
});

test("Editors and Admins retain Subchapter management actions", () => {
  for (const role of ["editor", "admin"] as const) {
    const draftActions = getCurriculumContainerActions(role, "draft");
    const activeActions = getCurriculumContainerActions(role, "active");
    assert.equal(draftActions.canManageStructure, true);
    assert.equal(draftActions.canPublish, true);
    assert.equal(activeActions.canManageStructure, true);
  }
});
