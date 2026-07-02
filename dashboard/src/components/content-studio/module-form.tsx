"use client";

import { FormEvent, useState } from "react";
import { moduleDifficulties, moduleStatuses, moduleTypes, type LearningModule, type LearningModuleInput, type ModuleDifficulty, type ModuleStatus, type ModuleType } from "@/lib/types";

export function ModuleForm({ module, onSave, onCancel }: { module?: LearningModule; onSave: (input: LearningModuleInput) => Promise<void>; onCancel: () => void }) {
  const [title, setTitle] = useState(module?.title ?? "");
  const [type, setType] = useState<ModuleType>(module?.type ?? "notes");
  const [content, setContent] = useState(module?.content ?? "");
  const [summary, setSummary] = useState(module?.summary ?? "");
  const [estimatedMinutes, setEstimatedMinutes] = useState(module?.estimatedMinutes ?? 10);
  const [difficulty, setDifficulty] = useState<ModuleDifficulty>(module?.difficulty ?? "medium");
  const [status, setStatus] = useState<ModuleStatus>(module?.status ?? "draft");
  const [order, setOrder] = useState(module?.order ?? 1);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setSaving(true);
    setError("");
    try {
      await onSave({ title: title.trim(), type, content: content.trim(), summary: summary.trim(), estimatedMinutes, difficulty, order, status });
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : "The module could not be saved.");
    } finally {
      setSaving(false);
    }
  }

  return (
    <form className="editor-card space-y-5" onSubmit={submit}>
      <div><p className="eyebrow">MODULE EDITOR</p><h2 className="mt-1 text-xl font-bold text-[#293930]">{module ? "Edit module" : "Add module"}</h2></div>
      <label className="field-label">Title<input className="field mt-2" required value={title} onChange={(event) => setTitle(event.target.value)} /></label>
      <div className="grid gap-4 sm:grid-cols-2">
        <label className="field-label">Module type<select className="field mt-2" value={type} onChange={(event) => setType(event.target.value as ModuleType)}>{moduleTypes.map((value) => <option key={value} value={value}>{titleCase(value)}</option>)}</select></label>
        <label className="field-label">Difficulty<select className="field mt-2" value={difficulty} onChange={(event) => setDifficulty(event.target.value as ModuleDifficulty)}>{moduleDifficulties.map((value) => <option key={value} value={value}>{titleCase(value)}</option>)}</select></label>
      </div>
      <label className="field-label">Content<textarea className="field mt-2 min-h-64 resize-y leading-7" required value={content} onChange={(event) => setContent(event.target.value)} /></label>
      <label className="field-label">Summary<textarea className="field mt-2 min-h-28 resize-y" required value={summary} onChange={(event) => setSummary(event.target.value)} /></label>
      <div className="grid gap-4 sm:grid-cols-3">
        <label className="field-label">Estimated minutes<input className="field mt-2" type="number" min="1" required value={estimatedMinutes} onChange={(event) => setEstimatedMinutes(Number(event.target.value))} /></label>
        <label className="field-label">Order<input className="field mt-2" type="number" min="0" required value={order} onChange={(event) => setOrder(Number(event.target.value))} /></label>
        <label className="field-label">Status<select className="field mt-2" value={status} onChange={(event) => setStatus(event.target.value as ModuleStatus)}>{moduleStatuses.map((value) => <option key={value} value={value}>{titleCase(value)}</option>)}</select></label>
      </div>
      {error && <p className="error-banner">{error}</p>}
      <div className="flex flex-wrap gap-3"><button className="primary-button" disabled={saving} type="submit">{saving ? "Saving…" : "Save module"}</button><button className="secondary-button" onClick={onCancel} type="button">Cancel</button></div>
    </form>
  );
}

function titleCase(value: string) { return value.charAt(0).toUpperCase() + value.slice(1); }
