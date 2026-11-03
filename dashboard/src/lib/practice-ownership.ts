export type PracticeOwnership = {
  moduleId?: string;
};

export function belongsToPracticeModule(
  item: PracticeOwnership,
  moduleId: string,
  practiceModuleIds: readonly string[],
): boolean {
  if (item.moduleId) return item.moduleId === moduleId;

  const uniqueModuleIds = [...new Set(practiceModuleIds)];
  return uniqueModuleIds.length === 1 && uniqueModuleIds[0] === moduleId;
}

export function filterPracticeItemsForModule<T extends PracticeOwnership>(
  items: readonly T[],
  moduleId: string,
  practiceModuleIds: readonly string[],
): T[] {
  return items.filter((item) =>
    belongsToPracticeModule(item, moduleId, practiceModuleIds),
  );
}
