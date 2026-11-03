import assert from "node:assert/strict";
import test from "node:test";
import {
  canChangeModuleType,
  existingTypeChangeExplanation,
  hasStructuredContentEditor,
  moduleDestinationAfterSave,
  moduleInputForSave,
  modulePostSaveState,
  moduleSaveLabel,
  usesInlineLessonContent,
} from "./module-authoring.ts";
import type { ModuleFormValues } from "./module-editor-navigation.ts";
import type { ModuleType } from "./types.ts";

function values(
  type: ModuleType,
  content = "Legacy content",
): ModuleFormValues {
  return {
    title: " Module title ",
    type,
    content,
    summary: " Summary ",
    estimatedMinutes: 10,
    difficulty: "easy",
    order: 1,
    status: "draft",
  };
}

test("only Notes shows and saves canonical inline lesson content", () => {
  assert.equal(usesInlineLessonContent("notes"), true);
  for (const type of [
    "flashcards",
    "practice",
    "quiz",
    "test",
    "review",
  ] as const) {
    assert.equal(usesInlineLessonContent(type), false);
    assert.equal(moduleInputForSave(values(type), false).content, "");
  }
  assert.equal(
    moduleInputForSave(values("notes", " Lesson body "), false).content,
    "Lesson body",
  );
});

test("structured module creation uses type-specific labels and destinations", () => {
  assert.equal(moduleSaveLabel("flashcards", false), "Save & add flashcards");
  assert.equal(
    moduleSaveLabel("practice", false),
    "Save & add practice questions",
  );
  assert.equal(
    moduleSaveLabel("quiz", false),
    "Save & add quiz questions",
  );
  for (const type of ["flashcards", "practice", "quiz"] as const) {
    assert.equal(hasStructuredContentEditor(type), true);
    assert.equal(moduleDestinationAfterSave(type), "structured");
  }
  assert.equal(moduleDestinationAfterSave("notes"), "module-list");
});

test("new Quiz modules open their question editor with the first form ready", () => {
  assert.deepEqual(modulePostSaveState("quiz", "quiz-module-1", true), {
    structuredModuleId: "quiz-module-1",
    startStructuredItem: true,
  });
});

test("saved Quiz metadata opens the same editor without forcing a new question", () => {
  assert.deepEqual(modulePostSaveState("quiz", "quiz-module-1", false), {
    structuredModuleId: "quiz-module-1",
    startStructuredItem: false,
  });
});

test("Test and Review remain explicit unsupported structured schemas", () => {
  for (const type of ["test", "review"] as const) {
    assert.equal(hasStructuredContentEditor(type), false);
    assert.equal(moduleDestinationAfterSave(type), "structured");
    assert.match(moduleSaveLabel(type, false), /Save (test|review) module/);
  }
});

test("editing structured metadata preserves legacy parent content", () => {
  for (const type of ["flashcards", "practice", "quiz"] as const) {
    assert.equal(
      moduleInputForSave(values(type, " Keep this "), true).content,
      "Keep this",
    );
  }
});

test("existing module types are immutable to protect child content", () => {
  assert.equal(canChangeModuleType(false), true);
  assert.equal(canChangeModuleType(true), false);
  assert.match(
    existingTypeChangeExplanation,
    /protect existing cards and questions/i,
  );
});

test("metadata normalization preserves the existing module schema", () => {
  assert.deepEqual(moduleInputForSave(values("quiz"), false), {
    title: "Module title",
    type: "quiz",
    content: "",
    summary: "Summary",
    estimatedMinutes: 10,
    difficulty: "easy",
    order: 1,
    status: "draft",
  });
});
