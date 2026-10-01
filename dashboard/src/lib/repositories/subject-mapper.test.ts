import assert from "node:assert/strict";
import test from "node:test";
import { mapSubjectDocument } from "./subject-mapper.ts";

test("uses the Firestore document ID when subject data contains an id field", () => {
  const subject = mapSubjectDocument("math", {
    id: "overridden-id",
    displayName: "Mathematics",
    shortName: "Math",
    contentStatus: "available",
    iconName: "math",
    themeColor: "#496A5A",
    order: 1,
  });

  assert.equal(subject.id, "math");
  assert.equal(subject.displayName, "Mathematics");
});
