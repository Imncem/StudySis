"use client";

import { FormEvent, useEffect, useMemo, useState } from "react";
import { answerLabel, answerLetters, isAnswerIndex, normalizeQuizOptions, quizQuestionMetadata, type QuizValidationErrors, validateQuizQuestionForm } from "@/components/content-studio/quiz-editor-utils";
import type { StructuredContentRepository } from "@/lib/repositories/structured-content-repository";
import {
  moduleDifficulties,
  moduleStatuses,
  type Flashcard,
  type FlashcardInput,
  type LearningModule,
  type ModuleDifficulty,
  type ModuleStatus,
  type NoteSection,
  type NoteSectionInput,
  type PracticeItem,
  type PracticeItemInput,
  type QuizQuestion,
  type QuizQuestionInput,
} from "@/lib/types";

type Location = { subjectId: string; chapterId: string; moduleId: string };

export function StructuredModuleEditor({ repository, subjectId, chapterId, module, onBack, onEditDetails, onPublish }: { repository: StructuredContentRepository; subjectId: string; chapterId: string; module: LearningModule; onBack: () => void; onEditDetails: () => void; onPublish: () => Promise<void> }) {
  const location = useMemo(
    () => ({ subjectId, chapterId, moduleId: module.id }),
    [chapterId, module.id, subjectId],
  );
  return (
    <div className="panel">
      <div className="flex flex-wrap items-start justify-between gap-4 border-b border-[#e6ebe7] pb-5">
        <div>
          <button className="mb-3 text-sm font-semibold text-[#496a5a] hover:underline" onClick={onBack} type="button">← Module list</button>
          <p className="eyebrow">{module.type.toUpperCase()} EDITOR</p>
          <h2 className="mt-1 text-2xl font-bold text-[#293930]">{module.title}</h2>
        </div>
        <div className="flex flex-wrap gap-2">
          <button className="secondary-button" onClick={onEditDetails} type="button">Edit details</button>
          {module.status !== "active" && <button className="primary-button" onClick={onPublish} type="button">Publish module</button>}
        </div>
      </div>
      <div className="pt-6">
        {module.type === "notes" && <NotesEditor location={location} repository={repository} />}
        {module.type === "flashcards" && <FlashcardsEditor location={location} repository={repository} />}
        {module.type === "practice" && <PracticeEditor location={location} repository={repository} />}
        {module.type === "quiz" && <QuizEditor location={location} repository={repository} />}
        {module.type === "test" && <Placeholder text="Test builder coming later" />}
        {module.type === "review" && <Placeholder text="Review engine coming later" />}
      </div>
    </div>
  );
}

function NotesEditor({ repository, location }: EditorProps) {
  const [items, setItems] = useState<NoteSection[]>([]);
  const [editing, setEditing] = useState<NoteSection | "new" | null>(null);
  const [error, setError] = useState("");
  useEffect(() => repository.watchNoteSections(location, setItems, (next) => setError(next.message)), [location, repository]);

  async function save(input: NoteSectionInput) {
    if (editing && editing !== "new") await repository.updateNoteSection(location, editing.id, input);
    else await repository.createNoteSection(location, input);
    setEditing(null);
  }

  return <CollectionLayout title="Note sections" count={items.length} addLabel="Add section" onAdd={() => setEditing("new")} error={error}>
    {editing && <NoteSectionForm item={editing === "new" ? undefined : editing} onCancel={() => setEditing(null)} onSave={save} />}
    {!editing && items.map((item) => <ItemCard key={item.id} eyebrow={`SECTION ${item.order}`} title={item.heading} description={item.body} onEdit={() => setEditing(item)} onDelete={() => confirmDelete(item.heading) && repository.deleteNoteSection(location, item.id)} />)}
    {!editing && !items.length && <Empty text="No note sections yet." />}
  </CollectionLayout>;
}

