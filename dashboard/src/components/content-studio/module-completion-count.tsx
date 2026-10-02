"use client";

import { useEffect, useState } from "react";
import type { StructuredContentRepository } from "@/lib/repositories/structured-content-repository";
import type { LearningModule } from "@/lib/types";
import type { CurriculumContentLocation } from "@/lib/content-paths";

export function ModuleCompletionCount({ repository, location, module }: { repository: StructuredContentRepository; location: CurriculumContentLocation; module: LearningModule }) {
  const [count, setCount] = useState(0);

  useEffect(
    () => repository.watchCompletionCount(
      location,
      module,
      setCount,
      () => setCount(0),
    ),
    [location, module, repository],
  );

  const labels: Record<string, string> = {
    notes: "sections",
    flashcards: "cards",
    practice: "questions",
    quiz: "questions",
  };
  const label = labels[module.type];
  return label ? <span>{count} {label}</span> : <span>Placeholder</span>;
}
