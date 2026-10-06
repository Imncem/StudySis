import assert from "node:assert/strict";
import test from "node:test";

import {
  canActivateContent,
  contentStatusOptions,
} from "./content-status-permissions.ts";

test("editors receive the complete trusted-collaborator status model", () => {
  assert.deepEqual(contentStatusOptions("editor", "draft"), [
    "draft",
    "active",
    "archived",
  ]);
  assert.equal(canActivateContent("draft"), true);
});

test("editors can create and revise any valid content status", () => {
  assert.deepEqual(contentStatusOptions("editor"), ["draft", "active", "archived"]);
  assert.deepEqual(contentStatusOptions("editor", "active"), ["draft", "active", "archived"]);
  assert.deepEqual(contentStatusOptions("editor", "archived"), ["draft", "active", "archived"]);
  assert.equal(canActivateContent("active"), false);
});

test("admins retain the complete status model", () => {
  assert.deepEqual(contentStatusOptions("admin", "active"), [
    "draft",
    "active",
    "archived",
  ]);
});