function FlashcardsEditor({ repository, location }: EditorProps) {
  const [items, setItems] = useState<Flashcard[]>([]);
  const [editing, setEditing] = useState<Flashcard | "new" | null>(null);
  const [error, setError] = useState("");
  useEffect(() => repository.watchFlashcards(location, setItems, (next) => setError(next.message)), [location, repository]);
  async function save(input: FlashcardInput) { if (editing && editing !== "new") await repository.updateFlashcard(location, editing.id, input); else await repository.createFlashcard(location, input); setEditing(null); }
  return <CollectionLayout title="Flashcards" count={items.length} addLabel="Add flashcard" onAdd={() => setEditing("new")} error={error}>
    {editing && <FlashcardForm item={editing === "new" ? undefined : editing} onCancel={() => setEditing(null)} onSave={save} />}
    {!editing && items.map((item) => <ItemCard key={item.id} eyebrow={`${item.status} · CARD ${item.order}`} title={item.front} description={item.back} onEdit={() => setEditing(item)} onDelete={() => confirmDelete(item.front) && repository.deleteFlashcard(location, item.id)} />)}
    {!editing && !items.length && <Empty text="No flashcards yet." />}
  </CollectionLayout>;
}

function PracticeEditor({ repository, location }: EditorProps) {
  const [items, setItems] = useState<PracticeItem[]>([]);
  const [editing, setEditing] = useState<PracticeItem | "new" | null>(null);
  const [error, setError] = useState("");
  useEffect(() => repository.watchPracticeItems(location, setItems, (next) => setError(next.message)), [location, repository]);
  async function save(input: PracticeItemInput) { if (editing && editing !== "new") await repository.updatePracticeItem(location, editing.id, input); else await repository.createPracticeItem(location, input); setEditing(null); }
  return <CollectionLayout title="Practice questions" count={items.length} addLabel="Add question" onAdd={() => setEditing("new")} error={error}>
    {editing && <PracticeForm item={editing === "new" ? undefined : editing} onCancel={() => setEditing(null)} onSave={save} />}
    {!editing && items.map((item) => <ItemCard key={item.id} eyebrow={`${item.status} · ${item.difficulty} · ${item.order}`} title={item.question} description={`${item.options.filter(Boolean).length} options · correct ${answerLabel(item.correctAnswerIndex)}${item.topic ? ` · ${item.topic}` : ""}`} onEdit={() => setEditing(item)} onDelete={() => confirmDelete(item.question) && repository.deletePracticeItem(location, item.id)} />)}
    {!editing && !items.length && <Empty text="No practice questions yet." />}
  </CollectionLayout>;
}

function QuizEditor({ repository, location }: EditorProps) {
  const [items, setItems] = useState<QuizQuestion[]>([]);
  const [editing, setEditing] = useState<QuizQuestion | "new" | null>(null);
  const [error, setError] = useState("");
  useEffect(() => repository.watchQuizQuestions(location, setItems, (next) => setError(next.message)), [location, repository]);
  async function save(input: QuizQuestionInput) { if (editing && editing !== "new") await repository.updateQuizQuestion(location, editing.id, input); else await repository.createQuizQuestion(location, input); setEditing(null); }
  return <CollectionLayout title="Quiz questions" count={items.length} addLabel="New Question" onAdd={() => setEditing("new")} error={error}>
    {editing && <QuizForm item={editing === "new" ? undefined : editing} onCancel={() => setEditing(null)} onSave={save} />}
    {!editing && items.map((item) => <QuizQuestionCard key={item.id} item={item} onEdit={() => setEditing(item)} onDelete={() => confirmDelete(item.question) && repository.deleteQuizQuestion(location, item.id)} />)}
    {!editing && !items.length && <Empty text="No quiz questions yet." />}
  </CollectionLayout>;
}

type EditorProps = { repository: StructuredContentRepository; location: Location };

function CollectionLayout({ title, count, addLabel, onAdd, error, children }: { title: string; count: number; addLabel: string; onAdd: () => void; error: string; children: React.ReactNode }) {
  return <div><div className="mb-5 flex flex-wrap items-center justify-between gap-3"><div><h3 className="text-xl font-bold text-[#293930]">{title}</h3><p className="mt-1 text-sm text-slate-500">{count} total</p></div><button className="primary-button" onClick={onAdd} type="button">{addLabel}</button></div>{error && <p className="error-banner">{error}</p>}<div className="space-y-3">{children}</div></div>;
}

function ItemCard({ eyebrow, title, description, onEdit, onDelete }: { eyebrow: string; title: string; description: string; onEdit: () => void; onDelete: () => void }) {
  return <article className="rounded-2xl border border-[#e5eae6] p-4"><p className="text-xs font-semibold uppercase tracking-wide text-[#668071]">{eyebrow}</p><h4 className="mt-1 font-bold text-[#293930]">{title}</h4><p className="mt-2 line-clamp-2 whitespace-pre-line text-sm text-slate-500">{description}</p><div className="mt-4 flex gap-2 border-t border-[#e8ebe7] pt-3"><button className="small-button" onClick={onEdit} type="button">Edit</button><button className="small-button danger" onClick={onDelete} type="button">Delete</button></div></article>;
}

