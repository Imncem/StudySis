"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { onAuthStateChanged, signOut, type User } from "firebase/auth";
import { getFirebaseAuth, getFirebaseDb } from "@/lib/firebase";
import { AdminDashboard } from "@/components/admin-dashboard";
import { LoginForm } from "@/components/login-form";
import type { DashboardAccessResult } from "@/lib/dashboard-access";
import { isFirestoreUnavailable } from "@/lib/firestore-errors";
import { DashboardAccessRepository } from "@/lib/repositories/dashboard-access-repository";

type AccessLoadError =
  | { kind: "firestore" }
  | { kind: "setup"; message: string };

export default function Home() {
  const [user, setUser] = useState<User | null>(null);
  const [checkingAuth, setCheckingAuth] = useState(true);
  const [accessResult, setAccessResult] = useState<DashboardAccessResult | null>(null);
  const [accessLoadError, setAccessLoadError] = useState<AccessLoadError | null>(null);
  const accessRequest = useRef(0);

  const loadDashboardAccess = useCallback(async (nextUser: User) => {
    const request = ++accessRequest.current;
    setCheckingAuth(true);
    setAccessResult(null);
    setAccessLoadError(null);

    const usesPassword = nextUser.providerData.some(
      (provider) => provider.providerId === "password",
    );
    if (!usesPassword) {
      if (request === accessRequest.current) {
        setAccessResult({ status: "invalid" });
        setCheckingAuth(false);
      }
      return;
    }

    try {
      const result = await new DashboardAccessRepository(getFirebaseDb()).getAccess(
        nextUser.uid,
      );
      if (request === accessRequest.current) setAccessResult(result);
    } catch (error) {
      if (request === accessRequest.current) {
        setAccessLoadError(
          isFirestoreUnavailable(error)
            ? { kind: "firestore" }
            : {
                kind: "setup",
                message: error instanceof Error
                  ? error.message
                  : "Dashboard access could not be loaded.",
              },
        );
      }
    } finally {
      if (request === accessRequest.current) setCheckingAuth(false);
    }
  }, []);

  useEffect(() => {
    try {
      return onAuthStateChanged(getFirebaseAuth(), (nextUser) => {
        setUser(nextUser);
        setAccessResult(null);
        setAccessLoadError(null);
        if (!nextUser) {
          accessRequest.current += 1;
          setCheckingAuth(false);
          return;
        }
        void loadDashboardAccess(nextUser);
      });
    } catch (error) {
      queueMicrotask(() => {
        setAccessLoadError({
          kind: "setup",
          message: error instanceof Error ? error.message : "Firebase is not configured.",
        });
        setCheckingAuth(false);
      });
    }
  }, [loadDashboardAccess]);

  function retryAccess() {
    const currentUser = getFirebaseAuth().currentUser;
    if (!currentUser) {
      setUser(null);
      setAccessLoadError(null);
      return;
    }
    setUser(currentUser);
    void loadDashboardAccess(currentUser);
  }

  if (checkingAuth) {
    return (
      <main className="grid min-h-screen place-items-center">
        <p className="text-sm text-slate-500">Opening StudySis…</p>
      </main>
    );
  }

  if (user && accessLoadError?.kind === "firestore") {
    return <FirestoreUnavailable user={user} onRetry={retryAccess} />;
  }

  if (accessLoadError?.kind === "setup") {
    return (
      <main className="grid min-h-screen place-items-center px-5">
        <section className="panel max-w-xl text-center">
          <h1 className="text-2xl font-bold">Connect StudySis to Firebase</h1>
          <p className="mt-3 text-sm leading-6 text-slate-600">{accessLoadError.message}</p>
          <p className="mt-2 text-sm text-slate-500">See the root README for setup instructions.</p>
        </section>
      </main>
    );
  }

  if (!user) return <LoginForm />;
  if (accessResult?.status === "active") {
    return <AdminDashboard access={accessResult.access} user={user} />;
  }
  if (accessResult?.status === "missing" || accessResult?.status === "inactive") {
    return <DashboardAccessRequired user={user} />;
  }
  return <AccessDenied />;
}

function DashboardAccessRequired({ user }: { user: User }) {
  return (
    <AccessInformationCard title="Dashboard access required" user={user}>
      <p className="mt-5 text-sm leading-6 text-slate-600">
        Give this UID to the StudySis administrator so dashboard access can be configured.
      </p>
    </AccessInformationCard>
  );
}

function FirestoreUnavailable({ user, onRetry }: { user: User; onRetry: () => void }) {
  return (
    <AccessInformationCard
      actions={<button className="secondary-button" onClick={onRetry} type="button">Retry</button>}
      title="Unable to connect to Firestore"
      user={user}
    >
      <p className="mt-5 text-sm leading-6 text-slate-600">
        StudySis could not reach the Firebase database.<br />
        Check your internet connection and try again.
      </p>
    </AccessInformationCard>
  );
}

function AccessInformationCard({ title, user, actions, children }: { title: string; user: User; actions?: React.ReactNode; children: React.ReactNode }) {
  return (
    <main className="grid min-h-screen place-items-center px-5">
      <section className="panel w-full max-w-lg">
        <p className="eyebrow">STUDYSIS CONTENT STUDIO</p>
        <h1 className="mt-2 text-2xl font-bold">{title}</h1>
        <dl className="mt-6 space-y-4 rounded-2xl bg-[#f5f8f6] p-4 text-sm">
          <div><dt className="font-semibold text-slate-500">Signed in as:</dt><dd className="mt-1 break-all font-medium text-[#293930]">{user.email ?? "Not available"}</dd></div>
          <div><dt className="font-semibold text-slate-500">Firebase UID:</dt><dd className="mt-1 break-all font-mono text-[#293930]">{user.uid}</dd></div>
        </dl>
        {children}
        <div className="mt-6 flex flex-wrap gap-3">
          <CopyUidButton uid={user.uid} />
          {actions}
          <button className="secondary-button" onClick={() => signOut(getFirebaseAuth())} type="button">Sign out</button>
        </div>
      </section>
    </main>
  );
}

function CopyUidButton({ uid }: { uid: string }) {
  const [copyState, setCopyState] = useState<"idle" | "copied" | "failed">("idle");

  async function copyUid() {
    try {
      await navigator.clipboard.writeText(uid);
      setCopyState("copied");
    } catch {
      setCopyState("failed");
    }
  }

  const label = copyState === "copied"
    ? "Copied"
    : copyState === "failed"
      ? "Copy failed"
      : "Copy UID";
  return <button className="primary-button" onClick={copyUid} type="button" aria-live="polite">{label}</button>;
}

function AccessDenied() {
  return (
    <main className="grid min-h-screen place-items-center px-5">
      <section className="panel max-w-lg text-center">
        <p className="eyebrow">STUDYSIS CONTENT STUDIO</p>
        <h1 className="mt-2 text-2xl font-bold">Access denied</h1>
        <p className="mt-3 text-sm leading-6 text-slate-600">Your dashboard access record is invalid or this sign-in method is not allowed.</p>
        <button className="secondary-button mt-5" onClick={() => signOut(getFirebaseAuth())} type="button">Sign out</button>
      </section>
    </main>
  );
}
