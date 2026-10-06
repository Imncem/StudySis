import assert from "node:assert/strict";
import test from "node:test";
import { planSejarahSubchapterMigration } from "./sejarahSubchapterMigration.ts";

test("previews numbered legacy modules without changing their data", () => {
  const data = {
    title: "1.4 KERAJAAN ALAM MELAYU",
    type: "notes",
    content: "Legacy text",
    status: "active",
  };
  const plan = planSejarahSubchapterMigration([
    {
      id: "legacy",
      chapterNumber: 1,
      title: String(data.title),
      data,
      descendantCounts: { sections: 0, cards: 2 },
    },
  ]);
  assert.equal(plan.ambiguous.length, 0);
  assert.deepEqual(plan.items[0].moduleData, data);
  assert.equal(plan.items[0].subchapterId, "subchapter_01_04");
  assert.equal(plan.items[0].hasUnstructuredContent, true);
  assert.equal(plan.items[0].descendantCounts.cards, 2);
});

test("accepts the Bab prefix and blocks ambiguous or cross-chapter titles", () => {
  const plan = planSejarahSubchapterMigration([
    {
      id: "valid",
      chapterNumber: 1,
      title: "Bab 1 : 1.1 Konsep Alam Melayu",
      data: {},
    },
    { id: "ambiguous", chapterNumber: 1, title: "Introduction", data: {} },
    { id: "wrong", chapterNumber: 2, title: "1.2 Tajuk", data: {} },
  ]);
  assert.equal(plan.items[0].number, "1.1");
  assert.deepEqual(
    plan.ambiguous.map((item) => item.id),
    ["ambiguous", "wrong"],
  );
});

test("duplicate mappings are blocked instead of overwritten", () => {
  const plan = planSejarahSubchapterMigration([
    { id: "one", chapterNumber: 1, title: "1.1 First", data: {} },
    { id: "two", chapterNumber: 1, title: "1.1 Second", data: {} },
  ]);
  assert.equal(plan.items.length, 1);
  assert.equal(plan.ambiguous[0].id, "two");
});

test("an already-migrated chapter with no direct modules is an idempotent no-op", () => {
  assert.deepEqual(planSejarahSubchapterMigration([]), {
    items: [],
    ambiguous: [],
  });
});
