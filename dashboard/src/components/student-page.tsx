"use client";

import { FormEvent, useState } from "react";
import { useStudent } from "@/hooks/use-study-data";
import type { Student } from "@/lib/types";
import type { StudentRepository } from "@/lib/repositories/student-repository";

export function StudentPage() {
  const { student, error, repository } = useStudent();

  return (
    <section>
      <p className="eyebrow">STUDENT</p>
      <h1 className="page-title">Qidah&apos;s profile</h1>
      <p className="page-description">Changes are reflected in the student app in real time.</p>
      {error && <p className="error-banner">{error}</p>}
      {!student ? (
        <div className="panel mt-8 text-sm text-slate-500">Loading profile…</div>
      ) : (
        <StudentForm key={`${student.preferredLanguage}-${student.dailyTargetMinutes}-${student.status}`} student={student} repository={repository} />
      )}
    </section>
  );
}

function StudentForm({ student, repository }: { student: Student; repository: StudentRepository }) {
  const [preferredLanguage, setPreferredLanguage] = useState(student.preferredLanguage);
  const [dailyTargetMinutes, setDailyTargetMinutes] = useState(student.dailyTargetMinutes);
  const [status, setStatus] = useState(student.status);
  const [saving, setSaving] = useState(false);
  const [notice, setNotice] = useState("");

  async function save(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setSaving(true);
    setNotice("");
    try {
      await repository.updateQidah({ preferredLanguage: preferredLanguage.trim(), dailyTargetMinutes, status });
      setNotice("Qidah’s profile was updated.");
    } catch (error) {
      setNotice(error instanceof Error ? error.message : "The profile could not be updated.");
    } finally {
      setSaving(false);
    }
  }

  return (
    <form className="panel mt-8 max-w-2xl space-y-5" onSubmit={save}>
      <label className="field-label">Preferred language<input className="field mt-2" required value={preferredLanguage} onChange={(event) => setPreferredLanguage(event.target.value)} /></label>
      <label className="field-label">Daily target (minutes)<input className="field mt-2" type="number" min="5" max="240" required value={dailyTargetMinutes} onChange={(event) => setDailyTargetMinutes(Number(event.target.value))} /></label>
      <label className="field-label">Status<select className="field mt-2" value={status} onChange={(event) => setStatus(event.target.value)}><option value="active">Active</option><option value="paused">Paused</option><option value="inactive">Inactive</option></select></label>
      {notice && <p className="notice-banner" aria-live="polite">{notice}</p>}
      <button className="primary-button" disabled={saving} type="submit">{saving ? "Saving…" : "Save profile"}</button>
    </form>
  );
}
