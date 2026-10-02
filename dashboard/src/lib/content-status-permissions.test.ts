import assert from "node:assert/strict";
import test from "node:test";

import {
  canActivateContent,
  contentStatusOptions,
} from "./content-status-permissions.ts";

test("editors may keep a draft or activate existing draft content", () => {
  assert.deepEqual(contentStatusOptions("editor", "draft"), ["draft", "active"]);
  assert.equal(canActivateContent("draft"), true);
});

test("editors cannot create active content or withdraw active content", () => {
  assert.deepEqual(contentStatusOptions("editor"), ["draft"]);
  assert.deepEqual(contentStatusOptions("editor", "active"), ["active"]);
  assert.deepEqual(contentStatusOptions("editor", "archived"), ["archived"]);
  assert.equal(canActivateContent("active"), false);
});

test("admins retain the complete status model", () => {
  assert.deepEqual(contentStatusOptions("admin", "active"), [
    "draft",
    "active",
    "archived",
  ]);
});
