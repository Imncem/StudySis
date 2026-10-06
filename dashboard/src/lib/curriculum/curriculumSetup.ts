import type { ChapterInput, CurriculumStructureType } from "../types.ts";
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
  structureType: CurriculumStructureType;
  items: CurriculumSetupItem[];
};

export type CurriculumSetupState =
  | "notConfigured"
  | "partiallyConfigured"
  | "configured"
  | "migrationRequired";

export type CurriculumSetupStatus = {
  state: CurriculumSetupState;
  expected: number;
  existing: number;
  skipped: number;
  missing: number;
  missingItems: CurriculumSetupItem[];
  unexpectedIds: string[];
  migration: LanguageMigrationStatus;
};

export type LanguageMigrationStatus = {
  state: "notApplicable" | "none" | "replaceable" | "blocked";
  legacyDocumentIds: string[];
  authoredLegacyDocumentIds: string[];
  legacyDocuments: LegacyCurriculumDocument[];
  authoredLegacyDocuments: LegacyCurriculumDocument[];
};

export type LegacyCurriculumDocument = {
  id: string;
  title: string;
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
    structureType: curriculum.structureType,
    items,
  };
}

export function curriculumDocumentIdFromTitle(title: string): string {
  const id = title
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLocaleLowerCase()
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "");
  if (!id) throw new Error("A deterministic curriculum document ID could not be created.");
  return id;
}

export function getCurriculumSetupStatus(
  subjectId: string,
  existingDocumentIds: Iterable<string>,
  authoredLegacyDocumentIds: Iterable<string> = [],
  legacyDocumentTitles: ReadonlyMap<string, string> = new Map(),
): CurriculumSetupStatus {
  const definition = getCurriculumSetupDefinition(subjectId);
  const existingIds = new Set(existingDocumentIds);
  const expectedIds = new Set(definition.items.map((item) => item.id));
  const missingItems = definition.items.filter((item) => !existingIds.has(item.id));
  const existing = definition.items.length - missingItems.length;
  const configuredState: CurriculumSetupState = existing === 0
    ? "notConfigured"
    : missingItems.length === 0
      ? "configured"
      : "partiallyConfigured";

  const migration = getLanguageMigrationStatus(
    subjectId,
    existingIds,
    authoredLegacyDocumentIds,
    legacyDocumentTitles,
  );
  const state = migration.state === "replaceable" || migration.state === "blocked"
    ? "migrationRequired"
    : configuredState;

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
    migration,
  };
}

export function getLanguageMigrationStatus(
  subjectId: string,
  existingDocumentIds: Iterable<string>,
  authoredLegacyDocumentIds: Iterable<string> = [],
  legacyDocumentTitles: ReadonlyMap<string, string> = new Map(),
): LanguageMigrationStatus {
  const curriculum = getForm2Curriculum(subjectId);
  if (!curriculum?.referenceItems?.length) {
    return {
      state: "notApplicable",
      legacyDocumentIds: [],
      authoredLegacyDocumentIds: [],
      legacyDocuments: [],
      authoredLegacyDocuments: [],
    };
  }

  const referenceIds = new Set(
    curriculum.referenceItems.flatMap((item) => item.id ? [item.id] : []),
  );
  const legacyDocumentIds = [...new Set(existingDocumentIds)]
    .filter((id) => referenceIds.has(id))
    .sort();
  const existingLegacyIds = new Set(legacyDocumentIds);
  const authoredIds = [...new Set(authoredLegacyDocumentIds)]
    .filter((id) => existingLegacyIds.has(id))
    .sort();
  const referenceTitles = new Map(
    curriculum.referenceItems.flatMap((item) => item.id ? [[item.id, item.title] as const] : []),
  );
  const legacyDocuments = legacyDocumentIds.map((id) => ({
    id,
    title: legacyDocumentTitles.get(id) ?? referenceTitles.get(id) ?? id,
  }));
  const authoredIdSet = new Set(authoredIds);

  return {
    state: legacyDocumentIds.length === 0
      ? "none"
      : authoredIds.length > 0
        ? "blocked"
        : "replaceable",
    legacyDocumentIds,
    authoredLegacyDocumentIds: authoredIds,
    legacyDocuments,
    authoredLegacyDocuments: legacyDocuments.filter((item) => authoredIdSet.has(item.id)),
  };
}

function curriculumItemId(
  curriculum: Form2Curriculum,
  item: Form2CurriculumItem,
): string {
  if (item.id) return item.id;
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
