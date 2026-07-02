"use client";

import { useEffect, useState } from "react";
import { onAuthStateChanged, type User } from "firebase/auth";
import { getFirebaseAuth } from "@/lib/firebase";
import { AdminDashboard } from "@/components/admin-dashboard";
import { LoginForm } from "@/components/login-form";

export default function Home() {
  const [user, setUser] = useState<User | null>(null);
  const [checkingAuth, setCheckingAuth] = useState(true);
  const [setupError, setSetupError] = useState("");

  useEffect(() => {
    try {
      return onAuthStateChanged(getFirebaseAuth(), (nextUser) => {
        setUser(nextUser);
        setCheckingAuth(false);
      });
    } catch (error) {
      queueMicrotask(() => {
        setSetupError(error instanceof Error ? error.message : "Firebase is not configured.");
        setCheckingAuth(false);
      });
    }
  }, []);

  if (checkingAuth) {
    return (
      <main className="grid min-h-screen place-items-center">
        <p className="text-sm text-slate-500">Opening StudySis…</p>
      </main>
    );
  }

  if (setupError) {
    return (
      <main className="grid min-h-screen place-items-center px-5">
        <section className="panel max-w-xl text-center">
          <h1 className="text-2xl font-bold">Connect StudySis to Firebase</h1>
          <p className="mt-3 text-sm leading-6 text-slate-600">{setupError}</p>
          <p className="mt-2 text-sm text-slate-500">See the root README for setup instructions.</p>
        </section>
      </main>
    );
  }

  return user ? <AdminDashboard user={user} /> : <LoginForm />;
}
