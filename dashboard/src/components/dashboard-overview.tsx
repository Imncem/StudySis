"use client";

import { useStudent, useSubjects } from "@/hooks/use-study-data";

export function DashboardOverview({ onOpenContent }: { onOpenContent: () => void }) {
  const { student, error: studentError } = useStudent();
  const { subjects, error: subjectError } = useSubjects();

  return (
    <section>
      <p className="eyebrow">STUDYSIS ADMIN</p>
      <h1 className="page-title">Qidah&apos;s learning space</h1>
      <p className="page-description">A calm overview of the student profile and Form 2 curriculum.</p>

      {(studentError || subjectError) && <p className="error-banner">{studentError || subjectError}</p>}

      <div className="mt-8 grid gap-5 sm:grid-cols-3">
        <div className="panel">
          <p className="metric-label">Student</p>
          <p className="metric-value">{student?.displayName ?? student?.fullName ?? student?.name ?? "Qidah"}</p>
          <p className="mt-2 text-sm text-slate-500">{student?.status ?? "Loading…"}</p>
        </div>
        <div className="panel">
          <p className="metric-label">Daily target</p>
          <p className="metric-value">{student ? `${student.dailyTargetMinutes} min` : "—"}</p>
          <p className="mt-2 text-sm text-slate-500">{student?.preferredLanguage ?? "Loading…"}</p>
        </div>
        <div className="panel">
          <p className="metric-label">Form 2 subjects</p>
          <p className="metric-value">{subjects.length || "—"}</p>
          <p className="mt-2 text-sm text-slate-500">Mathematics is editable in Sprint 2</p>
        </div>
      </div>

      <div className="panel mt-6 flex flex-wrap items-center justify-between gap-5">
        <div>
          <p className="text-lg font-bold text-[#293930]">Build Mathematics content</p>
          <p className="mt-1 text-sm text-slate-500">Create chapters and modules without opening Firebase Console.</p>
        </div>
        <button className="primary-button" onClick={onOpenContent} type="button">Open Content Studio</button>
      </div>
    </section>
  );
}
