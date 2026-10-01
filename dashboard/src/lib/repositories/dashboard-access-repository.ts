import { doc, getDoc, type Firestore } from "firebase/firestore";
import {
  parseDashboardAccess,
  type DashboardAccessResult,
} from "../dashboard-access";

export class DashboardAccessRepository {
  constructor(private readonly db: Firestore) {}

  async getAccess(uid: string): Promise<DashboardAccessResult> {
    const snapshot = await getDoc(doc(this.db, "dashboard_access", uid));
    return parseDashboardAccess(snapshot.exists() ? snapshot.data() : undefined);
  }
}
