"use client";

import { useEffect, useState } from "react";
import { useSubjects } from "@/hooks/use-study-data";
import { EDITABLE_SUBJECT_ID } from "@/lib/content-paths";
import type { Chapter, ChapterInput, LearningModule, LearningModuleInput } from "@/lib/types";
import { ChapterForm } from "./chapter-form";
import { ModuleForm } from "./module-form";

type Editor<T> = "new" | T | null;

export function ContentStudio() {
  const { subjects, error: subjectError, repository } = useSubjects();
  const [subjectId, setSubjectId] = useState<string | null>(null);
  const [chapters, setChapters] = useState<Chapter[]>([]);
  const [selectedChapterId, setSelectedChapterId] = useState<string | null>(null);
  const [modules, setModules] = useState<LearningModule[]>([]);
  const [chapterEditor, setChapterEditor] = useState<Editor<Chapter>>(null);
  const [moduleEditor, setModuleEditor] = useState<Editor<LearningModule>>(null);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");

  useEffect(() => {
    if (subjectId !== EDITABLE_SUBJECT_ID) return;
    return repository.watchChapters(
      subjectId,
      (nextChapters) => {
        setChapters(nextChapters);
        setSelectedChapterId((current) =>
          current && nextChapters.some((chapter) => chapter.id === current)
            ? current
            : (nextChapters[0]?.id ?? null),
        );
      },
      (nextError) => setError(nextError.message),
    );
  }, [repository, subjectId]);

  useEffect(() => {
    if (subjectId !== EDITABLE_SUBJECT_ID || !selectedChapterId) {
      queueMicrotask(() => setModules([]));
      return;
    }
    return repository.watchModules(
      subjectId,
      selectedChapterId,
      setModules,
      (nextError) => setError(nextError.message),
    );
  }, [repository, selectedChapterId, subjectId]);

  const selectedChapter = chapters.find((chapter) => chapter.id === selectedChapterId) ?? null;

  function openSubject(nextSubjectId: string) {
    if (nextSubjectId !== EDITABLE_SUBJECT_ID) return;
    setSubjectId(nextSubjectId);
    setChapterEditor(null);
    setModuleEditor(null);
    setError("");
    setNotice("");
  }

  async function saveChapter(input: ChapterInput) {
    if (!subjectId) return;
    if (chapterEditor && chapterEditor !== "new") {
      await repository.updateChapter(subjectId, chapterEditor.id, input);
      setNotice("Chapter updated.");
    } else {
      await repository.createChapter(subjectId, input);
      setNotice("Chapter created.");
    }
    setChapterEditor(null);
  }

  async function saveModule(input: LearningModuleInput) {
    if (!subjectId || !selectedChapterId) return;
    if (moduleEditor && moduleEditor !== "new") {
      await repository.updateModule(subjectId, selectedChapterId, moduleEditor.id, input);
      setNotice("Module updated.");
    } else {
      await repository.createModule(subjectId, selectedChapterId, input);
      setNotice("Module created.");
    }
    setModuleEditor(null);
  }

  async function archiveChapter(chapter: Chapter) {
    if (!subjectId) return;
    setError("");
    try {
      await repository.archiveChapter(subjectId, chapter.id);
      setNotice(`Chapter ${chapter.chapterNumber} archived.`);
    } catch (nextError) {
      setError(errorMessage(nextError));
    }
  }

  async function publishChapter(chapter: Chapter) {
    if (!subjectId) return;
    setError("");
    try {
      await repository.publishChapter(subjectId, chapter.id);
      setNotice(`Chapter ${chapter.chapterNumber} published.`);
    } catch (nextError) {
      setError(errorMessage(nextError));
    }
  }

  async function deleteChapter(chapter: Chapter) {
    if (!subjectId || !window.confirm(`Delete “${chapter.title}” and all of its modules? This cannot be undone.`)) return;
    setError("");
    try {
      await repository.deleteChapter(subjectId, chapter.id);
      setNotice("Chapter and its modules deleted.");
      setChapterEditor(null);
      setModuleEditor(null);
    } catch (nextError) {
      setError(errorMessage(nextError));
    }
  }

  async function deleteModule(module: LearningModule) {
    if (!subjectId || !selectedChapterId || !window.confirm(`Delete “${module.title}”? This cannot be undone.`)) return;
    setError("");
    try {
      await repository.deleteModule(subjectId, selectedChapterId, module.id);
      setNotice("Module deleted.");
      setModuleEditor(null);
    } catch (nextError) {
      setError(errorMessage(nextError));
    }
  }

  async function publishModule(module: LearningModule) {
    if (!subjectId || !selectedChapterId) return;
    setError("");
    try {
      await repository.publishModule(subjectId, selectedChapterId, module.id);
      setNotice("Module published. Its chapter is active and it is available in Continue.");
    } catch (nextError) {
      setError(errorMessage(nextError));
    }
  }

  if (!subjectId) {
    return (
      <section>
        <p className="eyebrow">CONTENT STUDIO / FORM 2</p>
        <h1 className="page-title">All subjects</h1>
        <p className="page-description">Build learning content in the official KSSM chapter sequence.</p>
        {subjectError && <p className="error-banner">{subjectError}</p>}
        <div className="mt-8 grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
          {subjects.map((subject) => {
            const editable = subject.id === EDITABLE_SUBJECT_ID;
            return (
              <article className="panel flex min-h-44 flex-col" key={subject.id}>
                <div className="mb-5 h-2 w-14 rounded-full" style={{ backgroundColor: subject.themeColor || "#7B8F72" }} />
                <h2 className="text-lg font-bold text-[#293930]">{subject.displayName}</h2>
                <p className="mt-1 text-sm text-slate-500">{subject.shortName}</p>
                <div className="mt-auto pt-6">
                  {editable ? <button className="primary-button w-full" onClick={() => openSubject(subject.id)} type="button">Manage chapters</button> : <span className="status-pill bg-stone-100 text-stone-600">Coming soon</span>}
                </div>
              </article>
            );
          })}
          {!subjects.length && !subjectError && <div className="panel text-sm text-slate-500">Loading subjects…</div>}
        </div>
      </section>
    );
  }

  return (
    <section>
      <button className="mb-5 text-sm font-semibold text-[#496a5a] hover:underline" onClick={() => setSubjectId(null)} type="button">← All Form 2 subjects</button>
      <p className="eyebrow">CONTENT STUDIO / FORM 2 / MATHEMATICS</p>
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div><h1 className="page-title">Mathematics</h1><p className="page-description">Chapters follow the official textbook sequence.</p></div>
        <button className="primary-button" onClick={() => { setChapterEditor("new"); setModuleEditor(null); }} type="button">Add chapter</button>
      </div>

      {(error || subjectError) && <p className="error-banner">{error || subjectError}</p>}
      {notice && <p className="notice-banner mt-5" aria-live="polite">{notice}</p>}

      {chapterEditor ? (
        <div className="mt-8"><ChapterForm chapter={chapterEditor === "new" ? undefined : chapterEditor} key={chapterEditor === "new" ? "new" : chapterEditor.id} onCancel={() => setChapterEditor(null)} onSave={saveChapter} /></div>
      ) : (
        <div className="mt-8 grid gap-6 xl:grid-cols-[minmax(18rem,0.8fr)_minmax(0,1.4fr)]">
          <section className="panel h-fit">
            <div className="mb-5 flex items-center justify-between"><h2 className="text-xl font-bold text-[#293930]">Chapters</h2><span className="status-pill bg-[#edf3ef] text-[#496a5a]">{chapters.length}</span></div>
            <div className="space-y-3">
              {chapters.map((chapter) => (
                <article className={`rounded-2xl border p-4 ${selectedChapterId === chapter.id ? "border-[#70917f] bg-[#f4f8f5]" : "border-[#e8ebe7]"}`} key={chapter.id}>
                  <button className="w-full text-left" onClick={() => { setSelectedChapterId(chapter.id); setModuleEditor(null); }} type="button">
                    <div className="flex items-start justify-between gap-3"><div><p className="text-xs font-semibold uppercase tracking-wide text-[#668071]">Chapter {chapter.chapterNumber}</p><h3 className="mt-1 font-bold text-[#293930]">{chapter.title}</h3></div><Status value={chapter.status} /></div>
                    <p className="mt-2 line-clamp-2 text-sm text-slate-500">{chapter.textbookChapterTitle}</p>
                  </button>
                  <div className="mt-4 flex flex-wrap gap-2 border-t border-[#e3e9e5] pt-3"><button className="small-button" onClick={() => setChapterEditor(chapter)} type="button">Edit</button>{chapter.status !== "active" && <button className="small-button" onClick={() => publishChapter(chapter)} type="button">Publish</button>}<button className="small-button" disabled={chapter.status === "archived"} onClick={() => archiveChapter(chapter)} type="button">Archive</button><button className="small-button danger" onClick={() => deleteChapter(chapter)} type="button">Delete</button></div>
                </article>
              ))}
              {!chapters.length && <p className="rounded-2xl bg-[#f7f8f6] px-4 py-7 text-center text-sm text-slate-500">No chapters yet. Add the first official Mathematics chapter.</p>}
            </div>
          </section>

          <section>
            {!selectedChapter ? (
              <div className="panel text-center text-sm text-slate-500">Select or create a chapter to manage modules.</div>
            ) : moduleEditor ? (
              <ModuleForm module={moduleEditor === "new" ? undefined : moduleEditor} key={moduleEditor === "new" ? `new-${selectedChapter.id}` : moduleEditor.id} onCancel={() => setModuleEditor(null)} onSave={saveModule} />
            ) : (
              <div className="panel">
                <div className="flex flex-wrap items-start justify-between gap-4"><div><p className="eyebrow">CHAPTER {selectedChapter.chapterNumber}</p><h2 className="mt-1 text-xl font-bold text-[#293930]">Learning modules</h2><p className="mt-1 text-sm text-slate-500">{selectedChapter.title}</p></div><button className="primary-button" onClick={() => setModuleEditor("new")} type="button">Add module</button></div>
                <div className="mt-6 space-y-3">
                  {modules.map((module) => (
                    <article className="rounded-2xl border border-[#e8ebe7] p-4" key={module.id}>
                      <div className="flex flex-wrap items-start justify-between gap-3"><div><p className="text-xs font-semibold uppercase tracking-wide text-[#668071]">{titleCase(module.type)} · {module.estimatedMinutes} min</p><h3 className="mt-1 font-bold text-[#293930]">{module.title}</h3><p className="mt-2 line-clamp-2 text-sm text-slate-500">{module.summary}</p></div><Status value={module.status} /></div>
                      <div className="mt-4 flex flex-wrap gap-2 border-t border-[#e8ebe7] pt-3"><button className="small-button" onClick={() => setModuleEditor(module)} type="button">Edit</button>{module.status !== "active" && <button className="small-button" onClick={() => publishModule(module)} type="button">Publish</button>}<button className="small-button danger" onClick={() => deleteModule(module)} type="button">Delete</button></div>
                    </article>
                  ))}
                  {!modules.length && <p className="rounded-2xl bg-[#f7f8f6] px-4 py-7 text-center text-sm text-slate-500">No modules in this chapter yet.</p>}
                </div>
              </div>
            )}
          </section>
        </div>
      )}
    </section>
  );
}

function Status({ value }: { value: string }) {
  const style = value === "active" ? "bg-emerald-50 text-emerald-700" : value === "archived" ? "bg-stone-100 text-stone-500" : "bg-amber-50 text-amber-700";
  return <span className={`status-pill ${style}`}>{titleCase(value)}</span>;
}

function titleCase(value: string) { return value.charAt(0).toUpperCase() + value.slice(1).replaceAll("_", " "); }
function errorMessage(error: unknown) { return error instanceof Error ? error.message : "The operation could not be completed."; }
