import assert from "node:assert/strict";
import test from "node:test";
import { mapChapterDocument } from "./chapter-mapper.ts";
import type { ChapterInput, CurriculumItem } from "../types.ts";

const legacyChapter: ChapterInput = {
  chapterNumber: 1,
  title: "Pola dan Jujukan",
  textbookChapterTitle: "Pola dan Jujukan",
  learningObjectives: ["Recognise patterns"],
  estimatedMinutes: 15,
  status: "active",
  order: 1,
};

test("parses existing chapter documents without group unchanged", () => {
  assert.deepEqual(mapChapterDocument("chapter-01", legacyChapter), {
    id: "chapter-01",
    ...legacyChapter,
    createdAt: null,
    updatedAt: null,
  });
});

test("reads optional group using the same metadata as curriculum items", () => {
  const item: CurriculumItem = {
    order: 1,
    sequenceLabel: "Unit 1",
    title: "Anda Sihat Anda Ceria",
    group: "Tema 1: Kesihatan dan Kebersihan",
    status: "draft",
  };
  const input: ChapterInput = { ...legacyChapter, group: item.group };
  assert.equal(mapChapterDocument("unit-01", input).group, item.group);
});

test("ignores null and malformed groups without discarding chapter fields", () => {
  for (const group of [null, 1, [], {}, false]) {
    const chapter = mapChapterDocument("chapter-01", { ...legacyChapter, group });
    assert.equal(Object.hasOwn(chapter, "group"), false);
    assert.equal(chapter.title, legacyChapter.title);
  }
});