function QuizQuestionCard({ item, onEdit, onDelete }: { item: QuizQuestion; onEdit: () => void; onDelete: () => void }) {
  return <article className="rounded-2xl border border-[#e5eae6] bg-white p-4">
    <div className="flex flex-wrap items-start justify-between gap-3">
      <div>
        <p className="text-xs font-semibold uppercase tracking-wide text-[#668071]">Question {item.order}</p>
        <h4 className="mt-1 font-bold text-[#293930]">{item.question}</h4>
      </div>
      <div className="flex flex-wrap gap-2">
        <Badge>{titleCase(item.difficulty)}</Badge>
        <Badge>{titleCase(item.status)}</Badge>
      </div>
    </div>
    <p className="mt-3 text-sm font-semibold text-[#496a5a]">{quizQuestionMetadata(item)}</p>
    <div className="mt-4 flex gap-2 border-t border-[#e8ebe7] pt-3"><button className="small-button" onClick={onEdit} type="button">Edit</button><button className="small-button danger" onClick={onDelete} type="button">Delete</button></div>
  </article>;
}

function Badge({ children }: { children: React.ReactNode }) {
  return <span className="rounded-full border border-[#dce6df] bg-[#f5f8f6] px-2.5 py-1 text-xs font-bold text-[#40534a]">{children}</span>;
}

function NoteSectionForm({ item, onSave, onCancel }: { item?: NoteSection; onSave: (input: NoteSectionInput) => Promise<void>; onCancel: () => void }) {
  const [heading, setHeading] = useState(item?.heading ?? ""); const [body, setBody] = useState(item?.body ?? ""); const [example, setExample] = useState(item?.example ?? ""); const [order, setOrder] = useState(item?.order ?? 1);
  return <SimpleForm onSubmit={() => onSave({ heading: heading.trim(), body: body.trim(), example: example.trim(), order })} onCancel={onCancel}><Field label="Heading" value={heading} setValue={setHeading} /><TextField label="Body" value={body} setValue={setBody} /><TextField label="Example" value={example} setValue={setExample} /><NumberField label="Order" value={order} setValue={setOrder} /></SimpleForm>;
}

function FlashcardForm({ item, onSave, onCancel }: { item?: Flashcard; onSave: (input: FlashcardInput) => Promise<void>; onCancel: () => void }) {
  const [front, setFront] = useState(item?.front ?? ""); const [back, setBack] = useState(item?.back ?? ""); const [hint, setHint] = useState(item?.hint ?? ""); const [order, setOrder] = useState(item?.order ?? 1); const [status, setStatus] = useState<ModuleStatus>(item?.status ?? "draft");
  return <SimpleForm onSubmit={() => onSave({ front: front.trim(), back: back.trim(), hint: hint.trim(), order, status })} onCancel={onCancel}><TextField label="Front" value={front} setValue={setFront} /><TextField label="Back" value={back} setValue={setBack} /><Field label="Hint" value={hint} setValue={setHint} required={false} /><NumberField label="Order" value={order} setValue={setOrder} /><StatusField value={status} setValue={setStatus} /></SimpleForm>;
}

