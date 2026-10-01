import {
  addDoc,
  collection,
  doc,
  getDocs,
  onSnapshot,
  orderBy,
  query,
  runTransaction,
  serverTimestamp,
  updateDoc,
  writeBatch,
  type DocumentData,
  type Firestore,
  type QueryDocumentSnapshot,
  type Unsubscribe,
} from "firebase/firestore";
import {
  getCurriculumSetupDefinition,
  getCurriculumSetupStatus as calculateCurriculumSetupStatus,
  type CurriculumSetupResult,
  type CurriculumSetupStatus,
} from "@/lib/curriculum/curriculumSetup";
import { contentPaths } from "@/lib/content-paths";
import type {
  Chapter,
  ChapterInput,
  LearningModule,
  LearningModuleInput,
  Subject,
} from "@/lib/types";
import { mapSubjectDocument } from "@/lib/repositories/subject-mapper";
import { mapChapterDocument } from "@/lib/repositories/chapter-mapper";

type ErrorHandler = (error: Error) => void;
const structuredCollections = ["sections", "cards", "items", "questions"];

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
            ...mapSubjectDocument(item.id, item.data()),
          })),
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

  async getCurriculumSetupStatus(
    subjectId: string,
  ): Promise<CurriculumSetupStatus> {
    getCurriculumSetupDefinition(subjectId);
    const snapshot = await getDocs(
      collection(this.db, contentPaths.chapters(subjectId)),
    );
    return calculateCurriculumSetupStatus(
      subjectId,
      snapshot.docs.map((item) => item.id),
    );
  }

  async setupCurriculum(subjectId: string): Promise<CurriculumSetupResult> {
    const definition = getCurriculumSetupDefinition(subjectId);
    const references = definition.items.map((item) => ({
      item,
      reference: doc(this.db, contentPaths.chapter(subjectId, item.id)),
    }));

    return runTransaction(this.db, async (transaction) => {
      const snapshots = await Promise.all(
        references.map(({ reference }) => transaction.get(reference)),
      );
      const createdIds: string[] = [];

      snapshots.forEach((snapshot, index) => {
        if (snapshot.exists()) return;
        const { item, reference } = references[index];
        transaction.set(reference, {
          ...item.chapter,
          createdAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        });
        createdIds.push(item.id);
      });

      const existing = definition.items.length - createdIds.length;
      return {
        expected: definition.items.length,
        existing,
        created: createdIds.length,
        skipped: existing,
        createdIds,
      };
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
    const nestedSnapshots = await Promise.all(
      modules.docs.flatMap((module) =>
        structuredCollections.map((collectionName) =>
          getDocs(
            collection(
              this.db,
              contentPaths.moduleContent(
                subjectId,
                chapterId,
                module.id,
                collectionName,
              ),
            ),
          ),
        ),
      ),
    );
    const nestedDocuments = nestedSnapshots.flatMap((snapshot) => snapshot.docs);
    const writeCount = nestedDocuments.length + modules.size + 1;
    if (writeCount > 500) {
      throw new Error("This chapter has too many modules for a safe dashboard deletion.");
    }
    const batch = writeBatch(this.db);
    nestedDocuments.forEach((item) => batch.delete(item.ref));
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
    const nestedSnapshots = await Promise.all(
      structuredCollections.map((collectionName) =>
        getDocs(
          collection(
            this.db,
            contentPaths.moduleContent(
              subjectId,
              chapterId,
              moduleId,
              collectionName,
            ),
          ),
        ),
      ),
    );
    const nestedDocuments = nestedSnapshots.flatMap((snapshot) => snapshot.docs);
    if (nestedDocuments.length >= 500) {
      throw new Error("This module has too much content for a safe dashboard deletion.");
    }
    const batch = writeBatch(this.db);
    nestedDocuments.forEach((item) => batch.delete(item.ref));
    batch.delete(doc(this.db, contentPaths.module(subjectId, chapterId, moduleId)));
    await batch.commit();
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
  return mapChapterDocument(item.id, item.data());
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
