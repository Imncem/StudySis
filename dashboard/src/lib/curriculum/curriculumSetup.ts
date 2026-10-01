import type { ChapterInput } from "../types.ts";
import {
  getForm2Curriculum,
  type Form2Curriculum,
  type Form2CurriculumItem,
} from "./form2Curriculum.ts";

export type CurriculumSetupItem = {
  id: string;
  sequenceLabel: string;
  chapter: Omit<ChapterInput, "createdAt" | "updatedAt">;
};

export type CurriculumSetupDefinition = {
  subjectId: string;
  curriculum: string;
  form: number;
  structureLabelSingular: string;
  structureLabelPlural: string;
  items: CurriculumSetupItem[];
};

export type CurriculumSetupState =
  | "notConfigured"
  | "partiallyConfigured"
  | "configured";

export type CurriculumSetupStatus = {
  state: CurriculumSetupState;
  expected: number;
  existing: number;
  skipped: number;
  missing: number;
  missingItems: CurriculumSetupItem[];
  unexpectedIds: string[];
};

export type CurriculumSetupResult = {
  expected: number;
  existing: number;
  created: number;
  skipped: number;
  createdIds: string[];
};

export function getCurriculumSetupDefinition(
  subjectId: string,
): CurriculumSetupDefinition {
  const curriculum = getForm2Curriculum(subjectId);
  if (!curriculum) {
    throw new Error(`Unknown Form 2 subject ID: ${subjectId}`);
  }

  const items = curriculum.items.map((item) => ({
    id: curriculumItemId(curriculum, item),
    sequenceLabel: item.sequenceLabel,
    chapter: {
      chapterNumber: sequenceNumber(item),
      title: item.title,
      textbookChapterTitle: item.title,
      learningObjectives: item.learningObjectives ?? [],
      estimatedMinutes: 30,
      status: "draft" as const,
      order: item.order,
      ...(item.group ? { group: item.group } : {}),
    },
  }));

  if (new Set(items.map((item) => item.id)).size !== items.length) {
    throw new Error(`Curriculum setup IDs collide for ${subjectId}.`);
  }

  return {
    subjectId,
    curriculum: curriculum.curriculum,
    form: curriculum.form,
    structureLabelSingular: curriculum.structureLabelSingular,
    structureLabelPlural: curriculum.structureLabelPlural,
    items,
  };
}

export function getCurriculumSetupStatus(
  subjectId: string,
  existingDocumentIds: Iterable<string>,
): CurriculumSetupStatus {
  const definition = getCurriculumSetupDefinition(subjectId);
  const existingIds = new Set(existingDocumentIds);
  const expectedIds = new Set(definition.items.map((item) => item.id));
  const missingItems = definition.items.filter((item) => !existingIds.has(item.id));
  const existing = definition.items.length - missingItems.length;
  const state = existing === 0
    ? "notConfigured"
    : missingItems.length === 0
      ? "configured"
      : "partiallyConfigured";

  return {
    state,
    expected: definition.items.length,
    existing,
    skipped: existing,
    missing: missingItems.length,
    missingItems,
    unexpectedIds: [...existingIds]
      .filter((id) => !expectedIds.has(id))
      .sort(),
  };
}

function curriculumItemId(
  curriculum: Form2Curriculum,
  item: Form2CurriculumItem,
): string {
  const number = sequenceNumber(item).toString().padStart(2, "0");

  if (curriculum.firestoreSubjectId === "math") {
    return `chapter-${item.order.toString().padStart(2, "0")}`;
  }
  if (curriculum.firestoreSubjectId === "pjk") {
    return `${item.group === "Pendidikan Jasmani" ? "pj" : "pk"}_unit_${number}`;
  }
  return `${curriculum.structureType}_${number}`;
}

function sequenceNumber(item: Form2CurriculumItem): number {
  const match = item.sequenceLabel.match(/(\d+)$/);
  if (!match) {
    throw new Error(`Curriculum item has no numeric sequence: ${item.sequenceLabel}`);
  }
  return Number(match[1]);
}