function PracticeForm({ item, onSave, onCancel }: { item?: PracticeItem; onSave: (input: PracticeItemInput) => Promise<void>; onCancel: () => void }) {
  const initialOptions = normalizePracticeOptions(item);
  const [question, setQuestion] = useState(item?.question ?? "");
  const [optionA, setOptionA] = useState(initialOptions[0]);
  const [optionB, setOptionB] = useState(initialOptions[1]);
  const [optionC, setOptionC] = useState(initialOptions[2]);
  const [optionD, setOptionD] = useState(initialOptions[3]);
  const [correctAnswerIndex, setCorrectAnswerIndex] = useState(item?.correctAnswerIndex ?? 0);
  const [explanation, setExplanation] = useState(item?.explanation ?? "");
  const [hint, setHint] = useState(item?.hint ?? "");
  const [topic, setTopic] = useState(item?.topic ?? "");
  const [difficulty, setDifficulty] = useState<ModuleDifficulty>(item?.difficulty ?? "easy");
  const [order, setOrder] = useState(item?.order ?? 1);
  const [status, setStatus] = useState<ModuleStatus>(item?.status ?? "draft");
  async function save() {
    const options = [optionA, optionB, optionC, optionD].map((value) => value.trim());
    if (options.some((value) => !value)) throw new Error("Add all four answer options.");
    if (correctAnswerIndex < 0 || correctAnswerIndex > 3) throw new Error("Choose the correct answer.");
    await onSave({ question: question.trim(), options, correctAnswerIndex, explanation: explanation.trim(), hint: hint.trim(), topic: topic.trim(), difficulty, order, status });
  }
  return <SimpleForm onSubmit={save} onCancel={onCancel}><TextField label="Question" value={question} setValue={setQuestion} /><Field label="Option A" value={optionA} setValue={setOptionA} /><Field label="Option B" value={optionB} setValue={setOptionB} /><Field label="Option C" value={optionC} setValue={setOptionC} /><Field label="Option D" value={optionD} setValue={setOptionD} /><CorrectAnswerField value={correctAnswerIndex} setValue={setCorrectAnswerIndex} /><Field label="Topic tag" value={topic} setValue={setTopic} required={false} /><TextField label="Explanation" value={explanation} setValue={setExplanation} /><Field label="Hint" value={hint} setValue={setHint} required={false} /><DifficultyField value={difficulty} setValue={setDifficulty} /><NumberField label="Order" value={order} setValue={setOrder} /><StatusField value={status} setValue={setStatus} /></SimpleForm>;
}

function QuizForm({ item, onSave, onCancel }: { item?: QuizQuestion; onSave: (input: QuizQuestionInput) => Promise<void>; onCancel: () => void }) {
  const initialOptions = normalizeQuizOptions(item);
  const [question, setQuestion] = useState(item?.question ?? "");
  const [optionA, setOptionA] = useState(initialOptions[0]);
  const [optionB, setOptionB] = useState(initialOptions[1]);
  const [optionC, setOptionC] = useState(initialOptions[2]);
  const [optionD, setOptionD] = useState(initialOptions[3]);
  const [correctOptionIndex, setCorrectOptionIndex] = useState<number | null>(isAnswerIndex(item?.correctOptionIndex) ? item.correctOptionIndex : null);
  const [explanation, setExplanation] = useState(item?.explanation ?? "");
  const [difficulty, setDifficulty] = useState<ModuleDifficulty>(item?.difficulty ?? "easy");
  const [order, setOrder] = useState(String(item?.order ?? 1));
  const [status, setStatus] = useState<ModuleStatus>(item?.status ?? "draft");
  const [errors, setErrors] = useState<QuizValidationErrors>({});
  const [saving, setSaving] = useState(false);
  const options = [optionA, optionB, optionC, optionD];

  async function submit(event: FormEvent) {
    event.preventDefault();
    if (saving) return;
    const result = validateQuizQuestionForm({ question, options, correctOptionIndex, explanation, difficulty, order, status });
    setErrors(result.errors);
    if (!result.input) return;
    setSaving(true);
    try {
      await onSave(result.input);
    } catch (next) {
      setErrors({ form: next instanceof Error ? next.message : "Could not save this question." });
    } finally {
      setSaving(false);
    }
  }

  return <form className="rounded-2xl bg-[#f5f8f6] p-5" noValidate onSubmit={submit}>
    <div className="grid gap-5 xl:grid-cols-[minmax(0,1fr)_20rem]">
      <div className="space-y-6">
        <FormSection title="Question">
          <QuizTextArea error={errors.question} label="Question" placeholder="Enter the quiz question here..." value={question} onChange={setQuestion} />
        </FormSection>
        <FormSection title="Answer Choices">
          <div className="grid gap-4 md:grid-cols-2">
            <QuizOptionField error={errors.optionA} label="Option A" value={optionA} onChange={setOptionA} />
            <QuizOptionField error={errors.optionB} label="Option B" value={optionB} onChange={setOptionB} />
            <QuizOptionField error={errors.optionC} label="Option C" value={optionC} onChange={setOptionC} />
            <QuizOptionField error={errors.optionD} label="Option D" value={optionD} onChange={setOptionD} />
          </div>
        </FormSection>
        <FormSection title="Correct Answer">
          <fieldset>
            <legend className="sr-only">Correct Answer</legend>
            <div className="flex flex-wrap gap-3">
              {answerLetters.map((letter, index) => <label key={letter} className={`flex min-w-20 cursor-pointer items-center gap-2 rounded-xl border px-3 py-2 text-sm font-bold ${correctOptionIndex === index ? "border-[#496a5a] bg-white text-[#293930] shadow-sm" : "border-[#dce2de] bg-white/70 text-[#40534a]"}`}>
                <input checked={correctOptionIndex === index} name="quiz-correct-answer" type="radio" onChange={() => setCorrectOptionIndex(index)} />
                {letter}
              </label>)}
            </div>
            <InlineError message={errors.correctOptionIndex} />
          </fieldset>
        </FormSection>
        <FormSection title="Explanation">
          <QuizTextArea error={errors.explanation} helper="This explanation will be shown after the student completes the quiz." label="Explanation" value={explanation} onChange={setExplanation} />
        </FormSection>
        <FormSection title="Quiz Settings">
          <div className="grid gap-4 md:grid-cols-3">
            <QuizSelect error={errors.difficulty} label="Difficulty" value={difficulty} values={moduleDifficulties} onChange={(value) => setDifficulty(value as ModuleDifficulty)} />
            <QuizNumberInput error={errors.order} label="Order" value={order} onChange={setOrder} />
            <QuizSelect error={errors.status} label="Status" value={status} values={moduleStatuses} onChange={(value) => setStatus(value as ModuleStatus)} />
          </div>
        </FormSection>
      </div>
      <QuizStudentPreview correctOptionIndex={correctOptionIndex} options={options} question={question} />
    </div>
    {errors.form && <p className="error-banner">{errors.form}</p>}
    <div className="mt-6 flex flex-wrap gap-3">
      <button className="primary-button" disabled={saving} type="submit">{saving ? "Saving..." : "Save Question"}</button>
      <button className="secondary-button" disabled={saving} onClick={onCancel} type="button">Cancel</button>
    </div>
  </form>;
}

