export type OrderedModuleIdentity = {
  id: string;
  title: string;
  order: number;
};

export function findModuleOrderConflict(
  modules: readonly OrderedModuleIdentity[],
  order: number,
  excludedModuleId?: string,
): OrderedModuleIdentity | null {
  return (
    modules.find(
      (module) =>
        module.id !== excludedModuleId && module.order === order,
    ) ?? null
  );
}
