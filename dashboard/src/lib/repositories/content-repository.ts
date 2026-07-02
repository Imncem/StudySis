import {
  addDoc,
  collection,
  deleteDoc,
  doc,
  getDocs,
  onSnapshot,
  orderBy,
  query,
  serverTimestamp,
  updateDoc,
  writeBatch,
  type DocumentData,
  type Firestore,
  type QueryDocumentSnapshot,
  type Unsubscribe,
} from "firebase/firestore";
import { contentPaths } from "@/lib/content-paths";
import type {
  Chapter,
  ChapterInput,
  LearningModule,
  LearningModuleInput,
  Subject,
} from "@/lib/types";

type ErrorHandler = (error: Error) => void;

export class ContentRepository {
  constructor(private readonly db: Firestore) {}

  watchSubjects(
    onData: (subjects: Subject[]) => void,
    onError: ErrorHandler,
  ): Unsubscribe {
    return onSnapshot(
      query(collection(this.db, contentPaths.subjects()), orderBy("order")),
      (snapshot) =>
        onData(
          snapshot.docs.map((item) => ({
            id: item.id,
            ...item.data(),
          }) as Subject),
        ),
      onError,
    );
  }

  watchChapters(
    subjectId: string,
    onData: (chapters: Chapter[]) => void,
    onError: ErrorHandler,
  ): Unsubscribe {
    return onSnapshot(
      query(collection(this.db, contentPaths.chapters(subjectId)), orderBy("order")),
      (snapshot) => onData(snapshot.docs.map(mapChapter)),
      onError,
    );
  }

  watchModules(
    subjectId: string,
    chapterId: string,
    onData: (modules: LearningModule[]) => void,
    onError: ErrorHandler,
  ): Unsubscribe {
    return onSnapshot(
      query(
        collection(this.db, contentPaths.modules(subjectId, chapterId)),
        orderBy("order"),
      ),
      (snapshot) => onData(snapshot.docs.map(mapModule)),
      onError,
    );
  }

  async createChapter(subjectId: string, input: ChapterInput): Promise<void> {
    await addDoc(collection(this.db, contentPaths.chapters(subjectId)), {
      ...input,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
  }

  async updateChapter(
    subjectId: string,
    chapterId: string,
    input: ChapterInput,
  ): Promise<void> {
    await updateDoc(doc(this.db, contentPaths.chapter(subjectId, chapterId)), {
      ...input,
      updatedAt: serverTimestamp(),
    });
  }

  async archiveChapter(subjectId: string, chapterId: string): Promise<void> {
    await updateDoc(doc(this.db, contentPaths.chapter(subjectId, chapterId)), {
      status: "archived",
      updatedAt: serverTimestamp(),
    });
  }

  async publishChapter(subjectId: string, chapterId: string): Promise<void> {
    await updateDoc(doc(this.db, contentPaths.chapter(subjectId, chapterId)), {
      status: "active",
      updatedAt: serverTimestamp(),
    });
  }

  async deleteChapter(subjectId: string, chapterId: string): Promise<void> {
    const modules = await getDocs(
      collection(this.db, contentPaths.modules(subjectId, chapterId)),
    );
    if (modules.size >= 499) {
      throw new Error("This chapter has too many modules for a safe dashboard deletion.");
    }
    const batch = writeBatch(this.db);
    modules.docs.forEach((item) => batch.delete(item.ref));
    batch.delete(doc(this.db, contentPaths.chapter(subjectId, chapterId)));
    await batch.commit();
  }

  async createModule(
    subjectId: string,
    chapterId: string,
    input: LearningModuleInput,
  ): Promise<void> {
    await addDoc(collection(this.db, contentPaths.modules(subjectId, chapterId)), {
      ...input,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
  }

  async updateModule(
    subjectId: string,
    chapterId: string,
    moduleId: string,
    input: LearningModuleInput,
  ): Promise<void> {
    await updateDoc(
      doc(this.db, contentPaths.module(subjectId, chapterId, moduleId)),
      { ...input, updatedAt: serverTimestamp() },
    );
  }

  async deleteModule(
    subjectId: string,
    chapterId: string,
    moduleId: string,
  ): Promise<void> {
    await deleteDoc(
      doc(this.db, contentPaths.module(subjectId, chapterId, moduleId)),
    );
  }

  async publishModule(
    subjectId: string,
    chapterId: string,
    moduleId: string,
  ): Promise<void> {
    const batch = writeBatch(this.db);
    batch.update(doc(this.db, contentPaths.chapter(subjectId, chapterId)), {
      status: "active",
      updatedAt: serverTimestamp(),
    });
    batch.update(
      doc(this.db, contentPaths.module(subjectId, chapterId, moduleId)),
      { status: "active", updatedAt: serverTimestamp() },
    );
    await batch.commit();
  }
}

function mapChapter(item: QueryDocumentSnapshot<DocumentData>): Chapter {
  const data = item.data();
  return {
    id: item.id,
    chapterNumber: data.chapterNumber ?? 0,
    title: data.title ?? "Untitled chapter",
    textbookChapterTitle: data.textbookChapterTitle ?? "",
    learningObjectives: Array.isArray(data.learningObjectives)
      ? data.learningObjectives
      : [],
    estimatedMinutes: data.estimatedMinutes ?? 0,
    status: data.status ?? "draft",
    order: data.order ?? 0,
    createdAt: data.createdAt ?? null,
    updatedAt: data.updatedAt ?? null,
  };
}

function mapModule(item: QueryDocumentSnapshot<DocumentData>): LearningModule {
  const data = item.data();
  return {
    id: item.id,
    title: data.title ?? "Untitled module",
    type: data.type ?? "notes",
    content: data.content ?? "",
    summary: data.summary ?? "",
    estimatedMinutes: data.estimatedMinutes ?? 0,
    difficulty: data.difficulty ?? "medium",
    order: data.order ?? 0,
    status: data.status ?? "draft",
    createdAt: data.createdAt ?? null,
    updatedAt: data.updatedAt ?? null,
  };
}