function FormSection({ title, children }: { title: string; children: React.ReactNode }) {
  return <section>
    <h4 className="mb-3 text-base font-bold text-[#293930]">{title}</h4>
    {children}
  </section>;
}

function QuizOptionField({ label, value, onChange, error }: { label: string; value: string; onChange: (value: string) => void; error?: string }) {
  return <label className="field-label">
    <span className="mb-2 flex items-center gap-2"><span className="rounded-lg bg-[#e7efe9] px-2 py-1 text-xs font-bold text-[#496a5a]">{label.slice(-1)}</span>{label}</span>
    <input className="field" value={value} onChange={(event) => onChange(event.target.value)} />
    <InlineError message={error} />
  </label>;
}

function QuizTextArea({ label, value, onChange, error, helper, placeholder }: { label: string; value: string; onChange: (value: string) => void; error?: string; helper?: string; placeholder?: string }) {
  return <label className="field-label block">
    {label}
    <textarea className="field mt-2 min-h-32 resize-y" placeholder={placeholder} value={value} onChange={(event) => onChange(event.target.value)} />
    {helper && <span className="mt-2 block text-xs font-medium text-slate-500">{helper}</span>}
    <InlineError message={error} />
  </label>;
}

function QuizNumberInput({ label, value, onChange, error }: { label: string; value: string; onChange: (value: string) => void; error?: string }) {
  return <label className="field-label">
    {label}
    <input className="field mt-2" min={0} type="number" value={value} onChange={(event) => onChange(event.target.value)} />
    <InlineError message={error} />
  </label>;
}

function QuizSelect({ label, value, values, onChange, error }: { label: string; value: string; values: readonly string[]; onChange: (value: string) => void; error?: string }) {
  return <label className="field-label">
    {label}
    <select className="field mt-2" value={value} onChange={(event) => onChange(event.target.value)}>
      {values.map((next) => <option key={next} value={next}>{titleCase(next)}</option>)}
    </select>
    <InlineError message={error} />
  </label>;
}

function QuizStudentPreview({ question, options, correctOptionIndex }: { question: string; options: string[]; correctOptionIndex: number | null }) {
  return <aside className="rounded-2xl border border-[#dce6df] bg-white p-4 xl:sticky xl:top-4 xl:self-start">
    <p className="text-xs font-semibold uppercase tracking-wide text-[#668071]">Student Preview</p>
    <h4 className="mt-3 whitespace-pre-wrap text-base font-bold text-[#293930]">{question.trim() || "Question text will appear here."}</h4>
    <div className="mt-4 space-y-2">
      {answerLetters.map((letter, index) => <div key={letter} className={`rounded-xl border px-3 py-2 text-sm ${correctOptionIndex === index ? "border-[#496a5a] bg-[#f0f5f1] text-[#293930]" : "border-[#e5eae6] text-[#40534a]"}`}>
        <span className="font-bold">{letter}.</span> {options[index]?.trim() || `Option ${letter}`}
        {correctOptionIndex === index && <span className="ml-2 text-xs font-bold text-[#496a5a]">Correct</span>}
      </div>)}
    </div>
  </aside>;
}

