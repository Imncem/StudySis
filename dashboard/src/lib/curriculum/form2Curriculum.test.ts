import assert from "node:assert/strict";
import test from "node:test";
import { mathematicsChapterSeed } from "../seeds/mathematics-chapters.ts";
import { curriculumStructureTypes } from "../types.ts";
import {
  form2Curriculum,
  getCurriculumStructureLabels,
  getForm2Curriculum,
} from "./form2Curriculum.ts";

const expectedSubjects = {
  bahasa_melayu: ["bahasaMelayu", "section", "Section", "Sections"],
  english: ["english", "section", "Section", "Sections"],
  math: ["mathematics", "chapter", "Chapter", "Chapters"],
  science: ["science", "chapter", "Chapter", "Chapters"],
  sejarah: ["sejarah", "chapter", "Chapter", "Chapters"],
  geography: ["geography", "chapter", "Chapter", "Chapters"],
  rbt: ["rekaBentukTeknologi", "chapter", "Chapter", "Chapters"],
  pendidikan_islam: ["pendidikanIslam", "lesson", "Lesson", "Lessons"],
  pjk: ["pendidikanJasmani", "unit", "Unit", "Units"],
  seni: ["seni", "topic", "Topic", "Topics"],
} as const;

test("registers all Form 2 subjects with their required structure labels", () => {
  assert.equal(form2Curriculum.length, 10);

  for (const [firestoreSubjectId, [subjectKey, type, singular, plural]] of Object.entries(
    expectedSubjects,
  )) {
    const curriculum = getForm2Curriculum(firestoreSubjectId);
    assert.ok(curriculum, `Missing curriculum for ${firestoreSubjectId}`);
    assert.equal(curriculum.firestoreSubjectId, firestoreSubjectId);
    assert.equal(curriculum.subjectKey, subjectKey);
    assert.equal(curriculum.curriculum, "KSSM");
    assert.equal(curriculum.form, 2);
    assert.equal(curriculum.structureType, type);
    assert.deepEqual(getCurriculumStructureLabels(firestoreSubjectId), {
      structureType: type,
      structureLabelSingular: singular,
      structureLabelPlural: plural,
    });
  }
});

test("does not treat obsolete candidate IDs as authoritative", () => {
  for (const candidateId of [
    "bahasa-melayu",
    "pendidikan-islam",
    "pendidikan-jasmani",
  ]) {
    assert.equal(getForm2Curriculum(candidateId), undefined);
    assert.equal(getCurriculumStructureLabels(candidateId), undefined);
  }
});

test("uses valid structure types and draft items with unique order and titles", () => {
  for (const subject of form2Curriculum) {
    assert.ok(
      curriculumStructureTypes.includes(subject.structureType),
      `Invalid structure type for ${subject.firestoreSubjectId}`,
    );

    const orders = subject.items.map((item) => item.order);
    assert.deepEqual(
      orders,
      Array.from({ length: subject.items.length }, (_, index) => index + 1),
    );
    assert.equal(
      new Set(subject.items.map((item) => item.title)).size,
      subject.items.length,
      `Duplicate titles for ${subject.firestoreSubjectId}`,
    );
    for (const [index, item] of subject.items.entries()) {
      assert.ok(item.title.trim().length > 0);
      assert.equal(item.status, "draft");
      assert.equal(
        item.sequenceLabel,
        subject.firestoreSubjectId === "pjk"
          ? ["Unit 1", "Unit 2", "Unit 3", "Unit 4", "Unit 5", "Unit 6",
              "Unit 7", "Unit 8", "Unit 1", "Unit 2", "Unit 3"][index]
          : subject.firestoreSubjectId === "math"
          ? String(index + 1)
          : `${
              subject.structureType === "lesson"
                ? "Pelajaran"
                : subject.structureType === "topic"
                  ? "Tajuk"
                  : subject.structureType === "section"
                    ? "Section"
                  : subject.structureType === "unit"
                    ? "Unit"
                    : "Chapter"
            } ${index + 1}`,
      );
      if (subject.firestoreSubjectId === "pendidikan_islam") {
        assert.equal(typeof item.group, "string");
        assert.ok(item.group.trim().length > 0);
      }
    }
  }
});

test("includes the verified textbook chapter counts for the populated subjects", () => {
  const expectedItemCounts = {
    bahasa_melayu: 3,
    english: 3,
    math: 13,
    science: 13,
    sejarah: 10,
    geography: 11,
    rbt: 2,
    pendidikan_islam: 28,
    seni: 11,
    pjk: 11,
  } as const;

  for (const [firestoreSubjectId, expectedCount] of Object.entries(
    expectedItemCounts,
  )) {
    const curriculum = getForm2Curriculum(firestoreSubjectId);
    assert.ok(curriculum, `Missing curriculum for ${firestoreSubjectId}`);
    assert.equal(curriculum.items.length, expectedCount);
    if (firestoreSubjectId !== "math") {
      assert.ok(curriculum.curriculumSource);
      assert.ok(curriculum.curriculumSourceNote);
    }
  }
});

