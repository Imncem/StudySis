import assert from "node:assert/strict";
import test from "node:test";
import { mapTopicDocument, prepareNewTopic } from "./topic-mapper.ts";

test("forces every newly created topic to draft", () => {
  assert.deepEqual(
    prepareNewTopic({ title: "Kata Kerja", order: 3, status: "active" }),
    { title: "Kata Kerja", order: 3, status: "draft" },
  );
});

test("maps a language topic and preserves draft status and ordering", () => {
  assert.deepEqual(
    mapTopicDocument("kata_nama", {
      title: "Kata Nama",
      order: 2,
      status: "draft",
    }),
    {
      id: "kata_nama",
      title: "Kata Nama",
      order: 2,
      status: "draft",
      createdAt: null,
      updatedAt: null,
    },
  );
});
