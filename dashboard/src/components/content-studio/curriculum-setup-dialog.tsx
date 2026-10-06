"use client";

import type {
  CurriculumSetupDefinition,
  CurriculumSetupStatus,
} from "@/lib/curriculum/curriculumSetup";

export function CurriculumSetupDialog({
  definition,
  status,
  subjectName,
  saving,
  onCancel,
  onConfirm,
}: {
  definition: CurriculumSetupDefinition;
  status: CurriculumSetupStatus;
  subjectName: string;
  saving: boolean;
  onCancel: () => void;
  onConfirm: () => Promise<void>;
}) {
  const plural = definition.structureLabelPlural.toLowerCase();
  const replacingLegacy = status.migration.state === "replaceable";

  return (
    <div
      className="fixed inset-0 z-50 grid place-items-center overflow-y-auto bg-[#1f2d25]/45 p-4"
      role="presentation"
    >
      <section
        aria-labelledby="curriculum-setup-title"
        aria-modal="true"
        className="panel my-8 w-full max-w-2xl"
        role="dialog"
      >
        <p className="eyebrow">CURRICULUM SETUP</p>
        <h2
          className="mt-2 text-2xl font-bold text-[#293930]"
          id="curriculum-setup-title"
        >
          {replacingLegacy ? "Replace legacy structure" : `Set up ${subjectName} curriculum`}
        </h2>
        <p className="mt-2 text-sm font-semibold text-[#668071]">
          {definition.curriculum} / Form {definition.form}
        </p>

        {replacingLegacy && (
          <div className="mt-6 grid gap-4 sm:grid-cols-2">
            <StructureSummary
              compact
              items={status.migration.legacyDocuments.map((item) => item.title)}
              label="Current structure"
              title={`${status.migration.legacyDocuments.length} legacy Units`}
            />
            <StructureSummary
              items={definition.items.map((item) => item.chapter.title)}
              label="New structure"
              title={`${definition.items.length} ${definition.structureLabelPlural}`}
            />
          </div>
        )}

        {replacingLegacy && (
          <div className="mt-5 rounded-2xl border border-amber-200 bg-amber-50 p-4 text-sm leading-6 text-amber-900">
            The safety check found no modules, structured module content,
            practice questions, or Topics beneath these legacy documents.
          </div>
        )}

        <div className="mt-6 grid gap-3 sm:grid-cols-3">
          <SetupMetric label={`${plural} expected`} value={status.expected} />
          <SetupMetric label="Already configured" value={status.existing} />
          <SetupMetric label="Will be created" value={status.missing} />
        </div>

        {!replacingLegacy && status.missingItems.length > 0 && (
          <div className="mt-6">
            <StructureSummary
              items={status.missingItems.map((item) => item.chapter.title)}
              label={`Missing ${definition.structureLabelPlural}`}
              title={`${status.missingItems.length} remaining`}
            />
          </div>
        )}

        <p className="mt-5 text-sm leading-6 text-slate-600">
          All new {plural} will be saved as Draft. Existing expected curriculum
          items, statuses, modules, and authored content will not be overwritten.
        </p>

        <div className="mt-6 flex flex-wrap justify-end gap-3">
          <button className="secondary-button" disabled={saving} onClick={onCancel} type="button">
            Cancel
          </button>
          <button className="primary-button" disabled={saving} onClick={onConfirm} type="button">
            {saving
              ? "Setting up..."
              : replacingLegacy
                ? "Replace legacy structure"
                : "Set up curriculum"}
          </button>
        </div>
      </section>
    </div>
  );
}

function StructureSummary({
  label,
  title,
  items,
  compact = false,
}: {
  label: string;
  title: string;
  items: string[];
  compact?: boolean;
}) {
  const visibleItems = compact ? items.slice(0, 3) : items;
  return (
    <div className="rounded-2xl border border-[#e1e7e3] bg-[#f8faf8] p-4">
      <p className="text-xs font-bold uppercase tracking-wide text-[#668071]">{label}</p>
      <p className="mt-1 font-bold text-[#293930]">{title}</p>
      <ul className="mt-3 space-y-1 text-sm text-slate-600">
        {visibleItems.map((item) => <li key={item}>{item}</li>)}
        {compact && items.length > visibleItems.length && (
          <li>and {items.length - visibleItems.length} more</li>
        )}
      </ul>
    </div>
  );
}

function SetupMetric({ label, value }: { label: string; value: number }) {
  return (
    <div className="rounded-2xl bg-[#f0f5f1] p-4">
      <p className="text-2xl font-bold text-[#293930]">{value}</p>
      <p className="mt-1 text-xs font-semibold text-[#668071]">{label}</p>
    </div>
  );
}
