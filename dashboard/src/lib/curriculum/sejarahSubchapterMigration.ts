export type LegacySejarahModule = {
  id: string;
  chapterNumber: number;
  title: string;
  data: Record<string, unknown>;
  descendantCounts?: Record<string, number>;
};

export type SejarahMigrationItem = {
  sourceModuleId: string;
  subchapterId: string;
  number: string;
  title: string;
  order: number;
  moduleData: Record<string, unknown>;
  descendantCounts: Record<string, number>;
  hasUnstructuredContent: boolean;
};

export type SejarahMigrationPlan = {
  items: SejarahMigrationItem[];
  ambiguous: Array<{ id: string; title: string; reason: string }>;
};

const NUMBERED_TITLE =
  /^(?:Bab\s+\d+\s*:\s*)?(\d+)\.(\d+)\s*[-:\u2013\u2014]?\s*(.+)$/i;

export function planSejarahSubchapterMigration(
  modules: LegacySejarahModule[],
): SejarahMigrationPlan {
  const items: SejarahMigrationItem[] = [];
  const ambiguous: SejarahMigrationPlan["ambiguous"] = [];
  const seen = new Set<string>();

  for (const legacyModule of modules) {
    const match = NUMBERED_TITLE.exec(legacyModule.title.trim());
    if (
      !match ||
      Number(match[1]) !== legacyModule.chapterNumber ||
      !match[3].trim()
    ) {
      ambiguous.push({
        id: legacyModule.id,
        title: legacyModule.title,
        reason:
          "Title does not contain an unambiguous subchapter number for its chapter.",
      });
      continue;
    }
    const number = `${Number(match[1])}.${Number(match[2])}`;
    const subchapterId = `subchapter_${match[1].padStart(2, "0")}_${match[2].padStart(2, "0")}`;
    if (seen.has(subchapterId)) {
      ambiguous.push({
        id: legacyModule.id,
        title: legacyModule.title,
        reason: `More than one direct module maps to ${number}.`,
      });
      continue;
    }
    seen.add(subchapterId);
    const descendantCounts = legacyModule.descendantCounts ?? {};
    items.push({
      sourceModuleId: legacyModule.id,
      subchapterId,
      number,
      title: match[3].trim(),
      order: Number(match[2]),
      moduleData: { ...legacyModule.data },
      descendantCounts: { ...descendantCounts },
      hasUnstructuredContent:
        typeof legacyModule.data.content === "string" &&
        legacyModule.data.content.trim().length > 0 &&
        (descendantCounts.sections ?? 0) === 0,
    });
  }

  return { items, ambiguous };
}
