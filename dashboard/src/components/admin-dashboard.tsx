"use client";

import { FormEvent, useEffect, useState } from "react";
import type { User } from "firebase/auth";
import { signOut } from "firebase/auth";
import {
  collection,
  doc,
  onSnapshot,
  orderBy,
  query,
  updateDoc,
} from "firebase/firestore";
import { getFirebaseAuth, getFirebaseDb } from "@/lib/firebase";
import type { Student, Subject } from "@/lib/types";

type Props = { user: User };

export function AdminDashboard({ user }: Props) {
  const [student, setStudent] = useState<Student | null>(null);
  const [subjects, setSubjects] = useState<Subject[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState("");
  const [preferredLanguage, setPreferredLanguage] = useState("");
  const [dailyTargetMinutes, setDailyTargetMinutes] = useState(20);
  const [status, setStatus] = useState("active");
  const [saving, setSaving] = useState(false);
  const [notice, setNotice] = useState("");

  useEffect(() => {
    const db = getFirebaseDb();
    const stopStudent = onSnapshot(
      doc(db, "students", "qidah"),
      (snapshot) => {
        if (!snapshot.exists()) {
          setLoadError("The students/qidah document does not exist.");
          setLoading(false);
          return;
        }
        const value = snapshot.data() as Student;
        setStudent(value);
        setPreferredLanguage(value.preferredLanguage ?? "Bahasa Melayu");
        setDailyTargetMinutes(value.dailyTargetMinutes ?? 20);
        setStatus(value.status ?? "active");
        setLoading(false);
      },
      (error) => {
        setLoadError(error.message);
        setLoading(false);
      },
    );

    const subjectQuery = query(
      collection(db, "curriculum", "form2", "subjects"),
      orderBy("order"),
    );
    const stopSubjects = onSnapshot(
      subjectQuery,
      (snapshot) => {
        setSubjects(snapshot.docs.map((item) => ({ id: item.id, ...item.data() }) as Subject));
      },
      (error) => setLoadError(error.message),
    );

    return () => {
      stopStudent();
      stopSubjects();
    };
  }, []);

  async function saveProfile(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setSaving(true);
    setNotice("");
    try {
      const db = getFirebaseDb();
      await updateDoc(doc(db, "students", "qidah"), {
        preferredLanguage: preferredLanguage.trim(),
        dailyTargetMinutes,
        status: status.trim(),
      });
      setNotice("Qidah’s profile was updated.");
    } catch (error) {
      setNotice(error instanceof Error ? error.message : "The profile could not be updated.");
    } finally {
      setSaving(false);
    }
  }

  if (loading) {
    return <main className="grid min-h-screen place-items-center text-sm text-slate-500">Loading Qidah&apos;s profile…</main>;
  }

  return (
    <main className="mx-auto min-h-screen max-w-7xl px-5 py-8 sm:px-8 lg:py-12">
      <header className="mb-9 flex flex-wrap items-center justify-between gap-4">
        <div>
          <p className="text-sm font-semibold tracking-wide text-[#567263]">STUDYSIS ADMIN</p>
          <h1 className="mt-1 text-3xl font-bold tracking-tight text-[#24342b]">Qidah&apos;s learning space</h1>
        </div>
        <div className="flex items-center gap-3">
          <span className="hidden text-sm text-slate-500 sm:block">{user.email}</span>
          <button className="secondary-button" onClick={() => signOut(getFirebaseAuth())} type="button">Sign out</button>
        </div>
      </header>

      {loadError && <p role="alert" className="mb-6 rounded-2xl bg-red-50 px-5 py-4 text-sm text-red-700">{loadError}</p>}

      <div className="grid gap-6 lg:grid-cols-[minmax(0,0.8fr)_minmax(0,1.2fr)]">
        <section className="panel h-fit">
          <div className="mb-6">
            <p className="text-sm font-medium text-[#668071]">Student profile</p>
            <h2 className="mt-1 text-2xl font-bold text-[#24342b]">{student?.name ?? student?.displayName ?? "Qidah"}</h2>
          </div>
          <form className="space-y-5" onSubmit={saveProfile}>
            <label className="block text-sm font-medium text-slate-700">
              Preferred language
              <input className="field mt-2" required value={preferredLanguage} onChange={(event) => setPreferredLanguage(event.target.value)} />
            </label>
            <label className="block text-sm font-medium text-slate-700">
              Daily target (minutes)
              <input className="field mt-2" type="number" min="5" max="240" required value={dailyTargetMinutes} onChange={(event) => setDailyTargetMinutes(Number(event.target.value))} />
            </label>
            <label className="block text-sm font-medium text-slate-700">
              Status
              <select className="field mt-2" value={status} onChange={(event) => setStatus(event.target.value)}>
                <option value="active">Active</option>
                <option value="paused">Paused</option>
                <option value="inactive">Inactive</option>
              </select>
            </label>
            {notice && <p aria-live="polite" className="rounded-xl bg-[#f0f5f1] px-4 py-3 text-sm text-[#385848]">{notice}</p>}
            <button className="primary-button w-full sm:w-auto" disabled={saving} type="submit">
              {saving ? "Saving…" : "Save profile"}
            </button>
          </form>
        </section>

        <section className="panel">
          <div className="mb-6 flex items-end justify-between gap-4">
            <div>
              <p className="text-sm font-medium text-[#668071]">Form 2 curriculum</p>
              <h2 className="mt-1 text-2xl font-bold text-[#24342b]">Subjects</h2>
            </div>
            <span className="rounded-full bg-[#edf3ef] px-3 py-1 text-sm font-semibold text-[#496a5a]">{subjects.length} subjects</span>
          </div>

          <div className="space-y-3">
            {subjects.map((subject) => (
              <article className="flex flex-wrap items-center gap-4 rounded-2xl border border-[#e8ebe7] p-4" key={subject.id}>
                <span className="h-11 w-2 rounded-full" style={{ backgroundColor: subject.themeColor || "#7B8F72" }} />
                <div className="min-w-0 flex-1">
                  <h3 className="font-semibold text-[#293930]">{subject.displayName}</h3>
                  <p className="mt-0.5 text-sm text-slate-500">{subject.shortName} · {subject.iconName}</p>
                </div>
                <span className={`rounded-full px-3 py-1 text-xs font-semibold ${subject.contentStatus === "coming_soon" ? "bg-stone-100 text-stone-600" : "bg-emerald-50 text-emerald-700"}`}>
                  {subject.contentStatus === "coming_soon" ? "Coming soon" : formatStatus(subject.contentStatus)}
                </span>
              </article>
            ))}
            {!subjects.length && !loadError && <p className="py-8 text-center text-sm text-slate-500">No subjects found.</p>}
          </div>
        </section>
      </div>
    </main>
  );
}

function formatStatus(value = "unknown") {
  return value.replaceAll("_", " ").replace(/^./, (letter) => letter.toUpperCase());
}
