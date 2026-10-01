import { doc, onSnapshot, updateDoc, type Firestore, type Unsubscribe } from "firebase/firestore";
import type { Student } from "@/lib/types";

export class StudentRepository {
  constructor(private readonly db: Firestore) {}

  watchQidah(
    onData: (student: Student) => void,
    onError: (error: Error) => void,
  ): Unsubscribe {
    return onSnapshot(
      doc(this.db, "students", "qidah"),
      (snapshot) => {
        if (!snapshot.exists()) {
          onError(new Error("The students/qidah document does not exist."));
          return;
        }
        onData(snapshot.data() as Student);
      },
      onError,
    );
  }

  async updateQidah(
    input: Pick<Student, "preferredLanguage" | "dailyTargetMinutes" | "status">,
  ): Promise<void> {
    await updateDoc(doc(this.db, "students", "qidah"), input);
  }
}
