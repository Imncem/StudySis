import { moduleDifficulties, moduleStatuses, type ModuleDifficulty, type ModuleStatus, type QuizQuestion, type QuizQuestionInput } from "../../lib/types.ts";

export const answerLetters = ["A", "B", "C", "D"] as const;

export type QuizValidationErrors = Partial<Record<"question" | "optionA" | "optionB" | "optionC" | "optionD" | "correctOptionIndex" | "explanation" | "order" | "difficulty" | "status" | "form", string>>;

export type QuizFormValues = {
  question: string;
  options: string[];
  correctOptionIndex: number | null;
  explanation: string;
  difficulty: ModuleDifficulty;
  order: string;
  status: ModuleStatus;
};

export function validateQuizQuestionForm(values: QuizFormValues): { errors: QuizValidationErrors; input?: QuizQuestionInput } {
  const errors: QuizValidationErrors = {};
  const options = values.options.map((option) => option.trim());
  const order = Number(values.order);
  const correctOptionIndex = isAnswerIndex(values.correctOptionIndex) ? values.correctOptionIndex : 0;
  if (!values.question.trim()) errors.question = "Enter the question.";
  if (!options[0]) errors.optionA = "Enter Option A.";
  if (!options[1]) errors.optionB = "Enter Option B.";
  if (!options[2]) errors.optionC = "Enter Option C.";
  if (!options[3]) errors.optionD = "Enter Option D.";
  if (!isAnswerIndex(values.correctOptionIndex)) errors.correctOptionIndex = "Select the correct answer.";
  if (!values.explanation.trim()) errors.explanation = "Enter an explanation.";
  if (!Number.isFinite(order) || order < 0) errors.order = "Enter a valid order number.";
  if (!moduleDifficulties.includes(values.difficulty)) errors.difficulty = "Choose Easy, Medium, or Hard.";
  if (!moduleStatuses.includes(values.status)) errors.status = "Choose Draft, Active, or Archived.";
  if (Object.keys(errors).length) return { errors };
  return { errors, input: { question: values.question.trim(), options, correctOptionIndex, explanation: values.explanation.trim(), difficulty: values.difficulty, order, status: values.status } };
}

export function isAnswerIndex(value: number | null | undefined): value is number {
  return typeof value === "number" && Number.isInteger(value) && value >= 0 && value <= 3;
}

export function normalizeQuizOptions(item?: Pick<QuizQuestion, "options">) {
  const options = item?.options?.slice(0, 4) ?? [];
  while (options.length < 4) options.push("");
  return options as [string, string, string, string];
}

export function answerLabel(index: number) {
  return answerLetters[index] ?? "A";
}

export function quizQuestionMetadata(item: Pick<QuizQuestion, "options" | "correctOptionIndex">) {
  return `${item.options.length} choices · Correct ${answerLabel(item.correctOptionIndex)}`;
}