test("assigns Pendidikan Islam lessons to the textbook bidang groups", () => {
  const curriculum = getForm2Curriculum("pendidikan_islam");
  assert.ok(curriculum);
  const expectedGroups = [
    { first: 0, last: 7, group: "Al-Quran" },
    { first: 8, last: 9, group: "Hadis" },
    { first: 10, last: 12, group: "Akidah" },
    { first: 13, last: 18, group: "Fekah" },
    { first: 19, last: 22, group: "Sirah" },
    { first: 23, last: 27, group: "Akhlak Islamiah" },
  ];

  for (const { first, last, group } of expectedGroups) {
    for (const item of curriculum.items.slice(first, last + 1)) {
      assert.equal(item.group, group);
    }
  }
});

test("preserves the previously populated subject sequences", () => {
  const knownEndpoints = {
    science: ["Biodiversiti", "Meteoroid, Asteroid dan Komet"],
    sejarah: ["Kerajaan Alam Melayu", "Sarawak dan Sabah"],
    geography: ["Skala dan Jarak", "Panduan Kerja Lapangan"],
    rbt: ["Penyelesaian Masalah Secara Inventif", "Aplikasi Teknologi"],
  } as const;

  for (const [firestoreSubjectId, [firstTitle, lastTitle]] of Object.entries(
    knownEndpoints,
  )) {
    const curriculum = getForm2Curriculum(firestoreSubjectId);
    assert.ok(curriculum);
    assert.equal(curriculum.items[0]?.title, firstTitle);
    assert.equal(curriculum.items.at(-1)?.title, lastTitle);
  }
});

test("keeps the existing Mathematics seed sequence unchanged", () => {
  const mathematics = getForm2Curriculum("math");
  assert.ok(mathematics);
  assert.equal(mathematics.subjectKey, "mathematics");
  assert.equal(mathematics.firestoreSubjectId, "math");
  assert.equal(mathematics.items.length, 13);
  assert.deepEqual(
    mathematics.items.map((item) => item.title),
    mathematicsChapterSeed,
  );
  assert.deepEqual(
    mathematics.items.map((item) => item.order),
    Array.from({ length: 13 }, (_, index) => index + 1),
  );
});

test("uses three deterministic Bahasa Melayu sections and retains all textbook units as references", () => {
  const curriculum = getForm2Curriculum("bahasa_melayu");
  assert.ok(curriculum);
  assert.deepEqual(
    curriculum.items.map((item) => [item.id, item.title]),
    [
      ["pemahaman", "Pemahaman"],
      ["tatabahasa", "Tatabahasa"],
      ["penulisan", "Penulisan"],
    ],
  );
  assert.equal(new Set(curriculum.items.map((item) => item.id)).size, 3);
  assert.ok(curriculum.referenceScopeNote);
  assert.ok(curriculum.referenceItems);
  const references = curriculum.referenceItems;
  const expectedThemes = [
    ["Kesihatan dan Kebersihan", "Anda Sihat Anda Ceria", "Kebersihan Lambang Keperibadian"],
    ["Menimba Ilmu", "Indahnya Menuntut Ilmu", "Ilmu Penyuluh Hidup"],
    ["Kerjaya ke Mercu Impian", "Cita-cita Setinggi Bintang", "Budi Disemai, Bakti Dituai"],
    ["Integriti Amalan Kita", "Remaja Berintegriti", "Integrasi Teras Kehidupan"],
    ["Bahasa dan Sastera", "Bahasaku di Persada Dunia", "Indah Sastera, Cantik Bahasa"],
    ["Teladani Sejarah Hargai Warisan", "Sejarah Kita", "Pusaka Tanah Air"],
    ["Indah Seni Gah Budaya", "Warna-warni Budaya", "Segalanya Bermula di Sini"],
    ["Utamakan Keselamatan", "Keselamatan Diri", "Anda Prihatin, Anda Selamat"],
    ["Sukan dan Rekreasi", "Sukan Milik Semua", "Seronoknya Beriadah"],
    ["Selamat Datang ke Malaysia", "Kenali Malaysia", "Cintai Malaysia"],
    ["Perpaduan", "Indahnya Ukhuwah", "Teras Keharmonian"],
    ["Negaraku Jati Diriku", "Semarak Negara", "Hayati Rukun Negara"],
    ["Ekonomi, Keusahawanan dan Pengurusan Kewangan", "Ekonomi dan Perniagaan", "Bijak Wang"],
    ["Berbudi kepada Alam", "Suburnya Bumiku", "Di Tanah dan di Air"],
    ["Sains, Teknologi dan Inovasi", "Hebatnya Teknologi", "Dunia Kreativiti"],
    ["Pelestarian Alam", "Dunia Hanya Pinjaman", "Buana Menguntum Senyum"],
    ["Era Baharu Industri", "Industri Berdaya Saing", "Industri Berdaya Maju"],
    ["Pentadbiran dan Politik", "Patriot Bangsa", "Pemimpin Berjasa, Negara Berjaya"],
  ];
  assert.equal(references.length, 36);
  assert.equal(new Set(references.map((item) => item.order)).size, 36);
  assert.equal(new Set(references.map((item) => item.title)).size, 36);
  assert.equal(new Set(references.map((item) => item.group)).size, 18);
  for (const [index, [theme, first, second]] of expectedThemes.entries()) {
    const group = `Tema ${index + 1}: ${theme}`;
    const items = references.filter((item) => item.group === group);
    assert.equal(items.length, 2);
    assert.deepEqual(items.map((item) => item.title), [first, second]);
    assert.deepEqual(
      items.map((item) => [item.order, item.sequenceLabel, item.status]),
      [0, 1].map((offset) => {
        const order = index * 2 + offset + 1;
        return [order, `Unit ${order}`, "draft"];
      }),
    );
  }
  assert.ok(references.every((item) => item.group?.trim()));
});

