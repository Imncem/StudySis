"use client";

import { useEffect, useMemo, useState } from "react";
import { useSubjects } from "@/hooks/use-study-data";
import { canEditSubject, filterAccessibleSubjects, type DashboardAccess } from "@/lib/dashboard-access";
import {
  curriculumDocumentIdFromTitle,
  getCurriculumSetupDefinition,
  type CurriculumSetupStatus,
} from "@/lib/curriculum/curriculumSetup";
import { getCurriculumPresentation } from "@/lib/curriculum/curriculumPresentation";
import type { CurriculumContentLocation } from "@/lib/content-paths";
import { contentStatusOptions } from "@/lib/content-status-permissions";
import { getFirebaseDb } from "@/lib/firebase";
import { StructuredContentRepository } from "@/lib/repositories/structured-content-repository";
import type { Chapter, ChapterInput, LearningModule, LearningModuleInput, Topic, TopicInput } from "@/lib/types";
import { ChapterForm } from "./chapter-form";
import { CurriculumSetupDialog } from "./curriculum-setup-dialog";
import { ModuleCompletionCount } from "./module-completion-count";
import { ModuleForm } from "./module-form";
import { StructuredModuleEditor } from "./structured-module-editor";
import { TopicForm } from "./topic-form";

type Editor<T> = "new" | T | null;

