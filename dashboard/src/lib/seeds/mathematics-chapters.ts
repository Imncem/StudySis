import type { ModuleType } from "@/lib/types";

export const mathematicsChapterSeed = [
  "Patterns and Sequences",
  "Factorisation and Algebraic Fractions",
  "Algebraic Formulae",
  "Polygons",
  "Circles",
  "Three-Dimensional Geometrical Shapes",
  "Coordinates",
  "Graphs of Functions",
  "Speed and Acceleration",
  "Gradient of a Straight Line",
  "Transformations",
  "Measures of Central Tendencies",
  "Simple Probability",
] as const;

export const draftModuleSeed: ReadonlyArray<{
  title: string;
  type: ModuleType;
}> = [
  { title: "Notes", type: "notes" },
  { title: "Flashcards", type: "flashcards" },
  { title: "Practice", type: "practice" },
  { title: "Quiz", type: "quiz" },
  { title: "Test", type: "test" },
  { title: "Review", type: "review" },
];