function InlineError({ message }: { message?: string }) {
  if (!message) return null;
  return <span className="mt-2 block text-xs font-bold text-[#b42318]">{message}</span>;
}

function SimpleForm({ onSubmit, onCancel, children }: { onSubmit: () => Promise<void>; onCancel: () => void; children: React.ReactNode }) {
  const [saving, setSaving] = useState(false); const [error, setError] = useState("");
  async function submit(event: FormEvent) { event.preventDefault(); setSaving(true); setError(""); try { await onSubmit(); } catch (next) { setError(next instanceof Error ? next.message : "Could not save this item."); } finally { setSaving(false); } }
  return <form className="rounded-2xl bg-[#f5f8f6] p-5" onSubmit={submit}><div className="grid gap-4 sm:grid-cols-2">{children}</div>{error && <p className="error-banner">{error}</p>}<div className="mt-5 flex gap-3"><button className="primary-button" disabled={saving} type="submit">{saving ? "Saving…" : "Save"}</button><button className="secondary-button" onClick={onCancel} type="button">Cancel</button></div></form>;
}

function Field({ label, value, setValue, required = true }: { label: string; value: string; setValue: (value: string) => void; required?: boolean }) { return <label className="field-label">{label}<input className="field mt-2" required={required} value={value} onChange={(event) => setValue(event.target.value)} /></label>; }
function TextField({ label, value, setValue }: { label: string; value: string; setValue: (value: string) => void }) { return <label className="field-label sm:col-span-2">{label}<textarea className="field mt-2 min-h-28 resize-y" required value={value} onChange={(event) => setValue(event.target.value)} /></label>; }
function NumberField({ label, value, setValue, min = 1 }: { label: string; value: number; setValue: (value: number) => void; min?: number }) { return <label className="field-label">{label}<input className="field mt-2" type="number" min={min} required value={value} onChange={(event) => setValue(Number(event.target.value))} /></label>; }
function StatusField({ value, setValue }: { value: ModuleStatus; setValue: (value: ModuleStatus) => void }) { return <label className="field-label">Status<select className="field mt-2" value={value} onChange={(event) => setValue(event.target.value as ModuleStatus)}>{moduleStatuses.map((status) => <option key={status} value={status}>{titleCase(status)}</option>)}</select></label>; }
function DifficultyField({ value, setValue }: { value: ModuleDifficulty; setValue: (value: ModuleDifficulty) => void }) { return <label className="field-label">Difficulty<select className="field mt-2" value={value} onChange={(event) => setValue(event.target.value as ModuleDifficulty)}>{moduleDifficulties.map((difficulty) => <option key={difficulty} value={difficulty}>{titleCase(difficulty)}</option>)}</select></label>; }
function CorrectAnswerField({ value, setValue }: { value: number; setValue: (value: number) => void }) { return <label className="field-label">Correct answer<select className="field mt-2" value={value} onChange={(event) => setValue(Number(event.target.value))}>{["A", "B", "C", "D"].map((label, index) => <option key={label} value={index}>{label}</option>)}</select></label>; }
function Placeholder({ text }: { text: string }) { return <div className="rounded-2xl bg-[#f5f7f5] px-6 py-12 text-center font-semibold text-slate-500">{text}</div>; }
function Empty({ text }: { text: string }) { return <p className="rounded-2xl bg-[#f7f8f6] px-4 py-8 text-center text-sm text-slate-500">{text}</p>; }
function confirmDelete(title: string) { return window.confirm(`Delete “${title}”? This cannot be undone.`); }
function titleCase(value: string) { return value.charAt(0).toUpperCase() + value.slice(1); }
function normalizePracticeOptions(item?: PracticeItem) {
  const options = item?.options?.slice(0, 4) ?? [];
  while (options.length < 4) options.push("");
  if (item?.answer && !options.some(Boolean)) options[0] = item.answer;
  return options as [string, string, string, string];
}
