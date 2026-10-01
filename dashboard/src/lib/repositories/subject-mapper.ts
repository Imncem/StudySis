import type { Subject } from "../types.ts";

export function mapSubjectDocument(
  documentId: string,
  data: Record<string, unknown>,
): Subject {
  return { ...data, id: documentId } as Subject;
}
