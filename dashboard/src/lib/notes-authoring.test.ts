import assert from "node:assert/strict";
import test from "node:test";
import {
  noteSectionInputForSave,
  notesContentPresentation,
  moduleCompletionLabel,
  moduleContentLabel,
  withoutNoteSection,
} from "./notes-authoring.ts";
import type { LearningModule, ModuleType, NoteSection } from "./types.ts";

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

test("Notes retain inline lesson content and open the structured workspace", () => {
  assert.equal(moduleContentLabel("notes"), "Lesson content");
  assert.equal(
    moduleCompletionLabel(module("notes", "A complete lesson.")),
    "Lesson content ready",
  );
  assert.equal(
    moduleCompletionLabel(module("notes", "  ")),
    "Open to add lesson content",
  );
  assert.equal(
    moduleCompletionLabel(module("notes", "-")),
    "Open to add lesson content",
  );
});

const geographySections: NoteSection[] = [
  "Jenis Jarak",
  "Jenis-Jenis skala",
  "Maksud Skala dan Jarak",
  "Penukaran Unit Jarak",
].map((heading, index) => ({
  id: `section-${index + 1}`,
  heading,
  body: `Body ${index + 1}`,
  example: `Example ${index + 1}`,
  order: index + 1,
  createdAt: null,
  updatedAt: null,
}));

test("dash placeholder exposes all four existing structured Notes sections", () => {
  const presentation = notesContentPresentation(
    module("notes", "-"),
    geographySections,
  );

  assert.equal(presentation.inlineContent, null);
  assert.deepEqual(
    presentation.structuredSections.map((section) => section.heading),
    geographySections.map((section) => section.heading),
  );
});

test("inline Notes and structured sections remain visible without merging", () => {
  const presentation = notesContentPresentation(
    module("notes", "Canonical lesson"),
    geographySections,
  );

  assert.equal(presentation.inlineContent, "Canonical lesson");
  assert.equal(presentation.structuredSections.length, 4);
});

test("editing section metadata preserves its body and example", () => {
  const section = geographySections[0];
  assert.deepEqual(
    noteSectionInputForSave({ ...section, heading: "Updated heading" }),
    {
      heading: "Updated heading",
      body: section.body,
      example: section.example,
      order: section.order,
    },
  );
});

test("deleting one structured section leaves every sibling intact", () => {
  const remaining = withoutNoteSection(geographySections, "section-2");
  assert.deepEqual(
    remaining.map((section) => section.id),
    ["section-1", "section-3", "section-4"],
  );
});
