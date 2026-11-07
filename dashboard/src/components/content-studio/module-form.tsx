"use client";

import { FormEvent, useMemo, useState } from "react";
import {
  initialModuleFormValues,
  summaryForSave,
  moduleFormIsDirty,
} from "@/lib/module-editor-navigation";
import { moduleContentLabel } from "@/lib/notes-authoring";
import {
  canChangeModuleType,
  existingTypeChangeExplanation,
  moduleInputForSave,
  moduleSaveLabel,
  usesInlineLessonContent,
} from "@/lib/module-authoring";
import {
  moduleDifficulties,
  moduleTypes,
  type LearningModule,
  type LearningModuleInput,
  type ModuleDifficulty,
  type ModuleStatus,
  type ModuleType,
} from "@/lib/types";

export function ModuleForm({
  module,
  statusOptions,
  contextLabel,
  onSave,
  onCancel,
}: {
  module?: LearningModule;
  statusOptions: readonly ModuleStatus[];
  contextLabel: string;
  onSave: (input: LearningModuleInput) => Promise<void>;
  onCancel: () => void;
}) {
  const initialValues = useMemo(() => initialModuleFormValues(module), [module]);
  const [title, setTitle] = useState(initialValues.title);
  const [type, setType] = useState<ModuleType>(initialValues.type);
  const [content, setContent] = useState(initialValues.content);
  const [summary, setSummary] = useState(initialValues.summary);
  const [summaryTouched, setSummaryTouched] = useState(false);
  const [estimatedMinutes, setEstimatedMinutes] = useState(
    initialValues.estimatedMinutes,
  );
  const [difficulty, setDifficulty] = useState<ModuleDifficulty>(
    initialValues.difficulty,
  );
  const [status, setStatus] = useState<ModuleStatus>(initialValues.status);
  const [order, setOrder] = useState(initialValues.order);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const [confirmingExit, setConfirmingExit] = useState(false);

  const isDirty = moduleFormIsDirty(initialValues, {
    title,
    type,
    content,
    summary,
    estimatedMinutes,
    difficulty,
    order,
    status,
  });

  function requestExit() {
    if (saving) return;
    if (isDirty) {
      setConfirmingExit(true);
      return;
    }
    onCancel();
  }

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setSaving(true);
    setError("");
    try {
      await onSave(moduleInputForSave({
        title,
        type,
        content,
        summary: summaryForSave({
          storedSummary: module?.summary,
          displayedSummary: summary,
          touched: summaryTouched,
        }),
        estimatedMinutes,
        difficulty,
        order,
        status,
      }, Boolean(module)));
    } catch (nextError) {
      setError(
        nextError instanceof Error
          ? nextError.message
          : "The module could not be saved.",
      );
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="space-y-4">
      <button
        className="text-sm font-semibold text-[#496a5a] hover:underline"
        onClick={requestExit}
        type="button"
      >
        &larr; {module ? "Back to content workspace" : "Back to module list"}
      </button>
      <form className="editor-card space-y-5" onSubmit={submit}>
        <div>
          <p className="eyebrow">{contextLabel}</p>
          <h2 className="mt-1 text-xl font-bold text-[#293930]">
            {module ? "Edit module" : "Add module"}
          </h2>
        </div>
        <label className="field-label">
          Title
          <input
            className="field mt-2"
            onChange={(event) => setTitle(event.target.value)}
            required
            value={title}
          />
        </label>
        <div className="grid gap-4 sm:grid-cols-2">
          <label className="field-label">
            Module type
            <select
              className="field mt-2"
              disabled={!canChangeModuleType(Boolean(module))}
              onChange={(event) => setType(event.target.value as ModuleType)}
              value={type}
            >
              {moduleTypes.map((value) => (
                <option key={value} value={value}>
                  {titleCase(value)}
                </option>
              ))}
            </select>
            {module && (
              <span className="mt-2 block text-xs font-medium text-slate-500">
                {existingTypeChangeExplanation}
              </span>
            )}
          </label>
          <label className="field-label">
            Difficulty
            <select
              className="field mt-2"
              onChange={(event) =>
                setDifficulty(event.target.value as ModuleDifficulty)
              }
              value={difficulty}
            >
              {moduleDifficulties.map((value) => (
                <option key={value} value={value}>
                  {titleCase(value)}
                </option>
              ))}
            </select>
          </label>
        </div>
        {usesInlineLessonContent(type) && (
          <label className="field-label">
            {moduleContentLabel(type)}
            <textarea
              className="field mt-2 min-h-64 resize-y leading-7"
              onChange={(event) => setContent(event.target.value)}
              required
              value={content}
            />
          </label>
        )}
        <label className="field-label">
          Summary (optional)
          <textarea
            className="field mt-2 min-h-28 resize-y"
            onChange={(event) => {
              setSummaryTouched(true);
              setSummary(event.target.value);
            }}
            value={summary}
          />
        </label>
        <div className="grid gap-4 sm:grid-cols-3">
          <label className="field-label">
            Estimated minutes
            <input
              className="field mt-2"
              min="1"
              onChange={(event) =>
                setEstimatedMinutes(Number(event.target.value))
              }
              required
              type="number"
              value={estimatedMinutes}
            />
          </label>
          <label className="field-label">
            Order
            <input
              className="field mt-2"
              min="0"
              onChange={(event) => setOrder(Number(event.target.value))}
              required
              type="number"
              value={order}
            />
          </label>
          {statusOptions.length > 1 ? (
            <label className="field-label">
              Status
              <select
                className="field mt-2"
                onChange={(event) =>
                  setStatus(event.target.value as ModuleStatus)
                }
                value={status}
              >
                {statusOptions.map((value) => (
                  <option key={value} value={value}>
                    {titleCase(value)}
                  </option>
                ))}
              </select>
            </label>
          ) : (
            <div className="field-label">
              Status
              <p className="field mt-2">
                {titleCase(statusOptions[0] ?? "draft")}
              </p>
            </div>
          )}
        </div>
        {error && <p className="error-banner">{error}</p>}
        <div className="flex flex-wrap gap-3">
          <button className="primary-button" disabled={saving} type="submit">
            {saving ? "Saving..." : moduleSaveLabel(type, Boolean(module))}
          </button>
          <button
            className="secondary-button"
            onClick={requestExit}
            type="button"
          >
            Cancel
          </button>
        </div>
      </form>
      {confirmingExit && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/30 p-5">
          <div
            aria-labelledby="unsaved-module-title"
            aria-modal="true"
            className="w-full max-w-md rounded-2xl bg-white p-6 shadow-xl"
            role="dialog"
          >
            <h2
              className="text-lg font-bold text-[#293930]"
              id="unsaved-module-title"
            >
              You have unsaved changes. Leave without saving?
            </h2>
            <div className="mt-6 flex justify-end gap-3">
              <button
                className="secondary-button"
                onClick={() => setConfirmingExit(false)}
                type="button"
              >
                Stay
              </button>
              <button className="primary-button" onClick={onCancel} type="button">
                Leave
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function titleCase(value: string) {
  return value.charAt(0).toUpperCase() + value.slice(1);
}
