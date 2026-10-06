import assert from "node:assert/strict";
import test from "node:test";

import {
  getCurriculumSetupDefinition,
  getCurriculumSetupStatus,
} from "./curriculumSetup.ts";
import { getCurriculumPresentation } from "./curriculumPresentation.ts";

test("legacy Bahasa Melayu units require migration and retain Section terminology", () => {
  const definition = getCurriculumSetupDefinition("bahasa_melayu");
  const status = getCurriculumSetupStatus(
    "bahasa_melayu",
    Array.from({ length: 36 }, (_, index) => `unit_${String(index + 1).padStart(2, "0")}`),
  );
  const presentation = getCurriculumPresentation(definition, status);

  assert.equal(status.state, "migrationRequired");
  assert.equal(status.migration.legacyDocuments.length, 36);
  assert.equal(presentation.heading, "Curriculum update required");
  assert.equal(definition.structureLabelPlural, "Sections");
  assert.equal(presentation.addLabel, "Add Section");
  assert.equal(presentation.showAddAction, false);
  assert.equal(presentation.migrationActionLabel, "Replace legacy structure");
});

test("legacy English units use the same mismatch treatment", () => {
  const definition = getCurriculumSetupDefinition("english");
  const status = getCurriculumSetupStatus(
    "english",
    ["unit_06", "unit_07", "unit_08", "unit_09"],
  );
  const presentation = getCurriculumPresentation(definition, status);

  assert.equal(status.state, "migrationRequired");
  assert.equal(status.migration.legacyDocuments.length, 4);
  assert.equal(presentation.addLabel, "Add Section");
  assert.equal(presentation.showAddAction, false);
});

test("configured Sections and normal subjects keep their expected presentation", () => {
  const bahasaDefinition = getCurriculumSetupDefinition("bahasa_melayu");
  const bahasaStatus = getCurriculumSetupStatus(
    "bahasa_melayu",
    bahasaDefinition.items.map((item) => item.id),
  );
  const bahasaPresentation = getCurriculumPresentation(bahasaDefinition, bahasaStatus);
  assert.equal(bahasaStatus.state, "configured");
  assert.equal(bahasaStatus.existing, 3);
  assert.equal(bahasaPresentation.heading, "Curriculum configured");
  assert.equal(bahasaPresentation.showAddAction, true);

  const scienceDefinition = getCurriculumSetupDefinition("science");
  const scienceStatus = getCurriculumSetupStatus(
    "science",
    scienceDefinition.items.map((item) => item.id),
  );
  const sciencePresentation = getCurriculumPresentation(scienceDefinition, scienceStatus);
  assert.equal(sciencePresentation.heading, "Curriculum configured");
  assert.equal(sciencePresentation.addLabel, "Add Chapter");
  assert.equal(sciencePresentation.showAddAction, true);
});
