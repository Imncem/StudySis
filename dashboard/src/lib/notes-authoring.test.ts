import assert from "node:assert/strict";
import test from "node:test";
import {
  moduleCardDestination,
  moduleCompletionLabel,
  moduleContentLabel,
} from "./notes-authoring.ts";
import type { LearningModule, ModuleType } from "./types.ts";

function module(type: ModuleType, content = ""): LearningModule {
  return {
    id: type,
    title: type,
    type,
    content,
    summary: "Summary",
    estimatedMinutes: 10,
    difficulty: "easy",
    order: 1,
    status: "active",
    createdAt: null,
    updatedAt: null,
  };
}

test("Notes use the canonical lesson-content field and details editor", () => {
  assert.equal(moduleContentLabel("notes"), "Lesson content");
  assert.equal(moduleCardDestination("notes"), "details");
  assert.equal(
    moduleCompletionLabel(module("notes", "A complete lesson.")),
    "Lesson content ready",
  );
  assert.equal(
    moduleCompletionLabel(module("notes", "  ")),
    "Open to add lesson content",
  );
});

test("structured module types retain their existing authoring flow", () => {
  for (const type of ["flashcards", "practice", "quiz"] as const) {
    assert.equal(moduleCardDestination(type), "structured");
  }
});
