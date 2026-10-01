"use client";

import { useEffect, useMemo, useState } from "react";
import { useSubjects } from "@/hooks/use-study-data";
import {
  canEditSubject,
  filterAccessibleSubjects,
  type DashboardAccess,
} from "@/lib/dashboard-access";
import {
  getCurriculumSetupDefinition,
  getCurriculumSetupStatus,
} from "@/lib/curriculum/curriculumSetup";
import { getFirebaseDb } from "@/lib/firebase";
import { StructuredContentRepository } from "@/lib/repositories/structured-content-repository";
import type { Chapter, ChapterInput, LearningModule, LearningModuleInput } from "@/lib/types";
import { ChapterForm } from "./chapter-form";
import { CurriculumSetupDialog } from "./curriculum-setup-dialog";
import { ModuleCompletionCount } from "./module-completion-count";
import { ModuleForm } from "./module-form";
import { StructuredModuleEditor } from "./structured-module-editor";

type Editor<T> = "new" | T | null;

export function ContentStudio({ access }: { access: DashboardAccess }) {
  const { subjects, error: subjectError, repository } = useSubjects();
  const structuredRepository = useMemo(
    () => new StructuredContentRepository(getFirebaseDb()),
    [],
  );
  const [subjectId, setSubjectId] = useState<string | null>(null);
  const [chapters, setChapters] = useState<Chapter[]>([]);
  const [chaptersLoaded, setChaptersLoaded] = useState(false);
  const [selectedChapterId, setSelectedChapterId] = useState<string | null>(null);
  const [modules, setModules] = useState<LearningModule[]>([]);
  const [chapterEditor, setChapterEditor] = useState<Editor<Chapter>>(null);
  const [moduleEditor, setModuleEditor] = useState<Editor<LearningModule>>(null);
  const [structuredModuleId, setStructuredModuleId] = useState<string | null>(null);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [isSettingUp, setIsSettingUp] = useState(false);
  const [showSetupPreview, setShowSetupPreview] = useState(false);
  const visibleSubjects = useMemo(
    () => filterAccessibleSubjects(subjects, access),
    [access, subjects],
  );
  const selectedSubject = subjects.find((subject) => subject.id === subjectId) ?? null;
  const isAdmin = access.role === "admin";
  const setupDefinition = useMemo(
    () => subjectId ? getCurriculumSetupDefinition(subjectId) : null,
    [subjectId],
  );
  const setupStatus = useMemo(
    () => subjectId && chaptersLoaded
      ? getCurriculumSetupStatus(subjectId, chapters.map((chapter) => chapter.id))
      : null,
    [chapters, chaptersLoaded, subjectId],
  );
  const structureSingular = setupDefinition?.structureLabelSingular ?? "Curriculum item";
  const structurePlural = setupDefinition?.structureLabelPlural ?? "Curriculum items";

  useEffect(() => {
    if (!subjectId || !canEditSubject(access, subjectId)) return;
    return repository.watchChapters(
      subjectId,
      (nextChapters) => {
        setChapters(nextChapters);
        setChaptersLoaded(true);
        setSelectedChapterId((current) =>
          current && nextChapters.some((chapter) => chapter.id === current)
            ? current
            : (nextChapters[0]?.id ?? null),
        );
      },
      (nextError) => setError(nextError.message),
    );
  }, [access, repository, subjectId]);

  useEffect(() => {
    if (!subjectId || !canEditSubject(access, subjectId) || !selectedChapterId) {
      queueMicrotask(() => setModules([]));
      return;
    }
    return repository.watchModules(
      subjectId,
      selectedChapterId,
      setModules,
      (nextError) => setError(nextError.message),
    );
  }, [access, repository, selectedChapterId, subjectId]);

  const selectedChapter = chapters.find((chapter) => chapter.id === selectedChapterId) ?? null;
  const structuredModule =
    modules.find((module) => module.id === structuredModuleId) ?? null;

  function openSubject(nextSubjectId: string) {
    if (!canEditSubject(access, nextSubjectId)) return;
    setSubjectId(nextSubjectId);
    setChapters([]);
    setChaptersLoaded(false);
    setSelectedChapterId(null);
    setChapterEditor(null);
    setModuleEditor(null);
    setStructuredModuleId(null);
    setError("");
    setNotice("");
    setShowSetupPreview(false);
  }

  async function saveChapter(input: ChapterInput) {
    if (!subjectId || !isAdmin) return;
    if (chapterEditor && chapterEditor !== "new") {
      await repository.updateChapter(subjectId, chapterEditor.id, input);
      setNotice(`${structureSingular} updated.`);
    } else {
      await repository.createChapter(subjectId, input);
      setNotice(`${structureSingular} created.`);
    }
    setChapterEditor(null);
  }

  async function setupCurriculum() {
    if (!subjectId || !isAdmin || !setupStatus || setupStatus.missing === 0) return;
    setIsSettingUp(true);
    setError("");
    setNotice("");
    try {
      const result = await repository.setupCurriculum(subjectId);
      setNotice(
        `Curriculum setup complete: ${result.created} created, ${result.skipped} preserved.`,
      );
      setShowSetupPreview(false);
    } catch (nextError) {
      setError(errorMessage(nextError));
    } finally {
      setIsSettingUp(false);
    }
  }

  async function saveModule(input: LearningModuleInput) {
    if (!subjectId || !selectedChapterId) return;
    const allowedInput = isAdmin ? input : { ...input, status: "draft" as const };
    if (moduleEditor && moduleEditor !== "new") {
      await repository.updateModule(subjectId, selectedChapterId, moduleEditor.id, allowedInput);
      setNotice("Module updated.");
    } else {
      await repository.createModule(subjectId, selectedChapterId, allowedInput);
      setNotice("Module created.");
    }
    setModuleEditor(null);
  }

  async function archiveChapter(chapter: Chapter) {
    if (!subjectId) return;
    setError("");
    try {
      await repository.archiveChapter(subjectId, chapter.id);
      setNotice(`${structureSingular} ${chapter.chapterNumber} archived.`);
    } catch (nextError) {
      setError(errorMessage(nextError));
    }
  }

  async function publishChapter(chapter: Chapter) {
    if (!subjectId) return;
    setError("");
    try {
      await repository.publishChapter(subjectId, chapter.id);
      setNotice(`${structureSingular} ${chapter.chapterNumber} published.`);
    } catch (nextError) {
      setError(errorMessage(nextError));
    }
  }

  async function deleteChapter(chapter: Chapter) {
    if (!subjectId || !window.confirm(`Delete “${chapter.title}” and all of its modules? This cannot be undone.`)) return;
    setError("");
    try {
      await repository.deleteChapter(subjectId, chapter.id);
      setNotice(`${structureSingular} and its modules deleted.`);
      setChapterEditor(null);
      setModuleEditor(null);
      setStructuredModuleId(null);
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
      setStructuredModuleId(null);
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
          {visibleSubjects.map((subject) => {
            return (
              <article className="panel flex min-h-44 flex-col" key={subject.id}>
                <div className="mb-5 h-2 w-14 rounded-full" style={{ backgroundColor: subject.themeColor || "#7B8F72" }} />
                <h2 className="text-lg font-bold text-[#293930]">{subject.displayName}</h2>
                <p className="mt-1 text-sm text-slate-500">{subject.shortName}</p>
                <div className="mt-auto pt-6">
                  <button className="primary-button w-full" onClick={() => openSubject(subject.id)} type="button">Open content</button>
                </div>
              </article>
            );
          })}
          {!visibleSubjects.length && !subjectError && <div className="panel text-sm text-slate-500">No assigned subjects are available.</div>}
        </div>
      </section>
    );
  }

  return (
    <section>
      <button className="mb-5 text-sm font-semibold text-[#496a5a] hover:underline" onClick={() => setSubjectId(null)} type="button">← All Form 2 subjects</button>
      <p className="eyebrow">CONTENT STUDIO / FORM 2 / {selectedSubject?.shortName ?? subjectId}</p>
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div><h1 className="page-title">{selectedSubject?.displayName ?? subjectId}</h1><p className="page-description">Create draft learning content within the verified curriculum structure.</p></div>
        {isAdmin && <div className="flex flex-wrap gap-3">
          <button className="primary-button" onClick={() => { setChapterEditor("new"); setModuleEditor(null); }} type="button">Add {structureSingular}</button>
        </div>}
      </div>

      {isAdmin && setupStatus && (
        <div className="mt-6 flex flex-wrap items-center justify-between gap-4 rounded-2xl border border-[#dfe7e1] bg-white/80 px-5 py-4">
          <div>
            <p className="text-sm font-bold text-[#293930]">
              {setupStatus.state === "configured"
                ? "Curriculum configured"
                : setupStatus.state === "notConfigured"
                  ? "Curriculum not configured"
                  : `${setupStatus.existing} of ${setupStatus.expected} ${structurePlural.toLowerCase()} configured`}
            </p>
            {setupStatus.unexpectedIds.length > 0 && (
              <p className="mt-1 text-xs text-slate-500">
                {setupStatus.unexpectedIds.length} additional document{setupStatus.unexpectedIds.length === 1 ? "" : "s"} preserved.
              </p>
            )}
          </div>
          {setupStatus.state !== "configured" && (
            <button className="secondary-button" onClick={() => setShowSetupPreview(true)} type="button">
              {setupStatus.state === "partiallyConfigured" ? "Complete setup" : "Set up curriculum"}
            </button>
          )}
        </div>
      )}

      {(error || subjectError) && <p className="error-banner">{error || subjectError}</p>}
      {notice && <p className="notice-banner mt-5" aria-live="polite">{notice}</p>}

      {chapterEditor ? (
        <div className="mt-8"><ChapterForm chapter={chapterEditor === "new" ? undefined : chapterEditor} key={chapterEditor === "new" ? "new" : chapterEditor.id} onCancel={() => setChapterEditor(null)} onSave={saveChapter} /></div>
      ) : (
        <div className="mt-8 grid gap-6 xl:grid-cols-[minmax(18rem,0.8fr)_minmax(0,1.4fr)]">
          <section className="panel h-fit">
            <div className="mb-5 flex items-center justify-between"><h2 className="text-xl font-bold text-[#293930]">{structurePlural}</h2><span className="status-pill bg-[#edf3ef] text-[#496a5a]">{chapters.length}</span></div>
            <div className="space-y-3">
              {chapters.map((chapter) => (
                <article className={`rounded-2xl border p-4 ${selectedChapterId === chapter.id ? "border-[#70917f] bg-[#f4f8f5]" : "border-[#e8ebe7]"}`} key={chapter.id}>
                  <button className="w-full text-left" onClick={() => { setSelectedChapterId(chapter.id); setModuleEditor(null); setStructuredModuleId(null); }} type="button">
                    <div className="flex items-start justify-between gap-3"><div><p className="text-xs font-semibold uppercase tracking-wide text-[#668071]">{structureSingular} {chapter.chapterNumber}</p><h3 className="mt-1 font-bold text-[#293930]">{chapter.title}</h3>{chapter.group && <p className="mt-1 text-xs font-medium text-slate-500">{chapter.group}</p>}</div><Status value={chapter.status} /></div>
                    <p className="mt-2 line-clamp-2 text-sm text-slate-500">{chapter.textbookChapterTitle}</p>
                  </button>
                  {isAdmin && <div className="mt-4 flex flex-wrap gap-2 border-t border-[#e3e9e5] pt-3"><button className="small-button" onClick={() => setChapterEditor(chapter)} type="button">Edit</button>{chapter.status !== "active" && <button className="small-button" onClick={() => publishChapter(chapter)} type="button">Publish</button>}<button className="small-button" disabled={chapter.status === "archived"} onClick={() => archiveChapter(chapter)} type="button">Archive</button><button className="small-button danger" onClick={() => deleteChapter(chapter)} type="button">Delete</button></div>}
                </article>
              ))}
              {!chapters.length && <p className="rounded-2xl bg-[#f7f8f6] px-4 py-7 text-center text-sm text-slate-500">No curriculum items are available yet.</p>}
            </div>
          </section>

          <section>
            {!selectedChapter ? (
              <div className="panel text-center text-sm text-slate-500">Select or create a {structureSingular.toLowerCase()} to manage modules.</div>
            ) : moduleEditor ? (
              <ModuleForm allowStatusChange={isAdmin} module={moduleEditor === "new" ? undefined : moduleEditor} key={moduleEditor === "new" ? `new-${selectedChapter.id}` : moduleEditor.id} onCancel={() => setModuleEditor(null)} onSave={saveModule} />
            ) : structuredModule ? (
              <StructuredModuleEditor
                chapterId={selectedChapter.id}
                module={structuredModule}
                onBack={() => setStructuredModuleId(null)}
                onEditDetails={() => {
                  setModuleEditor(structuredModule);
                  setStructuredModuleId(null);
                }}
                onPublish={() => publishModule(structuredModule)}
                canEdit={isAdmin || structuredModule.status === "draft"}
                canPublish={isAdmin}
                repository={structuredRepository}
                subjectId={subjectId}
              />
            ) : (
              <div className="panel">
                <div className="flex flex-wrap items-start justify-between gap-4"><div><p className="eyebrow">{structureSingular.toUpperCase()} {selectedChapter.chapterNumber}</p><h2 className="mt-1 text-xl font-bold text-[#293930]">Learning modules</h2><p className="mt-1 text-sm text-slate-500">{selectedChapter.title}</p></div><button className="primary-button" onClick={() => setModuleEditor("new")} type="button">Add module</button></div>
                <div className="mt-6 space-y-3">
                  {modules.map((module) => (
                    <article className="rounded-2xl border border-[#e8ebe7] p-4" key={module.id}>
                      <button className="w-full text-left" onClick={() => setStructuredModuleId(module.id)} type="button">
                        <div className="flex flex-wrap items-start justify-between gap-3"><div><p className="text-xs font-semibold uppercase tracking-wide text-[#668071]">{titleCase(module.type)} · {module.estimatedMinutes} min</p><h3 className="mt-1 font-bold text-[#293930]">{module.title}</h3><p className="mt-2 text-sm font-medium text-[#60766a]"><ModuleCompletionCount chapterId={selectedChapter.id} module={module} repository={structuredRepository} subjectId={subjectId} /></p></div><Status value={module.status} /></div>
                      </button>
                      <div className="mt-4 flex flex-wrap gap-2 border-t border-[#e8ebe7] pt-3">{(isAdmin || module.status === "draft") && <button className="small-button" onClick={() => setModuleEditor(module)} type="button">Edit</button>}{isAdmin && module.status !== "active" && <button className="small-button" onClick={() => publishModule(module)} type="button">Publish</button>}{(isAdmin || module.status === "draft") && <button className="small-button danger" onClick={() => deleteModule(module)} type="button">Delete</button>}</div>
                    </article>
                  ))}
                  {!modules.length && <p className="rounded-2xl bg-[#f7f8f6] px-4 py-7 text-center text-sm text-slate-500">No modules in this chapter yet.</p>}
                </div>
              </div>
            )}
          </section>
        </div>
      )}
      {showSetupPreview && setupDefinition && setupStatus && setupStatus.missing > 0 && selectedSubject && (
        <CurriculumSetupDialog
          definition={setupDefinition}
          onCancel={() => setShowSetupPreview(false)}
          onConfirm={setupCurriculum}
          saving={isSettingUp}
          status={setupStatus}
          subjectName={selectedSubject.displayName}
        />
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
