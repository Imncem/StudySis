import assert from "node:assert/strict";
import test from "node:test";
import { isFirestoreUnavailable } from "./firestore-errors.ts";

test("recognizes Firestore unavailable and offline failures", () => {
  assert.equal(isFirestoreUnavailable({ code: "unavailable" }), true);
  assert.equal(isFirestoreUnavailable({ code: "firestore/unavailable" }), true);
  assert.equal(
    isFirestoreUnavailable({
      message: "Failed to get document because the client is offline.",
    }),
    true,
  );
});

test("does not mislabel authorization or configuration failures as offline", () => {
  assert.equal(isFirestoreUnavailable({ code: "permission-denied" }), false);
  assert.equal(isFirestoreUnavailable(new Error("Firebase is not configured.")), false);
  assert.equal(isFirestoreUnavailable(undefined), false);
});
