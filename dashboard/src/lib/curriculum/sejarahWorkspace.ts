import type { Subchapter } from "../types.ts";

export type SejarahWorkspace =
  | { view: "chapter"; subchapter: null }
  | { view: "subchapter"; subchapter: Subchapter };

export function resolveSejarahWorkspace(
  subjectId: string | null,
  selectedSubchapterId: string | null,
  subchapters: readonly Subchapter[],
): SejarahWorkspace {
  if (subjectId !== "sejarah" || !selectedSubchapterId) {
    return { view: "chapter", subchapter: null };
  }

  const subchapter =
    subchapters.find((item) => item.id === selectedSubchapterId) ?? null;
  return subchapter
    ? { view: "subchapter", subchapter }
    : { view: "chapter", subchapter: null };
}
