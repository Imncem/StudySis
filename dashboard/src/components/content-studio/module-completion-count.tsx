"use client";

import { useEffect, useState } from "react";
import type { StructuredContentRepository } from "@/lib/repositories/structured-content-repository";
import type { LearningModule } from "@/lib/types";
import type { CurriculumContentLocation } from "@/lib/content-paths";
import { moduleCompletionLabel } from "@/lib/notes-authoring";
import { structuredContentCountLabel } from "@/lib/module-authoring";

export function ModuleCompletionCount({ repository, location, module, practiceModuleIds }: { repository: StructuredContentRepository; location: CurriculumContentLocation; module: LearningModule; practiceModuleIds: readonly string[] }) {
  const [count, setCount] = useState(0);

  useEffect(
    () => {
      return repository.watchCompletionCount(
        location,
        module,
        setCount,
        () => setCount(0),
        practiceModuleIds,
      );
    },
    [location, module, practiceModuleIds, repository],
  );

  if (module.type === "notes" && count === 0) {
    return <span>{moduleCompletionLabel(module)}</span>;
  }
  return <span>{structuredContentCountLabel(module.type, count)}</span>;
}
