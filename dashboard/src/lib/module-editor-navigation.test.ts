import assert from "node:assert/strict";
import test from "node:test";
import {
  initialModuleFormValues,
  moduleEditorBreadcrumb,
  moduleFormIsDirty,
} from "./module-editor-navigation.ts";
import type { LearningModule } from "./types.ts";

const geographyModule: LearningModule = {
  id: "jenis-jarak",
  title: "Jenis Jarak",
  type: "notes",
  content: "Lesson",
  summary: "Summary",
  estimatedMinutes: 10,
  difficulty: "easy",
  order: 1,
  status: "active",
  createdAt: null,
  updatedAt: null,
};

test("unchanged module values can return directly to the module list", () => {
  const initial = initialModuleFormValues(geographyModule);
  assert.equal(moduleFormIsDirty(initial, { ...initial }), false);
});

test("every editable module field participates in unsaved-change detection", () => {
  const initial = initialModuleFormValues(geographyModule);
  for (const current of [
    { ...initial, title: "Changed" },
    { ...initial, type: "quiz" as const },
    { ...initial, content: "Changed" },
    { ...initial, summary: "Changed" },
    { ...initial, estimatedMinutes: 20 },
    { ...initial, difficulty: "hard" as const },
    { ...initial, order: 2 },
    { ...initial, status: "archived" as const },
  ]) {
    assert.equal(moduleFormIsDirty(initial, current), true);
  }
});

test("new module defaults stay clean until an author changes a field", () => {
  const initial = initialModuleFormValues();
  assert.equal(moduleFormIsDirty(initial, { ...initial }), false);
  assert.equal(
    moduleFormIsDirty(initial, { ...initial, title: "New module" }),
    true,
  );
});

test("breadcrumbs preserve normal, Sejarah, BM and English parent context", () => {
  assert.equal(
    moduleEditorBreadcrumb({
      subjectName: "Geography",
      structureLabel: "Chapter",
      chapterNumber: 1,
    }),
    "CONTENT STUDIO / FORM 2 / Geography / Chapter 1",
  );
  assert.match(
    moduleEditorBreadcrumb({
      subjectName: "Sejarah",
      structureLabel: "Chapter",
      chapterNumber: 1,
      subchapterNumber: "1.1",
    }),
    /Sejarah \/ Chapter 1 \/ Subchapter 1\.1$/,
  );
  for (const subjectName of ["Bahasa Melayu", "English"]) {
    assert.match(
      moduleEditorBreadcrumb({
        subjectName,
        structureLabel: "Section",
        chapterNumber: 1,
        topicTitle: "Grammar",
      }),
      new RegExp(`${subjectName} / Section 1 / Topic Grammar$`),
    );
  }
});
