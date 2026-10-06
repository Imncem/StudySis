import assert from "node:assert/strict";
import test from "node:test";

import {
  getCurriculumContainerActions,
  markContainerActive,
} from "./containerActivation.ts";

test("trusted editors receive full curriculum-container controls", () => {
  assert.deepEqual(getCurriculumContainerActions("editor", "draft"), {
    canPublish: true,
    canManageStructure: true,
  });
  assert.equal(getCurriculumContainerActions("editor", "active").canPublish, false);
  assert.equal(getCurriculumContainerActions("editor", "archived").canPublish, true);
});

test("admins retain curriculum management and full publication controls", () => {
  assert.deepEqual(getCurriculumContainerActions("admin", "draft"), {
    canPublish: true,
    canManageStructure: true,
  });
  assert.equal(getCurriculumContainerActions("admin", "archived").canPublish, true);
});

test("successful activation immediately updates the displayed container", () => {
  const containers = [
    { id: "tatabahasa", status: "draft" as const, title: "Tatabahasa" },
    { id: "penulisan", status: "draft" as const, title: "Penulisan" },
  ];

  assert.deepEqual(markContainerActive(containers, "tatabahasa"), [
    { id: "tatabahasa", status: "active", title: "Tatabahasa" },
    { id: "penulisan", status: "draft", title: "Penulisan" },
  ]);
});
