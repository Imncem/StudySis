import assert from "node:assert/strict";
import test from "node:test";
import { buildDashboardIdentity } from "./dashboard-identity.ts";

test("uses the dashboard display name, email and editor role", () => {
  const identity = buildDashboardIdentity({
    role: "editor",
    active: true,
    displayName: "Chrisanne Dorence",
    email: "chrisannedorence@gmail.com",
  });

  assert.deepEqual(identity, {
    displayName: "Chrisanne Dorence",
    email: "chrisannedorence@gmail.com",
    initials: "CD",
    roleLabel: "Editor",
  });
});

test("creates one initial for a one-word name", () => {
  const identity = buildDashboardIdentity({
    role: "editor",
    active: true,
    displayName: "Dodee",
  });

  assert.equal(identity.initials, "D");
});

test("uses the first and last words of a multi-word name", () => {
  const identity = buildDashboardIdentity({
    role: "admin",
    active: true,
    displayName: "Ameerul Bin Iman",
  });

  assert.equal(identity.initials, "AI");
  assert.equal(identity.roleLabel, "Admin");
});

test("falls back to the access email prefix when displayName is missing", () => {
  const identity = buildDashboardIdentity({
    role: "editor",
    active: true,
    email: "chrisanne.dorence@example.com",
  });

  assert.equal(identity.displayName, "chrisanne.dorence");
  assert.equal(identity.initials, "CD");
});

test("preserves a long display name and limits its initials to two", () => {
  const longName = "Chrisanne Alexandra Dorence Longlastname";
  const identity = buildDashboardIdentity({
    role: "editor",
    active: true,
    displayName: longName,
    email: "chrisanne@example.com",
  });

  assert.equal(identity.displayName, longName);
  assert.equal(identity.initials, "CL");
});

test("falls back to the authenticated email without altering a long email", () => {
  const longEmail = "averylongdashboardusernamewithoutspaces@example.com";
  const identity = buildDashboardIdentity(
    { role: "admin", active: true, displayName: "  " },
    longEmail,
  );

  assert.equal(identity.displayName, "averylongdashboardusernamewithoutspaces");
  assert.equal(identity.email, longEmail);
  assert.equal(identity.initials, "A");
  assert.equal(identity.roleLabel, "Admin");
});

test("uses neutral fallbacks when optional profile metadata is unavailable", () => {
  const identity = buildDashboardIdentity({ role: "editor", active: true });

  assert.equal(identity.displayName, "User");
  assert.equal(identity.email, "Email unavailable");
  assert.equal(identity.initials, "U");
  assert.equal(identity.roleLabel, "Editor");
});
