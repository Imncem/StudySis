import type { Timestamp } from "firebase/firestore";

export type Student = {
  name?: string;
  displayName?: string;
  fullName?: string;
  preferredLanguage: string;
  dailyTargetMinutes: number;
  status: string;
};

export type Subject = {
  id: string;
  displayName: string;
  shortName: string;
  contentStatus: string;
  iconName: string;
  themeColor: string;
  order: number;
};

export const chapterStatuses = ["draft", "active", "archived"] as const;
export type ChapterStatus = (typeof chapterStatuses)[number];

export type Chapter = {
  id: string;
  chapterNumber: number;
  title: string;
  textbookChapterTitle: string;
  learningObjectives: string[];
  estimatedMinutes: number;
  status: ChapterStatus;
  order: number;
  createdAt: Timestamp | null;
  updatedAt: Timestamp | null;
};

export type ChapterInput = Omit<Chapter, "id" | "createdAt" | "updatedAt">;

export const moduleTypes = [
  "notes",
  "flashcards",
  "practice",
  "quiz",
  "test",
  "review",
] as const;
export type ModuleType = (typeof moduleTypes)[number];

export const moduleDifficulties = ["easy", "medium", "hard"] as const;
export type ModuleDifficulty = (typeof moduleDifficulties)[number];

export const moduleStatuses = ["draft", "active", "archived"] as const;
export type ModuleStatus = (typeof moduleStatuses)[number];

export type LearningModule = {
  id: string;
  title: string;
  type: ModuleType;
  content: string;
  summary: string;
  estimatedMinutes: number;
  difficulty: ModuleDifficulty;
  order: number;
  status: ModuleStatus;
  createdAt: Timestamp | null;
  updatedAt: Timestamp | null;
};

export type LearningModuleInput = Omit<
  LearningModule,
  "id" | "createdAt" | "updatedAt"
>;

export type NoteSection = {
  id: string;
  heading: string;
  body: string;
  example: string;
  order: number;
  createdAt: Timestamp | null;
  updatedAt: Timestamp | null;
};
export type NoteSectionInput = Omit<
  NoteSection,
  "id" | "createdAt" | "updatedAt"
>;

export type Flashcard = {
  id: string;
  front: string;
  back: string;
  hint: string;
  order: number;
  status: ModuleStatus;
  createdAt: Timestamp | null;
  updatedAt: Timestamp | null;
};
export type FlashcardInput = Omit<
  Flashcard,
  "id" | "createdAt" | "updatedAt"
>;

export type PracticeItem = {
  id: string;
  question: string;
  answer: string;
  explanation: string;
  difficulty: ModuleDifficulty;
  order: number;
  status: ModuleStatus;
  createdAt: Timestamp | null;
  updatedAt: Timestamp | null;
};
export type PracticeItemInput = Omit<
  PracticeItem,
  "id" | "createdAt" | "updatedAt"
>;

export type QuizQuestion = {
  id: string;
  question: string;
  options: string[];
  correctOptionIndex: number;
  explanation: string;
  difficulty: ModuleDifficulty;
  order: number;
  status: ModuleStatus;
  createdAt: Timestamp | null;
  updatedAt: Timestamp | null;
};
export type QuizQuestionInput = Omit<
  QuizQuestion,
  "id" | "createdAt" | "updatedAt"
>;
