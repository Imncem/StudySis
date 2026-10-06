import type {
  CurriculumSetupDefinition,
  CurriculumSetupStatus,
} from "./curriculumSetup.ts";

export type CurriculumPresentation = {
  heading: string;
  addLabel: string;
  showAddAction: boolean;
  migrationActionLabel: string | null;
};

export function getCurriculumPresentation(
  definition: CurriculumSetupDefinition,
  status: CurriculumSetupStatus,
): CurriculumPresentation {
  const migrationRequired = status.state === "migrationRequired";
  const heading = migrationRequired
    ? "Curriculum update required"
    : status.state === "configured"
      ? "Curriculum configured"
      : status.state === "notConfigured"
        ? "Curriculum not configured"
        : `${status.existing} of ${status.expected} ${definition.structureLabelPlural.toLowerCase()} configured`;

  return {
    heading,
    addLabel: `Add ${definition.structureLabelSingular}`,
    showAddAction: !migrationRequired,
    migrationActionLabel: status.migration.state === "replaceable"
      ? "Replace legacy structure"
      : null,
  };
}
