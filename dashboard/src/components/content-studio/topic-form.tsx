"use client";

import { type FormEvent, useState } from "react";
import { chapterStatuses, type ChapterStatus, type Topic, type TopicInput } from "@/lib/types";

export function TopicForm({ topic, onSave, onCancel }: { topic?: Topic; onSave: (input: TopicInput) => Promise<void>; onCancel: () => void }) {
  const [title, setTitle] = useState(topic?.title ?? "");
  const [order, setOrder] = useState(topic?.order ?? 1);
  const [status, setStatus] = useState<ChapterStatus>(topic?.status ?? "draft");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  async function submit(event: FormEvent<HTMLFormElement>) { event.preventDefault(); setSaving(true); setError(""); try { await onSave({ title: title.trim(), order, status: topic ? status : "draft" }); } catch (nextError) { setError(nextError instanceof Error ? nextError.message : "The topic could not be saved."); } finally { setSaving(false); } }
  return <form className="editor-card space-y-5" onSubmit={submit}>
    <div><p className="eyebrow">TOPIC EDITOR</p><h2 className="mt-1 text-xl font-bold text-[#293930]">{topic ? "Edit topic" : "Add topic"}</h2></div>
    <label className="field-label">Title<input className="field mt-2" required value={title} onChange={(event) => setTitle(event.target.value)} /></label>
    <div className="grid gap-4 sm:grid-cols-2"><label className="field-label">Order<input className="field mt-2" min="1" required type="number" value={order} onChange={(event) => setOrder(Number(event.target.value))} /></label><label className="field-label">Status<select className="field mt-2" disabled={!topic} value={topic ? status : "draft"} onChange={(event) => setStatus(event.target.value as ChapterStatus)}>{chapterStatuses.map((value) => <option key={value} value={value}>{titleCase(value)}</option>)}</select></label></div>
    {error && <p className="error-banner">{error}</p>}
    <div className="flex flex-wrap gap-3"><button className="primary-button" disabled={saving} type="submit">{saving ? "Saving..." : "Save topic"}</button><button className="secondary-button" onClick={onCancel} type="button">Cancel</button></div>
  </form>;
}

function titleCase(value: string) { return value.charAt(0).toUpperCase() + value.slice(1); }
