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

  return (
    <div className="fixed inset-0 z-50 grid place-items-center overflow-y-auto bg-[#1f2d25]/45 p-4" role="presentation">
      <section
        aria-labelledby="curriculum-setup-title"
        aria-modal="true"
        className="panel my-8 w-full max-w-2xl"
        role="dialog"
      >
        <p className="eyebrow">CURRICULUM SETUP</p>
        <h2 className="mt-2 text-2xl font-bold text-[#293930]" id="curriculum-setup-title">
          Set up {subjectName} curriculum
        </h2>
        <p className="mt-2 text-sm font-semibold text-[#668071]">
          {definition.curriculum} · Form {definition.form}
        </p>

        <div className="mt-6 grid gap-3 sm:grid-cols-3">
          <SetupMetric label={`${plural} expected`} value={status.expected} />
          <SetupMetric label="Already configured" value={status.existing} />
          <SetupMetric label="Will be created" value={status.missing} />
        </div>

        <div className="mt-6 max-h-72 overflow-y-auto rounded-2xl border border-[#e1e7e3] bg-[#f8faf8] p-4">
          <p className="mb-3 text-sm font-bold text-[#374840]">
            Missing {definition.structureLabelPlural}
          </p>
          <ol className="space-y-2 text-sm text-slate-600">
            {status.missingItems.map((item) => (
              <li className="flex gap-3" key={item.id}>
                <span className="min-w-20 font-semibold text-[#496a5a]">{item.sequenceLabel}</span>
                <span>{item.chapter.title}</span>
              </li>
            ))}
          </ol>
        </div>

        <p className="mt-5 text-sm leading-6 text-slate-600">
          All new {plural} will be saved as Draft. Existing curriculum items,
          statuses, modules, and authored content will not be overwritten.
        </p>

        <div className="mt-6 flex flex-wrap justify-end gap-3">
          <button className="secondary-button" disabled={saving} onClick={onCancel} type="button">
            Cancel
          </button>
          <button className="primary-button" disabled={saving} onClick={onConfirm} type="button">
            {saving ? "Setting up..." : "Set up curriculum"}
          </button>
        </div>
      </section>
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
