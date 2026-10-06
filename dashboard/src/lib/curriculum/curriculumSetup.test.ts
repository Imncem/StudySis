import assert from "node:assert/strict";
import test from "node:test";
import { form2Curriculum } from "./form2Curriculum.ts";
import {
  getCurriculumSetupDefinition,
  getCurriculumSetupStatus,
  curriculumDocumentIdFromTitle,
} from "./curriculumSetup.ts";

const expectedCounts: Record<string, number> = {
  bahasa_melayu: 3,
  english: 3,
  math: 13,
  science: 13,
  sejarah: 10,
  geography: 11,
  rbt: 2,
  pendidikan_islam: 28,
  pjk: 11,
  seni: 11,
};

test("builds unique deterministic setup IDs for all ten subjects", () => {
  assert.equal(form2Curriculum.length, 10);
  for (const curriculum of form2Curriculum) {
    const definition = getCurriculumSetupDefinition(
      curriculum.firestoreSubjectId,
    );
    assert.equal(definition.items.length, expectedCounts[curriculum.firestoreSubjectId]);
    assert.equal(
      new Set(definition.items.map((item) => item.id)).size,
      definition.items.length,
    );
    assert.equal(definition.structureLabelPlural, curriculum.structureLabelPlural);
  }
});

test("preserves Mathematics IDs and uses stable language section IDs", () => {
  assert.deepEqual(
    getCurriculumSetupDefinition("math").items.map((item) => item.id),
    Array.from({ length: 13 }, (_, index) =>
      `chapter-${(index + 1).toString().padStart(2, "0")}`,
    ),
  );
  assert.deepEqual(getCurriculumSetupDefinition("bahasa_melayu").items.map((item) => item.id), ["pemahaman", "tatabahasa", "penulisan"]);
  assert.deepEqual(getCurriculumSetupDefinition("english").items.map((item) => item.id), ["grammar", "literature", "essay_writing"]);
});

test("uses the approved structure prefix for every remaining subject", () => {
  const expectedRanges: Record<string, [string, number]> = {
    science: ["chapter", 13],
    sejarah: ["chapter", 10],
    geography: ["chapter", 11],
    rbt: ["chapter", 2],
    pendidikan_islam: ["lesson", 28],
    seni: ["topic", 11],
  };

  for (const [subjectId, [prefix, count]] of Object.entries(expectedRanges)) {
    assert.deepEqual(
      getCurriculumSetupDefinition(subjectId).items.map((item) => item.id),
      Array.from({ length: count }, (_, index) =>
        `${prefix}_${(index + 1).toString().padStart(2, "0")}`,
      ),
    );
  }
});

test("uses section-specific PJK IDs without collisions", () => {
  const pjk = getCurriculumSetupDefinition("pjk").items;
  assert.deepEqual(pjk.map((item) => item.id), [
    "pj_unit_01", "pj_unit_02", "pj_unit_03", "pj_unit_04",
    "pj_unit_05", "pj_unit_06", "pj_unit_07", "pj_unit_08",
    "pk_unit_01", "pk_unit_02", "pk_unit_03",
  ]);
  assert.deepEqual(
    pjk.map((item) => item.chapter.chapterNumber),
    [1, 2, 3, 4, 5, 6, 7, 8, 1, 2, 3],
  );
});

test("maps grouping metadata and starts every generated item as draft", () => {
  for (const subjectId of [
    "pendidikan_islam",
    "pjk",
  ]) {
    const definition = getCurriculumSetupDefinition(subjectId);
    assert.ok(definition.items.every((item) => item.chapter.group));
    assert.ok(definition.items.every((item) => item.chapter.status === "draft"));
  }
  assert.ok(
    getCurriculumSetupDefinition("science").items.every(
      (item) => item.chapter.group === undefined,
    ),
  );
});

test("classifies empty legacy language units as replaceable", () => {
  const status = getCurriculumSetupStatus("english", ["unit_06", "unit_07"]);
  assert.equal(status.state, "migrationRequired");
  assert.equal(status.migration.state, "replaceable");
  assert.deepEqual(status.migration.legacyDocumentIds, ["unit_06", "unit_07"]);
  assert.deepEqual(status.migration.authoredLegacyDocumentIds, []);
});

test("blocks language replacement when a legacy unit has authored content", () => {
  const status = getCurriculumSetupStatus(
    "bahasa_melayu",
    ["unit_01", "unit_02"],
    ["unit_02"],
  );
  assert.equal(status.migration.state, "blocked");
  assert.equal(status.state, "migrationRequired");
  assert.deepEqual(status.migration.authoredLegacyDocumentIds, ["unit_02"]);
});

test("reports persisted legacy titles for blocked manual migration", () => {
  const status = getCurriculumSetupStatus(
    "english",
    ["unit_06"],
    ["unit_06"],
    new Map([["unit_06", "Edited Money title"]]),
  );

  assert.deepEqual(status.migration.authoredLegacyDocuments, [
    { id: "unit_06", title: "Edited Money title" },
  ]);
});

test("creates stable section IDs without auto-ID", () => {
  assert.equal(curriculumDocumentIdFromTitle("Essay Writing"), "essay_writing");
  assert.equal(curriculumDocumentIdFromTitle("Tatabahasa"), "tatabahasa");
});

test("classifies empty, partial and complete setup without scheduling existing IDs", () => {
  const definition = getCurriculumSetupDefinition("science");
  const empty = getCurriculumSetupStatus("science", []);
  assert.equal(empty.state, "notConfigured");
  assert.equal(empty.missing, 13);

  const existingIds = definition.items.slice(0, 12).map((item) => item.id);
  const partial = getCurriculumSetupStatus("science", [
    ...existingIds,
    "teacher_extension",
  ]);
  assert.equal(partial.state, "partiallyConfigured");
  assert.equal(partial.existing, 12);
  assert.deepEqual(partial.missingItems.map((item) => item.id), ["chapter_13"]);
  assert.deepEqual(partial.unexpectedIds, ["teacher_extension"]);

  const complete = getCurriculumSetupStatus(
    "science",
    definition.items.map((item) => item.id),
  );
  assert.equal(complete.state, "configured");
  assert.equal(complete.missing, 0);
  assert.equal(complete.skipped, 13);
});

test("idempotency planning preserves edited active items and their nested content", () => {
  const existing = new Map([
    ["chapter_01", {
      title: "Teacher-edited title",
      status: "active",
      modules: {notes: {sections: ["section-1"]}},
    }],
  ]);
  const before = structuredClone([...existing.entries()]);
  const status = getCurriculumSetupStatus("science", existing.keys());

  assert.ok(!status.missingItems.some((item) => item.id === "chapter_01"));
  assert.deepEqual([...existing.entries()], before);
});

test("unknown subject IDs fail safely", () => {
  assert.throws(
    () => getCurriculumSetupDefinition("unknown"),
    /Unknown Form 2 subject ID/,
  );
});
