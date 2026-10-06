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
import {
  contentPaths,
  type CurriculumContentLocation,
} from "@/lib/content-paths";
import type {
  Chapter,
  ChapterInput,
  LearningModule,
  LearningModuleInput,
  Subject,
  Topic,
  TopicInput,
} from "@/lib/types";
import { mapSubjectDocument } from "@/lib/repositories/subject-mapper";
import { mapChapterDocument } from "@/lib/repositories/chapter-mapper";
import {
  mapTopicDocument,
  prepareNewTopic,
} from "@/lib/repositories/topic-mapper";

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
    location: CurriculumContentLocation,
    onData: (modules: LearningModule[]) => void,
    onError: ErrorHandler,
  ): Unsubscribe {
    return onSnapshot(
      query(
        collection(this.db, contentPaths.modules(location)),
        orderBy("order"),
      ),
      (snapshot) => onData(snapshot.docs.map(mapModule)),
      onError,
    );
  }

  watchTopics(
    subjectId: string,
    chapterId: string,
    onData: (topics: Topic[]) => void,
    onError: ErrorHandler,
  ): Unsubscribe {
    return onSnapshot(
      query(
        collection(this.db, contentPaths.topics(subjectId, chapterId)),
        orderBy("order"),
      ),
      (snapshot) => onData(snapshot.docs.map(mapTopic)),
      onError,
    );
  }

  async createChapter(
    subjectId: string,
    input: ChapterInput,
    documentId?: string,
  ): Promise<void> {
    const data = {
      ...input,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    };
    if (documentId) {
      await runTransaction(this.db, async (transaction) => {
        const reference = doc(this.db, contentPaths.chapter(subjectId, documentId));
        const snapshot = await transaction.get(reference);
        if (snapshot.exists()) throw new Error("A section with this ID already exists.");
        transaction.set(reference, data);
      });
      return;
    }
    await addDoc(collection(this.db, contentPaths.chapters(subjectId)), data);
  }

  async getCurriculumSetupStatus(
    subjectId: string,
  ): Promise<CurriculumSetupStatus> {
    getCurriculumSetupDefinition(subjectId);
    const snapshot = await getDocs(
      collection(this.db, contentPaths.chapters(subjectId)),
    );
    const legacyDocumentTitles = new Map(
      snapshot.docs.map((item) => [
        item.id,
        typeof item.data().title === "string" ? item.data().title : item.id,
      ]),
    );
    const initialStatus = calculateCurriculumSetupStatus(
      subjectId,
      snapshot.docs.map((item) => item.id),
      [],
      legacyDocumentTitles,
    );
    if (initialStatus.migration.state !== "replaceable") return initialStatus;
    const authoredIds = await this.findAuthoredLegacyDocuments(
      subjectId,
      initialStatus.migration.legacyDocumentIds,
    );
    return calculateCurriculumSetupStatus(
      subjectId,
      snapshot.docs.map((item) => item.id),
      authoredIds,
      legacyDocumentTitles,
    );
  }

  async setupCurriculum(subjectId: string): Promise<CurriculumSetupResult> {
    const definition = getCurriculumSetupDefinition(subjectId);
    const status = await this.getCurriculumSetupStatus(subjectId);
    if (status.migration.state === "blocked") {
      throw new Error(
        "Legacy textbook units contain authored content. Migrate that content manually before replacing the units.",
      );
    }
    const references = definition.items.map((item) => ({
      item,
      reference: doc(this.db, contentPaths.chapter(subjectId, item.id)),
    }));

    return runTransaction(this.db, async (transaction) => {
      const legacyReferences = status.migration.legacyDocumentIds.map((id) =>
        doc(this.db, contentPaths.chapter(subjectId, id))
      );
      const snapshots = await Promise.all(
        references.map(({ reference }) => transaction.get(reference)),
      );
      const legacySnapshots = await Promise.all(
        legacyReferences.map((reference) => transaction.get(reference)),
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

      legacySnapshots.forEach((snapshot) => {
        if (snapshot.exists()) transaction.delete(snapshot.ref);
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

  async createTopic(
    subjectId: string,
    chapterId: string,
    input: TopicInput,
  ): Promise<void> {
    await addDoc(collection(this.db, contentPaths.topics(subjectId, chapterId)), {
      ...prepareNewTopic(input),
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
  }

  async updateTopic(
    subjectId: string,
    chapterId: string,
    topicId: string,
    input: TopicInput,
  ): Promise<void> {
    await updateDoc(doc(this.db, contentPaths.topic(subjectId, chapterId, topicId)), {
      ...input,
      updatedAt: serverTimestamp(),
    });
  }

  async setTopicStatus(
    subjectId: string,
    chapterId: string,
    topicId: string,
    status: Topic["status"],
  ): Promise<void> {
    await updateDoc(doc(this.db, contentPaths.topic(subjectId, chapterId, topicId)), {
      status,
      updatedAt: serverTimestamp(),
    });
  }

  async deleteTopic(subjectId: string, chapterId: string, topicId: string): Promise<void> {
    const location = { subjectId, chapterId, topicId };
    await this.deleteContentParent(
      location,
      doc(this.db, contentPaths.topic(subjectId, chapterId, topicId)),
      "topic",
    );
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
    const topics = await getDocs(
      collection(this.db, contentPaths.topics(subjectId, chapterId)),
    );
    if (!topics.empty) {
      throw new Error("Delete every topic before deleting this section.");
    }
    await this.deleteContentParent(
      { subjectId, chapterId },
      doc(this.db, contentPaths.chapter(subjectId, chapterId)),
      "curriculum item",
    );
  }

  private async deleteContentParent(
    location: CurriculumContentLocation,
    parentReference: ReturnType<typeof doc>,
    label: string,
  ): Promise<void> {
    const modules = await getDocs(
      collection(this.db, contentPaths.modules(location)),
    );
    const practiceQuestions = await getDocs(
      collection(this.db, contentPaths.practiceQuestions(location)),
    );
    const nestedSnapshots = await Promise.all(
      modules.docs.flatMap((module) =>
        structuredCollections.map((collectionName) =>
          getDocs(
            collection(
              this.db,
              contentPaths.moduleContent(
                location,
                module.id,
                collectionName,
              ),
            ),
          ),
        ),
      ),
    );
    const nestedDocuments = nestedSnapshots.flatMap((snapshot) => snapshot.docs);
    const writeCount = nestedDocuments.length + modules.size + practiceQuestions.size + 1;
    if (writeCount > 500) {
      throw new Error(`This ${label} has too much content for a safe dashboard deletion.`);
    }
    const batch = writeBatch(this.db);
    nestedDocuments.forEach((item) => batch.delete(item.ref));
    modules.docs.forEach((item) => batch.delete(item.ref));
    practiceQuestions.docs.forEach((item) => batch.delete(item.ref));
    batch.delete(parentReference);
    await batch.commit();
  }

  async createModule(
    location: CurriculumContentLocation,
    input: LearningModuleInput,
  ): Promise<void> {
    await addDoc(collection(this.db, contentPaths.modules(location)), {
      ...input,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
  }

  async updateModule(
    location: CurriculumContentLocation,
    moduleId: string,
    input: LearningModuleInput,
  ): Promise<void> {
    await updateDoc(
      doc(this.db, contentPaths.module(location, moduleId)),
      { ...input, updatedAt: serverTimestamp() },
    );
  }

  async deleteModule(
    location: CurriculumContentLocation,
    moduleId: string,
  ): Promise<void> {
    const nestedSnapshots = await Promise.all(
      structuredCollections.map((collectionName) =>
        getDocs(
          collection(
            this.db,
            contentPaths.moduleContent(
              location,
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
    batch.delete(doc(this.db, contentPaths.module(location, moduleId)));
    await batch.commit();
  }

  async publishModule(
    location: CurriculumContentLocation,
    moduleId: string,
  ): Promise<void> {
    const chapterReference = doc(
      this.db,
      contentPaths.chapter(location.subjectId, location.chapterId),
    );
    const topicReference = location.topicId
      ? doc(
          this.db,
          contentPaths.topic(location.subjectId, location.chapterId, location.topicId),
        )
      : null;
    const moduleReference = doc(this.db, contentPaths.module(location, moduleId));

    await runTransaction(this.db, async (transaction) => {
      const chapterSnapshot = await transaction.get(chapterReference);
      const topicSnapshot = topicReference
        ? await transaction.get(topicReference)
        : null;
      const moduleSnapshot = await transaction.get(moduleReference);

      assertActivatableParent(chapterSnapshot.data()?.status, "curriculum container");
      if (topicSnapshot) assertActivatableParent(topicSnapshot.data()?.status, "topic");
      assertActivatableModule(moduleSnapshot.data()?.status);

      if (chapterSnapshot.data()?.status === "draft") {
        transaction.update(chapterReference, {
          status: "active",
          updatedAt: serverTimestamp(),
        });
      }
      if (topicReference && topicSnapshot?.data()?.status === "draft") {
        transaction.update(topicReference, {
          status: "active",
          updatedAt: serverTimestamp(),
        });
      }
      if (moduleSnapshot.data()?.status === "draft") {
        transaction.update(moduleReference, {
          status: "active",
          updatedAt: serverTimestamp(),
        });
      }
    });
  }

  private async findAuthoredLegacyDocuments(
    subjectId: string,
    legacyDocumentIds: string[],
  ): Promise<string[]> {
    const results = await Promise.all(
      legacyDocumentIds.map(async (chapterId) => {
        const location = { subjectId, chapterId };
        const [modules, practiceQuestions, topics] = await Promise.all([
          getDocs(collection(this.db, contentPaths.modules(location))),
          getDocs(collection(this.db, contentPaths.practiceQuestions(location))),
          getDocs(collection(this.db, contentPaths.topics(subjectId, chapterId))),
        ]);
        return modules.empty && practiceQuestions.empty && topics.empty
          ? null
          : chapterId;
      }),
    );
    return results.filter((id): id is string => id !== null);
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

function mapTopic(item: QueryDocumentSnapshot<DocumentData>): Topic {
  return mapTopicDocument(item.id, item.data());
}

function assertActivatableParent(status: unknown, label: string): void {
  if (status !== "draft" && status !== "active") {
    throw new Error(`The ${label} must be Draft or Active before activating a module.`);
  }
}

function assertActivatableModule(status: unknown): void {
  if (status !== "draft" && status !== "active") {
    throw new Error("The module must be Draft or Active before activation.");
  }
}
