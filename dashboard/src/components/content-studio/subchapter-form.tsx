"use client";

import { useState } from "react";
import type { Subchapter, SubchapterInput } from "@/lib/types";

export function SubchapterForm({
  subchapter,
  onCancel,
  onSave,
}: {
  subchapter?: Subchapter;
  onCancel: () => void;
  onSave: (input: SubchapterInput) => Promise<void>;
}) {
  const [number, setNumber] = useState(subchapter?.number ?? "");
  const [title, setTitle] = useState(subchapter?.title ?? "");
  const [order, setOrder] = useState(subchapter?.order ?? 1);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  async function submit(event: React.FormEvent) {
    event.preventDefault();
    setSaving(true);
    setError("");
    try {
      await onSave({
        number: number.trim(),
        title: title.trim(),
        order,
        status: subchapter?.status ?? "draft",
      });
    } catch (nextError) {
      setError(
        nextError instanceof Error
          ? nextError.message
          : "Unable to save subchapter.",
      );
    } finally {
      setSaving(false);
    }
  }

  return (
    <form className="panel space-y-5" onSubmit={submit}>
      <div>
        <p className="eyebrow">SEJARAH</p>
        <h2 className="mt-1 text-xl font-bold text-[#293930]">
          {subchapter ? "Edit subchapter" : "Add subchapter"}
        </h2>
      </div>
      {error && (
        <p className="rounded-xl bg-red-50 p-3 text-sm text-red-700">{error}</p>
      )}
      <label className="block text-sm font-semibold text-[#405349]">
        Number
        <input
          className="input mt-2"
          disabled={Boolean(subchapter)}
          onChange={(event) => setNumber(event.target.value)}
          pattern="[0-9]+\.[0-9]+"
          placeholder="1.4"
          required
          value={number}
        />
      </label>
      <label className="block text-sm font-semibold text-[#405349]">
        Title
        <input
          className="input mt-2"
          onChange={(event) => setTitle(event.target.value)}
          required
          value={title}
        />
      </label>
      <label className="block text-sm font-semibold text-[#405349]">
        Order
        <input
          className="input mt-2"
          min={1}
          onChange={(event) => setOrder(Number(event.target.value))}
          required
          type="number"
          value={order}
        />
      </label>
      <div className="flex gap-3">
        <button className="primary-button" disabled={saving} type="submit">
          {saving ? "Saving..." : "Save subchapter"}
        </button>
        <button className="small-button" onClick={onCancel} type="button">
          Cancel
        </button>
      </div>
    </form>
  );
}
