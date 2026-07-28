import assert from "node:assert/strict";
import test from "node:test";
import type { QuizQuestion } from "../../lib/types.ts";
import { normalizeQuizOptions, quizQuestionMetadata, validateQuizQuestionForm } from "./quiz-editor-utils.ts";

const validValues = {
  question: "What is 2 + 2?",
  options: ["3", "4", "5", "6"],
  correctOptionIndex: 1,
  explanation: "2 + 2 equals 4.",
  difficulty: "easy" as const,
  order: "0",
  status: "active" as const,
};

test("creates a quiz question with four separate options and converts answer B to index 1", () => {
  const result = validateQuizQuestionForm(validValues);
  assert.deepEqual(result.errors, {});
  assert.deepEqual(result.input?.options, ["3", "4", "5", "6"]);
  assert.equal(result.input?.correctOptionIndex, 1);
});

test("loads existing options into separate A-D inputs and leaves missing choices empty", () => {
  assert.deepEqual(normalizeQuizOptions({ options: ["Alpha", "Beta"] }), ["Alpha", "Beta", "", ""]);
});

test("edits an existing question without changing the Firestore field names", () => {
  const existing: QuizQuestion = {
    id: "question-1",
    question: "Original?",
    options: ["A1", "B1", "C1", "D1"],
    correctOptionIndex: 3,
    explanation: "Original explanation.",
    difficulty: "medium",
    order: 2,
    status: "draft",
    createdAt: null,
    updatedAt: null,
  };
  const result = validateQuizQuestionForm({
    question: existing.question,
    options: normalizeQuizOptions(existing),
    correctOptionIndex: existing.correctOptionIndex,
    explanation: existing.explanation,
    difficulty: existing.difficulty,
    order: String(existing.order),
    status: existing.status,
  });
  assert.equal(result.input?.correctOptionIndex, 3);
  assert.ok("correctOptionIndex" in (result.input ?? {}));
});

test("validates missing options, correct answer, explanation, and invalid order", () => {
  const result = validateQuizQuestionForm({ ...validValues, options: ["", "B", "", "D"], correctOptionIndex: null, explanation: "", order: "-1" });
  assert.equal(result.errors.optionA, "Enter Option A.");
  assert.equal(result.errors.optionC, "Enter Option C.");
  assert.equal(result.errors.correctOptionIndex, "Select the correct answer.");
  assert.equal(result.errors.explanation, "Enter an explanation.");
  assert.equal(result.errors.order, "Enter a valid order number.");
  assert.equal(result.input, undefined);
});

test("builds question-list card metadata with answer letters", () => {
  assert.equal(quizQuestionMetadata({ options: ["A", "B", "C", "D"], correctOptionIndex: 1 }), "4 choices · Correct B");
});