test("preserves the complete PJK unit list and section-local numbering", () => {
  const curriculum = getForm2Curriculum("pjk");
  assert.ok(curriculum);
  const expected = [
    ["Pendidikan Jasmani", "Unit 1", "Gimnastik Asas"],
    ["Pendidikan Jasmani", "Unit 2", "Pergerakan Berirama"],
    ["Pendidikan Jasmani", "Unit 3", "Permainan Kategori Serangan"],
    ["Pendidikan Jasmani", "Unit 4", "Permainan Kategori Jaring"],
    ["Pendidikan Jasmani", "Unit 5", "Permainan Kategori Memadang"],
    ["Pendidikan Jasmani", "Unit 6", "Olahraga Asas"],
    ["Pendidikan Jasmani", "Unit 7", "Rekreasi dan Kesenggangan"],
    ["Pendidikan Jasmani", "Unit 8", "Kecergasan"],
    ["Pendidikan Kesihatan", "Unit 1", "Pendidikan Kesihatan Reproduktif dan Sosial (PEERS)"],
    ["Pendidikan Kesihatan", "Unit 2", "Pemakanan"],
    ["Pendidikan Kesihatan", "Unit 3", "Pertolongan Cemas"],
  ];
  // Exact equality also prevents subtopics from becoming extra curriculum items.
  assert.deepEqual(
    curriculum.items,
    expected.map(([group, sequenceLabel, title], index) => ({
      order: index + 1,
      sequenceLabel,
      title,
      group,
      status: "draft",
    })),
  );
  assert.equal(new Set(curriculum.items.map((item) => item.order)).size, 11);
  assert.equal(new Set(curriculum.items.map((item) => item.title)).size, 11);
  assert.ok(curriculum.items.every((item) => item.title.trim()));
});

test("uses three deterministic English sections and preserves Pulse 2 references", () => {
  const english = getForm2Curriculum("english");
  assert.ok(english);
  assert.deepEqual(
    english.items.map((item) => [item.id, item.title]),
    [
      ["grammar", "Grammar"],
      ["literature", "Literature"],
      ["essay_writing", "Essay Writing"],
    ],
  );
  assert.ok(english.referenceScopeNote);
  assert.deepEqual(
    english.referenceItems,
    [
      { id: "unit_06", order: 1, sequenceLabel: "Unit 6", title: "Money", group: "Consumerism and Financial Awareness", status: "draft" },
      { id: "unit_07", order: 2, sequenceLabel: "Unit 7", title: "Journeys", group: "People and Culture", status: "draft" },
      { id: "unit_08", order: 3, sequenceLabel: "Unit 8", title: "Good luck, bad luck", group: "People and Culture", status: "draft" },
      { id: "unit_09", order: 4, sequenceLabel: "Unit 9", title: "Take care", group: "Health and Environment", status: "draft" },
    ],
  );
  for (const item of english.referenceItems ?? []) {
    assert.notEqual(item.sequenceLabel, `Unit ${item.order}`);
    assert.equal(item.contentStandards, undefined);
    assert.equal(item.learningStandards, undefined);
  }
});

test("has no empty subjects and limits grouping to the approved subjects", () => {
  assert.equal(new Set(form2Curriculum.map((subject) => subject.firestoreSubjectId)).size, 10);
  assert.ok(form2Curriculum.every((subject) => subject.items.length > 0));
  assert.deepEqual(
    form2Curriculum
      .filter((subject) => subject.items.some((item) => item.group !== undefined))
      .map((subject) => subject.firestoreSubjectId),
    ["pendidikan_islam", "pjk"],
  );
});

test("returns undefined for unknown subject IDs", () => {
  assert.equal(getForm2Curriculum("unknown-subject"), undefined);
  assert.equal(getCurriculumStructureLabels("unknown-subject"), undefined);
});
