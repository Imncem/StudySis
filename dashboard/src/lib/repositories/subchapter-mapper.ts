import type { DocumentData } from "firebase/firestore";
import type { Subchapter, SubchapterInput } from "@/lib/types";

const NUMBER_PATTERN = /^(\d+)\.(\d+)$/;

export function subchapterDocumentId(number: string): string {
  const match = NUMBER_PATTERN.exec(number.trim());
  if (!match) throw new Error('Subchapter number must use the format "1.4".');
  return `subchapter_${match[1].padStart(2, "0")}_${match[2].padStart(2, "0")}`;
}

export function mapSubchapterDocument(
  id: string,
  data: DocumentData,
): Subchapter {
  return {
    id,
    number: typeof data.number === "string" ? data.number : "",
    title: typeof data.title === "string" ? data.title : "Untitled subchapter",
    order: typeof data.order === "number" ? data.order : 0,
    status: ["draft", "active", "archived"].includes(data.status)
      ? data.status
      : "draft",
    createdAt: data.createdAt ?? null,
    updatedAt: data.updatedAt ?? null,
  };
}

export function prepareNewSubchapter(input: SubchapterInput): SubchapterInput {
  return { ...input, number: input.number.trim(), title: input.title.trim() };
}
