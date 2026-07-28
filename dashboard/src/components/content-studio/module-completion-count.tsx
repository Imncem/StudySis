"use client";

import { useEffect, useState } from "react";
import type { StructuredContentRepository } from "@/lib/repositories/structured-content-repository";
import type { LearningModule } from "@/lib/types";

export function ModuleCompletionCount({ repository, subjectId, chapterId, module }: { repository: StructuredContentRepository; subjectId: string; chapterId: string; module: LearningModule }) {
  const [count, setCount] = useState(0);

  useEffect(
    () => repository.watchCompletionCount(
      { subjectId, chapterId },
      module,
      setCount,
      () => setCount(0),
    ),
    [chapterId, module, repository, subjectId],
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
