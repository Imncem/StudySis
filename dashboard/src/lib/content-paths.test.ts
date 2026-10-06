import assert from "node:assert/strict";
import test from "node:test";
import { contentPaths } from "./content-paths.ts";

test("keeps existing chapter module paths unchanged", () => {
  const location = { subjectId: "science", chapterId: "chapter_01" };
  assert.equal(
    contentPaths.modules(location),
    "curriculum/form2/subjects/science/chapters/chapter_01/modules",
  );
});

test("stores language modules and content beneath a topic", () => {
  const location = {
    subjectId: "bahasa_melayu",
    chapterId: "tatabahasa",
    topicId: "kata_nama",
  };
  assert.equal(
    contentPaths.modules(location),
    "curriculum/form2/subjects/bahasa_melayu/chapters/tatabahasa/topics/kata_nama/modules",
  );
  assert.equal(
    contentPaths.moduleContent(location, "notes", "sections"),
    "curriculum/form2/subjects/bahasa_melayu/chapters/tatabahasa/topics/kata_nama/modules/notes/sections",
  );
});

test("stores Sejarah modules and content beneath a subchapter", () => {
  const location = {
    subjectId: "sejarah",
    chapterId: "chapter_01",
    subchapterId: "subchapter_01_04",
  };
  assert.equal(
    contentPaths.modules(location),
    "curriculum/form2/subjects/sejarah/chapters/chapter_01/subchapters/subchapter_01_04/modules",
  );
  assert.equal(
    contentPaths.moduleContent(location, "notes", "sections"),
    "curriculum/form2/subjects/sejarah/chapters/chapter_01/subchapters/subchapter_01_04/modules/notes/sections",
  );
});
