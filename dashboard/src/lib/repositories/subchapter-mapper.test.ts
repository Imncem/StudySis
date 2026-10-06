import assert from "node:assert/strict";
import test from "node:test";
import {
  mapSubchapterDocument,
  subchapterDocumentId,
} from "./subchapter-mapper.ts";

test("creates deterministic padded subchapter IDs", () => {
  assert.equal(subchapterDocumentId("1.4"), "subchapter_01_04");
  assert.equal(subchapterDocumentId("10.2"), "subchapter_10_02");
  assert.throws(() => subchapterDocumentId("Chapter 1"));
});

test("maps subchapter status and ordering", () => {
  const mapped = mapSubchapterDocument("subchapter_01_04", {
    number: "1.4",
    title: "Kerajaan Alam Melayu",
    order: 4,
    status: "active",
  });
  assert.equal(mapped.number, "1.4");
  assert.equal(mapped.order, 4);
  assert.equal(mapped.status, "active");
});
