"use client";

import { useState } from "react";
import type { User } from "firebase/auth";
import { signOut } from "firebase/auth";
import { getFirebaseAuth } from "@/lib/firebase";
import { ContentStudio } from "@/components/content-studio/content-studio";
import { DashboardOverview } from "@/components/dashboard-overview";
import { StudentPage } from "@/components/student-page";
import type { DashboardAccess } from "@/lib/dashboard-access";
import { buildDashboardIdentity } from "@/lib/dashboard-identity";

type Props = {
  user: User;
  access: DashboardAccess;
};
type View = "dashboard" | "student" | "content" | "rewards" | "muffin" | "progress" | "settings";

const navigation: { id: View; label: string; marker: string; available: boolean }[] = [
  { id: "dashboard", label: "Dashboard", marker: "D", available: true },
  { id: "student", label: "Student", marker: "S", available: true },
  { id: "content", label: "Content Studio", marker: "C", available: true },
  { id: "rewards", label: "Rewards", marker: "R", available: false },
  { id: "muffin", label: "Muffin", marker: "M", available: false },
  { id: "progress", label: "Progress", marker: "P", available: false },
  { id: "settings", label: "Settings", marker: "⋯", available: false },
];

const editorNavigation: { id: View; label: string; marker: string; available: boolean }[] = [
  { id: "content", label: "Content Studio", marker: "C", available: true },
];

export function AdminDashboard({ user, access }: Props) {
  const identity = buildDashboardIdentity(access, user.email);
  const availableNavigation = access.role === "admin"
    ? navigation
    : editorNavigation;
  const [view, setView] = useState<View>(access.role === "admin" ? "dashboard" : "content");

  return (
    <div className="min-h-screen md:pl-64">
      <aside className="border-b border-[#dfe5e0] bg-[#eef3ef] px-4 py-4 md:fixed md:inset-y-0 md:left-0 md:w-64 md:border-b-0 md:border-r md:px-5 md:py-7">
        <div className="mb-5 flex items-center justify-between md:mb-9">
          <div>
            <p className="text-xs font-bold tracking-[0.18em] text-[#567263]">STUDYSIS</p>
            <p className="mt-1 font-bold text-[#24342b]">Content Studio</p>
          </div>
          <span
            aria-label={`${identity.displayName} avatar`}
            className="grid h-10 w-10 shrink-0 place-items-center rounded-full bg-white text-sm font-bold text-[#496a5a] shadow-sm"
            title={identity.displayName}
          >
            {identity.initials}
          </span>
        </div>

        <nav className="flex gap-2 overflow-x-auto pb-1 md:block md:space-y-1 md:overflow-visible">
          {availableNavigation.map((item) => (
            <button
              className={`flex shrink-0 items-center gap-3 rounded-xl px-3 py-2.5 text-left text-sm font-semibold transition md:w-full ${
                view === item.id
                  ? "bg-white text-[#294336] shadow-sm"
                  : "text-[#63736a] hover:bg-white/60"
              }`}
              key={item.id}
              onClick={() => setView(item.id)}
              type="button"
            >
              <span className="grid h-7 w-7 place-items-center rounded-lg bg-[#e2ebe5] text-xs text-[#496a5a]">{item.marker}</span>
              {item.label}
              {!item.available && <span className="ml-auto hidden text-[10px] font-medium uppercase text-slate-400 md:inline">Soon</span>}
            </button>
          ))}
        </nav>

        <div className="mt-6 hidden border-t border-[#d8e0da] pt-5 md:block">
          <p
            className="line-clamp-2 break-words text-sm font-bold leading-5 text-[#293930]"
            title={identity.displayName}
          >
            {identity.displayName}
          </p>
          <p className="mt-1 break-all text-xs leading-4 text-slate-500" title={identity.email}>
            {identity.email}
          </p>
          <p className="mt-2 text-xs font-semibold text-[#496a5a]">{identity.roleLabel}</p>
          <button className="secondary-button mt-3 w-full" onClick={() => signOut(getFirebaseAuth())} type="button">Sign out</button>
        </div>
      </aside>

      <main className="mx-auto min-h-screen max-w-7xl px-5 py-8 sm:px-8 lg:py-12">
        {view === "dashboard" && <DashboardOverview onOpenContent={() => setView("content")} />}
        {view === "student" && <StudentPage />}
        {view === "content" && <ContentStudio access={access} />}
        {!availableNavigation.find((item) => item.id === view)?.available && <ComingSoon title={availableNavigation.find((item) => item.id === view)?.label ?? "Section"} />}
      </main>
    </div>
  );
}

function ComingSoon({ title }: { title: string }) {
  return (
    <section>
      <p className="eyebrow">STUDYSIS ADMIN</p>
      <h1 className="page-title">{title}</h1>
      <div className="panel mt-8 text-center">
        <p className="text-lg font-semibold text-[#354b40]">Coming soon</p>
        <p className="mt-2 text-sm text-slate-500">This area remains a placeholder in Sprint 2.</p>
      </div>
    </section>
  );
}
