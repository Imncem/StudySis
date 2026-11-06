import assert from "node:assert/strict";
import test from "node:test";
import { findModuleOrderConflict } from "./module-ordering.ts";

const modules = [
  { id: "notes", title: "Notes", order: 1 },
  { id: "flashcards", title: "Flashcards", order: 2 },
];

test("detects duplicate module order under the same parent", () => {
  assert.deepEqual(findModuleOrderConflict(modules, 1), modules[0]);
});

test("allows an existing module to retain its own order", () => {
  assert.equal(findModuleOrderConflict(modules, 1, "notes"), null);
});

test("allows an unused module order", () => {
  assert.equal(findModuleOrderConflict(modules, 3), null);
});
