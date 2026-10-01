"use client";

import { useEffect, useMemo, useState } from "react";
import { getFirebaseDb } from "@/lib/firebase";
import { ContentRepository } from "@/lib/repositories/content-repository";
import { StudentRepository } from "@/lib/repositories/student-repository";
import type { Student, Subject } from "@/lib/types";

export function useStudent() {
  const repository = useMemo(() => new StudentRepository(getFirebaseDb()), []);
  const [student, setStudent] = useState<Student | null>(null);
  const [error, setError] = useState("");

  useEffect(
    () => repository.watchQidah(setStudent, (nextError) => setError(nextError.message)),
    [repository],
  );

  return { student, error, repository };
}

export function useSubjects() {
  const repository = useMemo(() => new ContentRepository(getFirebaseDb()), []);
  const [subjects, setSubjects] = useState<Subject[]>([]);
  const [error, setError] = useState("");

  useEffect(
    () => repository.watchSubjects(setSubjects, (nextError) => setError(nextError.message)),
    [repository],
  );

  return { subjects, error, repository };
}
