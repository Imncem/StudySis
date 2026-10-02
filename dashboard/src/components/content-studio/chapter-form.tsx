"use client";

import { type FormEvent, useState } from "react";
import { chapterStatuses, type Chapter, type ChapterInput, type ChapterStatus } from "@/lib/types";

export function ChapterForm({ chapter, structureSingular = "Chapter", onSave, onCancel }: { chapter?: Chapter; structureSingular?: string; onSave: (input: ChapterInput) => Promise<void>; onCancel: () => void }) {
  const [chapterNumber, setChapterNumber] = useState(chapter?.chapterNumber ?? 1);
  const [title, setTitle] = useState(chapter?.title ?? "");
  const [referenceTitle, setReferenceTitle] = useState(chapter?.textbookChapterTitle ?? "");
  const [objectives, setObjectives] = useState(chapter?.learningObjectives.join("\n") ?? "");
  const [estimatedMinutes, setEstimatedMinutes] = useState(chapter?.estimatedMinutes ?? 30);
  const [status, setStatus] = useState<ChapterStatus>(chapter?.status ?? "draft");
  const [order, setOrder] = useState(chapter?.order ?? chapter?.chapterNumber ?? 1);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setSaving(true);
    setError("");
    try {
      await onSave({ chapterNumber, title: title.trim(), textbookChapterTitle: referenceTitle.trim(), learningObjectives: objectives.split("\n").map((item) => item.trim()).filter(Boolean), estimatedMinutes, status, order });
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : `The ${structureSingular.toLowerCase()} could not be saved.`);
    } finally {
      setSaving(false);
    }
  }

  return <form className="editor-card space-y-5" onSubmit={submit}>
    <div><p className="eyebrow">{structureSingular.toUpperCase()} EDITOR</p><h2 className="mt-1 text-xl font-bold text-[#293930]">{chapter ? `Edit ${structureSingular.toLowerCase()}` : `Add ${structureSingular.toLowerCase()}`}</h2></div>
    <div className="grid gap-4 sm:grid-cols-2">
      <label className="field-label">{structureSingular} number<input className="field mt-2" type="number" min="1" required value={chapterNumber} onChange={(event) => setChapterNumber(Number(event.target.value))} /></label>
      <label className="field-label">Order<input className="field mt-2" type="number" min="0" required value={order} onChange={(event) => setOrder(Number(event.target.value))} /></label>
    </div>
    <label className="field-label">Title<input className="field mt-2" required value={title} onChange={(event) => setTitle(event.target.value)} /></label>
    <label className="field-label">Reference title<input className="field mt-2" required value={referenceTitle} onChange={(event) => setReferenceTitle(event.target.value)} /></label>
    <label className="field-label">Learning objectives <span className="font-normal text-slate-400">(one per line)</span><textarea className="field mt-2 min-h-32 resize-y" required value={objectives} onChange={(event) => setObjectives(event.target.value)} /></label>
    <div className="grid gap-4 sm:grid-cols-2">
      <label className="field-label">Estimated minutes<input className="field mt-2" type="number" min="1" required value={estimatedMinutes} onChange={(event) => setEstimatedMinutes(Number(event.target.value))} /></label>
      <label className="field-label">Status<select className="field mt-2" value={status} onChange={(event) => setStatus(event.target.value as ChapterStatus)}>{chapterStatuses.map((value) => <option key={value} value={value}>{titleCase(value)}</option>)}</select></label>
    </div>
    {error && <p className="error-banner">{error}</p>}
    <div className="flex flex-wrap gap-3"><button className="primary-button" disabled={saving} type="submit">{saving ? "Saving..." : `Save ${structureSingular.toLowerCase()}`}</button><button className="secondary-button" onClick={onCancel} type="button">Cancel</button></div>
  </form>;
}

function titleCase(value: string) { return value.charAt(0).toUpperCase() + value.slice(1); }
