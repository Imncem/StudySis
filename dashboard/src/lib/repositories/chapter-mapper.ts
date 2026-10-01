import type { DocumentData } from "firebase/firestore";
import type { Chapter } from "../types.ts";

export function mapChapterDocument(id: string, data: DocumentData): Chapter {
  return {
    id,
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
    ...(typeof data.group === "string" ? { group: data.group } : {}),
  };
}