export function ContentStudio({ access }: { access: DashboardAccess }) {
  const { subjects, error: subjectError, repository } = useSubjects();
  const structuredRepository = useMemo(() => new StructuredContentRepository(getFirebaseDb()), []);
  const [subjectId, setSubjectId] = useState<string | null>(null);
  const [chapters, setChapters] = useState<Chapter[]>([]);
  const [chaptersLoaded, setChaptersLoaded] = useState(false);
  const [selectedChapterId, setSelectedChapterId] = useState<string | null>(null);
  const [topics, setTopics] = useState<Topic[]>([]);
  const [selectedTopicId, setSelectedTopicId] = useState<string | null>(null);
  const [modules, setModules] = useState<LearningModule[]>([]);
  const [chapterEditor, setChapterEditor] = useState<Editor<Chapter>>(null);
  const [topicEditor, setTopicEditor] = useState<Editor<Topic>>(null);
  const [moduleEditor, setModuleEditor] = useState<Editor<LearningModule>>(null);
  const [structuredModuleId, setStructuredModuleId] = useState<string | null>(null);
  const [setupStatus, setSetupStatus] = useState<CurriculumSetupStatus | null>(null);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [isSettingUp, setIsSettingUp] = useState(false);
  const [showSetupPreview, setShowSetupPreview] = useState(false);

  const visibleSubjects = useMemo(() => filterAccessibleSubjects(subjects, access), [access, subjects]);
  const selectedSubject = subjects.find((subject) => subject.id === subjectId) ?? null;
  const isAdmin = access.role === "admin";
  const setupDefinition = useMemo(() => subjectId ? getCurriculumSetupDefinition(subjectId) : null, [subjectId]);
  const setupPresentation = useMemo(
    () => setupDefinition && setupStatus
      ? getCurriculumPresentation(setupDefinition, setupStatus)
      : null,
    [setupDefinition, setupStatus],
  );
  const isLanguageSubject = setupDefinition?.structureType === "section";
  const expectedChapterIds = useMemo(() => new Set(setupDefinition?.items.map((item) => item.id) ?? []), [setupDefinition]);
  const displayedChapters = isLanguageSubject
    ? chapters.filter((chapter) => expectedChapterIds.has(chapter.id))
    : chapters;
  const structureSingular = setupDefinition?.structureLabelSingular ?? "Curriculum item";
  const structurePlural = setupDefinition?.structureLabelPlural ?? "Curriculum items";
  const selectedChapter = displayedChapters.find((chapter) => chapter.id === selectedChapterId) ?? null;
  const selectedTopic = topics.find((topic) => topic.id === selectedTopicId) ?? null;
  const moduleLocation = useMemo<CurriculumContentLocation | null>(() => {
    if (!subjectId || !selectedChapterId) return null;
    if (isLanguageSubject && !selectedTopicId) return null;
    return {
      subjectId,
      chapterId: selectedChapterId,
      ...(selectedTopicId ? { topicId: selectedTopicId } : {}),
    };
  }, [isLanguageSubject, selectedChapterId, selectedTopicId, subjectId]);
  const structuredModule = modules.find((module) => module.id === structuredModuleId) ?? null;

  useEffect(() => {
    if (!subjectId || !canEditSubject(access, subjectId)) return;
    return repository.watchChapters(subjectId, (nextChapters) => {
      setChapters(nextChapters);
      setChaptersLoaded(true);
      const selectable = isLanguageSubject
        ? nextChapters.filter((chapter) => expectedChapterIds.has(chapter.id))
        : nextChapters;
      setSelectedChapterId((current) => current && selectable.some((chapter) => chapter.id === current) ? current : (selectable[0]?.id ?? null));
    }, (nextError) => setError(nextError.message));
  }, [access, expectedChapterIds, isLanguageSubject, repository, subjectId]);

  useEffect(() => {
    if (!subjectId || !chaptersLoaded) return;
    let active = true;
    void repository.getCurriculumSetupStatus(subjectId)
      .then((status) => { if (active) setSetupStatus(status); })
      .catch((nextError) => { if (active) setError(errorMessage(nextError)); });
    return () => { active = false; };
  }, [chapters, chaptersLoaded, repository, subjectId]);

  useEffect(() => {
    if (!subjectId || !selectedChapterId || !isLanguageSubject) {
      queueMicrotask(() => { setTopics([]); setSelectedTopicId(null); });
      return;
    }
    return repository.watchTopics(subjectId, selectedChapterId, (nextTopics) => {
      setTopics(nextTopics);
      setSelectedTopicId((current) => current && nextTopics.some((topic) => topic.id === current) ? current : (nextTopics[0]?.id ?? null));
    }, (nextError) => setError(nextError.message));
  }, [isLanguageSubject, repository, selectedChapterId, subjectId]);

  useEffect(() => {
    if (!moduleLocation || !subjectId || !canEditSubject(access, subjectId)) {
      queueMicrotask(() => setModules([]));
      return;
    }
    return repository.watchModules(moduleLocation, setModules, (nextError) => setError(nextError.message));
  }, [access, moduleLocation, repository, subjectId]);

  function openSubject(nextSubjectId: string) {
    if (!canEditSubject(access, nextSubjectId)) return;
    setSubjectId(nextSubjectId);
    setChapters([]);
    setChaptersLoaded(false);
    setSelectedChapterId(null);
    setTopics([]);
    setSelectedTopicId(null);
    setChapterEditor(null);
    setTopicEditor(null);
    setModuleEditor(null);
    setStructuredModuleId(null);
    setSetupStatus(null);
    setError("");
    setNotice("");
    setShowSetupPreview(false);
  }

  function selectChapter(chapterId: string) {
    setSelectedChapterId(chapterId);
    setSelectedTopicId(null);
    setTopicEditor(null);
    setModuleEditor(null);
    setStructuredModuleId(null);
  }

  function selectTopic(topicId: string) {
    setSelectedTopicId(topicId);
    setModuleEditor(null);
    setStructuredModuleId(null);
  }

  async function saveChapter(input: ChapterInput) {
    if (!subjectId || !isAdmin) return;
    if (chapterEditor && chapterEditor !== "new") {
      await repository.updateChapter(subjectId, chapterEditor.id, input);
      setNotice(`${structureSingular} updated.`);
    } else {
      const documentId = isLanguageSubject ? curriculumDocumentIdFromTitle(input.title) : undefined;
      await repository.createChapter(subjectId, input, documentId);
      setNotice(`${structureSingular} created.`);
    }
    setChapterEditor(null);
  }

  async function saveTopic(input: TopicInput) {
    if (!subjectId || !selectedChapterId || !isAdmin) return;
    if (topicEditor && topicEditor !== "new") {
      await repository.updateTopic(subjectId, selectedChapterId, topicEditor.id, input);
      setNotice("Topic updated.");
    } else {
      await repository.createTopic(subjectId, selectedChapterId, input);
      setNotice("Draft topic created.");
    }
    setTopicEditor(null);
  }

  async function setupCurriculum() {
    if (!subjectId || !isAdmin || !setupStatus || setupStatus.migration.state === "blocked") return;
    setIsSettingUp(true);
    setError("");
    setNotice("");
    try {
      const result = await repository.setupCurriculum(subjectId);
      setNotice(`Curriculum setup complete: ${result.created} created, ${result.skipped} preserved.`);
      setShowSetupPreview(false);
    } catch (nextError) {
      setError(errorMessage(nextError));
    } finally {
      setIsSettingUp(false);
    }
  }

  async function saveModule(input: LearningModuleInput) {
    if (!moduleLocation) return;
    const allowedInput = !isAdmin && moduleEditor === "new"
      ? { ...input, status: "draft" as const }
      : input;
    if (moduleEditor && moduleEditor !== "new") {
      await repository.updateModule(moduleLocation, moduleEditor.id, allowedInput);
      setNotice("Module updated.");
    } else {
      await repository.createModule(moduleLocation, allowedInput);
      setNotice("Module created.");
    }
    setModuleEditor(null);
  }

  async function deleteChapter(chapter: Chapter) {
    if (!subjectId || !window.confirm(`Delete "${chapter.title}"? This cannot be undone.`)) return;
    try {
      await repository.deleteChapter(subjectId, chapter.id);
      setNotice(`${structureSingular} deleted.`);
    } catch (nextError) { setError(errorMessage(nextError)); }
  }

  async function deleteTopic(topic: Topic) {
    if (!subjectId || !selectedChapterId || !window.confirm(`Delete "${topic.title}" and all of its draft content? This cannot be undone.`)) return;
    try {
      await repository.deleteTopic(subjectId, selectedChapterId, topic.id);
      setNotice("Topic deleted.");
    } catch (nextError) { setError(errorMessage(nextError)); }
  }

  async function deleteModule(module: LearningModule) {
    if (!moduleLocation || !window.confirm(`Delete "${module.title}"? This cannot be undone.`)) return;
    try {
      await repository.deleteModule(moduleLocation, module.id);
      setNotice("Module deleted.");
      setModuleEditor(null);
      setStructuredModuleId(null);
    } catch (nextError) { setError(errorMessage(nextError)); }
  }

  async function publishModule(module: LearningModule) {
    if (!moduleLocation) return;
    try {
      await repository.publishModule(moduleLocation, module.id);
      setNotice("Module activated with its curriculum parents.");
    } catch (nextError) { setError(errorMessage(nextError)); }
  }

  function moduleWorkspace() {
    if (!moduleLocation) return <div className="panel text-center text-sm text-slate-500">{isLanguageSubject ? "Select or create a topic to manage learning modules." : `Select or create a ${structureSingular.toLowerCase()} to manage modules.`}</div>;
    if (moduleEditor) return <ModuleForm statusOptions={contentStatusOptions(access.role, moduleEditor === "new" ? undefined : moduleEditor.status)} module={moduleEditor === "new" ? undefined : moduleEditor} key={moduleEditor === "new" ? `new-${moduleLocation.chapterId}-${moduleLocation.topicId ?? "root"}` : moduleEditor.id} onCancel={() => setModuleEditor(null)} onSave={saveModule} />;
    if (structuredModule) return <StructuredModuleEditor location={moduleLocation} module={structuredModule} onBack={() => setStructuredModuleId(null)} onEditDetails={() => { setModuleEditor(structuredModule); setStructuredModuleId(null); }} onPublish={() => publishModule(structuredModule)} canActivate={structuredModule.status === "draft"} canEdit={isAdmin || structuredModule.status === "draft"} canManageStatus={isAdmin} repository={structuredRepository} />;
    return <div className="panel">
      <div className="flex flex-wrap items-start justify-between gap-4"><div><p className="eyebrow">{isLanguageSubject ? `TOPIC / ${selectedTopic?.title ?? ""}` : `${structureSingular.toUpperCase()} ${selectedChapter?.chapterNumber ?? ""}`}</p><h2 className="mt-1 text-xl font-bold text-[#293930]">Learning modules</h2><p className="mt-1 text-sm text-slate-500">{selectedTopic?.title ?? selectedChapter?.title}</p></div><button className="primary-button" onClick={() => setModuleEditor("new")} type="button">Add module</button></div>
      <div className="mt-6 space-y-3">
        {modules.map((module) => <article className="rounded-2xl border border-[#e8ebe7] p-4" key={module.id}>
          <button className="w-full text-left" onClick={() => setStructuredModuleId(module.id)} type="button"><div className="flex flex-wrap items-start justify-between gap-3"><div><p className="text-xs font-semibold uppercase tracking-wide text-[#668071]">{titleCase(module.type)} / {module.estimatedMinutes} min</p><h3 className="mt-1 font-bold text-[#293930]">{module.title}</h3><p className="mt-2 text-sm font-medium text-[#60766a]"><ModuleCompletionCount location={moduleLocation} module={module} repository={structuredRepository} /></p></div><Status value={module.status} /></div></button>
          <div className="mt-4 flex flex-wrap gap-2 border-t border-[#e8ebe7] pt-3">{(isAdmin || module.status === "draft") && <button className="small-button" onClick={() => setModuleEditor(module)} type="button">Edit</button>}{module.status === "draft" && <button className="small-button" onClick={() => publishModule(module)} type="button">Activate</button>}{(isAdmin || module.status === "draft") && <button className="small-button danger" onClick={() => deleteModule(module)} type="button">Delete</button>}</div>
        </article>)}
        {!modules.length && <p className="rounded-2xl bg-[#f7f8f6] px-4 py-7 text-center text-sm text-slate-500">No learning modules here yet.</p>}
      </div>
    </div>;
  }

  if (!subjectId) return <section><p className="eyebrow">CONTENT STUDIO / FORM 2</p><h1 className="page-title">All subjects</h1><p className="page-description">Build learning content within the verified KSSM structure.</p>{subjectError && <p className="error-banner">{subjectError}</p>}<div className="mt-8 grid gap-4 sm:grid-cols-2 xl:grid-cols-3">{visibleSubjects.map((subject) => <article className="panel flex min-h-44 flex-col" key={subject.id}><div className="mb-5 h-2 w-14 rounded-full" style={{ backgroundColor: subject.themeColor || "#7B8F72" }} /><h2 className="text-lg font-bold text-[#293930]">{subject.displayName}</h2><p className="mt-1 text-sm text-slate-500">{subject.shortName}</p><div className="mt-auto pt-6"><button className="primary-button w-full" onClick={() => openSubject(subject.id)} type="button">Open content</button></div></article>)}{!visibleSubjects.length && !subjectError && <div className="panel text-sm text-slate-500">No subjects are available.</div>}</div></section>;

  const setupActionAvailable = setupStatus && setupStatus.migration.state !== "blocked" && (setupStatus.missing > 0 || setupStatus.migration.state === "replaceable");

  return <section>
    <button className="mb-5 text-sm font-semibold text-[#496a5a] hover:underline" onClick={() => setSubjectId(null)} type="button">Back to all Form 2 subjects</button>
    <p className="eyebrow">CONTENT STUDIO / FORM 2 / {selectedSubject?.shortName ?? subjectId}</p>
    <div className="flex flex-wrap items-end justify-between gap-4"><div><h1 className="page-title">{selectedSubject?.displayName ?? subjectId}</h1><p className="page-description">Create draft learning content within the verified curriculum structure.</p></div>{isAdmin && setupPresentation?.showAddAction && <button className="primary-button" onClick={() => { setChapterEditor("new"); setTopicEditor(null); }} type="button">{setupPresentation.addLabel}</button>}</div>

    {isAdmin && setupStatus && <div className="mt-6 rounded-2xl border border-[#dfe7e1] bg-white/80 px-5 py-4">
      <div className="flex flex-wrap items-center justify-between gap-4"><div><p className="text-sm font-bold text-[#293930]">{setupPresentation?.heading}</p>{setupStatus.unexpectedIds.length > 0 && setupStatus.state !== "migrationRequired" && <p className="mt-1 text-xs text-slate-500">{setupStatus.unexpectedIds.length} additional document{setupStatus.unexpectedIds.length === 1 ? "" : "s"} detected and preserved.</p>}</div>{setupActionAvailable && setupPresentation?.migrationActionLabel && <button className="secondary-button" onClick={() => setShowSetupPreview(true)} type="button">{setupPresentation.migrationActionLabel}</button>}{setupActionAvailable && !setupPresentation?.migrationActionLabel && <button className="secondary-button" onClick={() => setShowSetupPreview(true)} type="button">{setupStatus.state === "partiallyConfigured" ? "Complete setup" : "Set up curriculum"}</button>}</div>
      {setupStatus.state === "migrationRequired" && <div className="mt-4 grid gap-3 sm:grid-cols-2"><div className="rounded-xl bg-[#f7f8f6] p-4"><p className="text-xs font-bold uppercase tracking-wide text-[#668071]">Current structure</p><p className="mt-1 font-bold text-[#293930]">{setupStatus.migration.legacyDocuments.length} legacy Units</p></div><div className="rounded-xl bg-[#f0f5f1] p-4"><p className="text-xs font-bold uppercase tracking-wide text-[#668071]">New structure</p><p className="mt-1 font-bold text-[#293930]">{setupDefinition?.items.length} {structurePlural}</p><p className="mt-1 text-sm text-slate-600">{setupDefinition?.items.map((item) => item.chapter.title).join(", ")}</p></div></div>}
      {setupStatus.migration.state === "blocked" && <div className="error-banner mt-4"><p>Textbook-unit documents contain authored content. Automatic replacement is disabled.</p><ul className="mt-2 list-disc pl-5">{setupStatus.migration.authoredLegacyDocuments.map((item) => <li key={item.id}>{item.id}: {item.title}</li>)}</ul></div>}
    </div>}

    {(error || subjectError) && <p className="error-banner">{error || subjectError}</p>}{notice && <p className="notice-banner mt-5" aria-live="polite">{notice}</p>}

    {chapterEditor ? <div className="mt-8"><ChapterForm chapter={chapterEditor === "new" ? undefined : chapterEditor} structureSingular={structureSingular} key={chapterEditor === "new" ? "new" : chapterEditor.id} onCancel={() => setChapterEditor(null)} onSave={saveChapter} /></div> : <div className="mt-8 grid gap-6 xl:grid-cols-[minmax(18rem,0.8fr)_minmax(0,1.4fr)]">
      <section className="panel h-fit"><div className="mb-5 flex items-center justify-between"><h2 className="text-xl font-bold text-[#293930]">{structurePlural}</h2><span className="status-pill bg-[#edf3ef] text-[#496a5a]">{displayedChapters.length}</span></div><div className="space-y-3">{displayedChapters.map((chapter) => <article className={`rounded-2xl border p-4 ${selectedChapterId === chapter.id ? "border-[#70917f] bg-[#f4f8f5]" : "border-[#e8ebe7]"}`} key={chapter.id}><button className="w-full text-left" onClick={() => selectChapter(chapter.id)} type="button"><div className="flex items-start justify-between gap-3"><div><p className="text-xs font-semibold uppercase tracking-wide text-[#668071]">{structureSingular} {chapter.chapterNumber}</p><h3 className="mt-1 font-bold text-[#293930]">{chapter.title}</h3></div><Status value={chapter.status} /></div></button>{isAdmin && <div className="mt-4 flex flex-wrap gap-2 border-t border-[#e3e9e5] pt-3"><button className="small-button" onClick={() => setChapterEditor(chapter)} type="button">Edit</button>{chapter.status !== "active" && <button className="small-button" onClick={() => repository.publishChapter(subjectId, chapter.id)} type="button">Publish</button>}<button className="small-button" disabled={chapter.status === "archived"} onClick={() => repository.archiveChapter(subjectId, chapter.id)} type="button">Archive</button><button className="small-button danger" onClick={() => deleteChapter(chapter)} type="button">Delete</button></div>}</article>)}{!displayedChapters.length && <p className="rounded-2xl bg-[#f7f8f6] px-4 py-7 text-center text-sm text-slate-500">No {structurePlural.toLowerCase()} are configured yet.</p>}</div></section>
      <section className="space-y-6">{!selectedChapter ? <div className="panel text-center text-sm text-slate-500">Select or create a {structureSingular.toLowerCase()}.</div> : isLanguageSubject && topicEditor ? <TopicForm topic={topicEditor === "new" ? undefined : topicEditor} key={topicEditor === "new" ? `new-${selectedChapter.id}` : topicEditor.id} onCancel={() => setTopicEditor(null)} onSave={saveTopic} /> : <>{isLanguageSubject && <div className="panel"><div className="mb-5 flex flex-wrap items-center justify-between gap-3"><div><p className="eyebrow">{selectedChapter.title}</p><h2 className="mt-1 text-xl font-bold text-[#293930]">Topics</h2></div>{isAdmin && <button className="primary-button" onClick={() => setTopicEditor("new")} type="button">Add topic</button>}</div><div className="space-y-3">{topics.map((topic) => <article className={`rounded-2xl border p-4 ${selectedTopicId === topic.id ? "border-[#70917f] bg-[#f4f8f5]" : "border-[#e8ebe7]"}`} key={topic.id}><button className="w-full text-left" onClick={() => selectTopic(topic.id)} type="button"><div className="flex items-start justify-between gap-3"><div><p className="text-xs font-semibold uppercase tracking-wide text-[#668071]">Topic {topic.order}</p><h3 className="mt-1 font-bold text-[#293930]">{topic.title}</h3></div><Status value={topic.status} /></div></button>{isAdmin && <div className="mt-4 flex flex-wrap gap-2 border-t border-[#e3e9e5] pt-3"><button className="small-button" onClick={() => setTopicEditor(topic)} type="button">Edit</button>{topic.status !== "active" && <button className="small-button" onClick={() => repository.setTopicStatus(subjectId, selectedChapter.id, topic.id, "active")} type="button">Publish</button>}<button className="small-button" disabled={topic.status === "archived"} onClick={() => repository.setTopicStatus(subjectId, selectedChapter.id, topic.id, "archived")} type="button">Archive</button><button className="small-button danger" onClick={() => deleteTopic(topic)} type="button">Delete</button></div>}</article>)}{!topics.length && <p className="rounded-2xl bg-[#f7f8f6] px-4 py-7 text-center text-sm text-slate-500">No topics in this section yet.</p>}</div></div>}{moduleWorkspace()}</>}</section>
    </div>}

    {showSetupPreview && setupDefinition && setupStatus && selectedSubject && <CurriculumSetupDialog definition={setupDefinition} onCancel={() => setShowSetupPreview(false)} onConfirm={setupCurriculum} saving={isSettingUp} status={setupStatus} subjectName={selectedSubject.displayName} />}
  </section>;
}

function Status({ value }: { value: string }) { const style = value === "active" ? "bg-emerald-50 text-emerald-700" : value === "archived" ? "bg-stone-100 text-stone-500" : "bg-amber-50 text-amber-700"; return <span className={`status-pill ${style}`}>{titleCase(value)}</span>; }
function titleCase(value: string) { return value.charAt(0).toUpperCase() + value.slice(1).replaceAll("_", " "); }
function errorMessage(error: unknown) { return error instanceof Error ? error.message : "The operation could not be completed."; }
