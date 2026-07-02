import {
  addDoc,
  collection,
  deleteDoc,
  doc,
  onSnapshot,
  orderBy,
  query,
  serverTimestamp,
  updateDoc,
  type DocumentData,
  type Firestore,
  type QueryDocumentSnapshot,
  type Unsubscribe,
} from "firebase/firestore";
import { contentPaths } from "@/lib/content-paths";
import type {
  Flashcard,
  FlashcardInput,
  LearningModule,
  NoteSection,
  NoteSectionInput,
  PracticeItem,
  PracticeItemInput,
  QuizQuestion,
  QuizQuestionInput,
} from "@/lib/types";

type ErrorHandler = (error: Error) => void;
type Location = { subjectId: string; chapterId: string; moduleId: string };

const childCollectionByType = {
  notes: "sections",
  flashcards: "cards",
  practice: "items",
  quiz: "questions",
} as const;

export class StructuredContentRepository {
  constructor(private readonly db: Firestore) {}

  watchCompletionCount(
    location: Omit<Location, "moduleId">,
    module: LearningModule,
    onData: (count: number) => void,
    onError: ErrorHandler,
  ): Unsubscribe {
    const collectionName = childCollectionByType[
      module.type as keyof typeof childCollectionByType
    ];
    if (!collectionName) {
      onData(0);
      return () => undefined;
    }
    return onSnapshot(
      collection(
        this.db,
        contentPaths.moduleContent(
          location.subjectId,
          location.chapterId,
          module.id,
          collectionName,
        ),
      ),
      (snapshot) => onData(snapshot.size),
      onError,
    );
  }

  watchNoteSections(location: Location, onData: (items: NoteSection[]) => void, onError: ErrorHandler) {
    return this.watchOrdered(location, "sections", mapNoteSection, onData, onError);
  }

  createNoteSection(location: Location, input: NoteSectionInput) {
    return this.create(location, "sections", input);
  }

  updateNoteSection(location: Location, id: string, input: NoteSectionInput) {
    return this.update(location, "sections", id, input);
  }

  deleteNoteSection(location: Location, id: string) {
    return this.remove(location, "sections", id);
  }

  watchFlashcards(location: Location, onData: (items: Flashcard[]) => void, onError: ErrorHandler) {
    return this.watchOrdered(location, "cards", mapFlashcard, onData, onError);
  }

  createFlashcard(location: Location, input: FlashcardInput) {
    return this.create(location, "cards", input);
  }

  updateFlashcard(location: Location, id: string, input: FlashcardInput) {
    return this.update(location, "cards", id, input);
  }

  deleteFlashcard(location: Location, id: string) {
    return this.remove(location, "cards", id);
  }

  watchPracticeItems(location: Location, onData: (items: PracticeItem[]) => void, onError: ErrorHandler) {
    return this.watchOrdered(location, "items", mapPracticeItem, onData, onError);
  }

  createPracticeItem(location: Location, input: PracticeItemInput) {
    return this.create(location, "items", input);
  }

  updatePracticeItem(location: Location, id: string, input: PracticeItemInput) {
    return this.update(location, "items", id, input);
  }

  deletePracticeItem(location: Location, id: string) {
    return this.remove(location, "items", id);
  }

  watchQuizQuestions(location: Location, onData: (items: QuizQuestion[]) => void, onError: ErrorHandler) {
    return this.watchOrdered(location, "questions", mapQuizQuestion, onData, onError);
  }

  createQuizQuestion(location: Location, input: QuizQuestionInput) {
    return this.create(location, "questions", input);
  }

  updateQuizQuestion(location: Location, id: string, input: QuizQuestionInput) {
    return this.update(location, "questions", id, input);
  }

  deleteQuizQuestion(location: Location, id: string) {
    return this.remove(location, "questions", id);
  }

  private watchOrdered<T>(
    location: Location,
    collectionName: string,
    mapper: (snapshot: QueryDocumentSnapshot<DocumentData>) => T,
    onData: (items: T[]) => void,
    onError: ErrorHandler,
  ): Unsubscribe {
    return onSnapshot(
      query(
        collection(this.db, this.collectionPath(location, collectionName)),
        orderBy("order"),
      ),
      (snapshot) => onData(snapshot.docs.map(mapper)),
      onError,
    );
  }

  private async create<T extends object>(location: Location, collectionName: string, input: T) {
    await addDoc(collection(this.db, this.collectionPath(location, collectionName)), {
      ...input,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
  }

  private async update<T extends object>(location: Location, collectionName: string, id: string, input: T) {
    await updateDoc(doc(this.db, this.itemPath(location, collectionName, id)), {
      ...input,
      updatedAt: serverTimestamp(),
    });
  }

  private async remove(location: Location, collectionName: string, id: string) {
    await deleteDoc(doc(this.db, this.itemPath(location, collectionName, id)));
  }

  private collectionPath(location: Location, collectionName: string) {
    return contentPaths.moduleContent(
      location.subjectId,
      location.chapterId,
      location.moduleId,
      collectionName,
    );
  }

  private itemPath(location: Location, collectionName: string, id: string) {
    return contentPaths.moduleContentItem(
      location.subjectId,
      location.chapterId,
      location.moduleId,
      collectionName,
      id,
    );
  }
}

function base(item: QueryDocumentSnapshot<DocumentData>) {
  const data = item.data();
  return { id: item.id, createdAt: data.createdAt ?? null, updatedAt: data.updatedAt ?? null };
}

function mapNoteSection(item: QueryDocumentSnapshot<DocumentData>): NoteSection {
  const data = item.data();
  return { ...base(item), heading: data.heading ?? "", body: data.body ?? "", example: data.example ?? "", order: data.order ?? 0 };
}

function mapFlashcard(item: QueryDocumentSnapshot<DocumentData>): Flashcard {
  const data = item.data();
  return { ...base(item), front: data.front ?? "", back: data.back ?? "", hint: data.hint ?? "", order: data.order ?? 0, status: data.status ?? "draft" };
}

function mapPracticeItem(item: QueryDocumentSnapshot<DocumentData>): PracticeItem {
  const data = item.data();
  return { ...base(item), question: data.question ?? "", answer: data.answer ?? "", explanation: data.explanation ?? "", difficulty: data.difficulty ?? "easy", order: data.order ?? 0, status: data.status ?? "draft" };
}

function mapQuizQuestion(item: QueryDocumentSnapshot<DocumentData>): QuizQuestion {
  const data = item.data();
  return { ...base(item), question: data.question ?? "", options: Array.isArray(data.options) ? data.options : [], correctOptionIndex: data.correctOptionIndex ?? 0, explanation: data.explanation ?? "", difficulty: data.difficulty ?? "easy", order: data.order ?? 0, status: data.status ?? "draft" };
}
