"use client";

import { useEffect, useState } from "react";
import type { StructuredContentRepository } from "@/lib/repositories/structured-content-repository";
import type { LearningModule } from "@/lib/types";
import type { CurriculumContentLocation } from "@/lib/content-paths";
import { moduleCompletionLabel } from "@/lib/notes-authoring";

export function ModuleCompletionCount({ repository, location, module, practiceModuleIds }: { repository: StructuredContentRepository; location: CurriculumContentLocation; module: LearningModule; practiceModuleIds: readonly string[] }) {
  const [count, setCount] = useState(0);

  useEffect(
    () => {
      if (module.type === "notes") return () => undefined;
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

  if (module.type === "notes") {
    return <span>{moduleCompletionLabel(module)}</span>;
  }

  const labels: Record<string, string> = {
    flashcards: "cards",
    practice: "questions",
    quiz: "questions",
  };
  const label = labels[module.type];
  return label ? <span>{count} {label}</span> : <span>Placeholder</span>;
}
