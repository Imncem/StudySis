import assert from "node:assert/strict";
import test from "node:test";
import {
  belongsToPracticeModule,
  filterPracticeItemsForModule,
} from "./practice-ownership.ts";

test("questions from two Practice modules cannot mix", () => {
  const questions = [
    { id: "a-1", moduleId: "practice-a" },
    { id: "b-1", moduleId: "practice-b" },
    { id: "a-2", moduleId: "practice-a" },
  ];
  const moduleIds = ["practice-a", "practice-b"];

  assert.deepEqual(
    filterPracticeItemsForModule(questions, "practice-a", moduleIds).map(
      (item) => item.id,
    ),
    ["a-1", "a-2"],
  );
  assert.deepEqual(
    filterPracticeItemsForModule(questions, "practice-b", moduleIds).map(
      (item) => item.id,
    ),
    ["b-1"],
  );
});

test("legacy unassigned questions remain compatible with one Practice module", () => {
  assert.equal(
    belongsToPracticeModule({}, "practice-a", ["practice-a"]),
    true,
  );
});

test("legacy unassigned questions are not duplicated across multiple modules", () => {
  assert.equal(
    belongsToPracticeModule(
      {},
      "practice-a",
      ["practice-a", "practice-b"],
    ),
    false,
  );
  assert.equal(
    belongsToPracticeModule(
      {},
      "practice-b",
      ["practice-a", "practice-b"],
    ),
    false,
  );
});
