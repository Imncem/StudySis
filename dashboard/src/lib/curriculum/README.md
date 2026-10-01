# Form 2 curriculum registry

The registry is descriptive metadata, not a Firestore seeder.

Bahasa Melayu (`bahasa_melayu`) uses 36 Unit items grouped under 18 Tema,
following the textbook contents on pages iv-v. Each Tema contains two Unit.
Source links are recorded in the subject's curriculumSourceNote.
`group` is optional reusable CurriculumItem and dashboard Chapter metadata;
ChapterInput inherits it. Existing documents without it remain compatible.
The dashboard reader ignores null or non-string group values.

## Pendidikan Jasmani and Pendidikan Kesihatan

PJK (`pjk`) retains unit / Unit / Units with 11 draft textbook units:
orders 1-8 are Pendidikan Jasmani, and orders 9-11 are Pendidikan Kesihatan.
PJ uses Unit 1-8; PK restarts at Unit 1-3. Global order is unique, but
sequenceLabel and chapterNumber (display numbering) are not globally unique.
Textbook Unit numbering is separate from DSKP Standard Kandungan and
Standard Pembelajaran codes. Source attribution is in curriculumSourceNote.

Future deterministic Firestore IDs should distinguish the sections:
`pj_unit_01` through `pj_unit_08`, then `pk_unit_01` through `pk_unit_03`.
Do not derive identity or deduplicate solely from chapterNumber. The existing
Mathematics-specific seed's number-based checks must not be reused unchanged.
No documents or generic seeder are created here.

Bola Baling, Ragbi Sentuh, Sepak Takraw, Kriket, Lumba Jalan Kaki, Lompat Jauh,
Merejam Lembing, PEERS subdivisions and T.O.T.A.P.S. remain internal subtopic
context for future content and generation, not extra units or module types.

## English textbook component

English (`english`) retains unit / Unit / Units. Its four draft items are
Pulse 2 Units 6-9: Money; Journeys; Good luck, bad luck; Take care.
They represent the Form 2 textbook component, not the complete English
Scheme of Work. Non-textbook lessons, Literature in Action, teacher-developed
cycles and projects are not converted into artificial StudySis Units.
Future supplementary content requires a separate authoring/coverage design.

Pulse 2 supplies Unit identity; the Scheme of Work supplies theme/context.
The optional group is a SoW theme association, not a textbook parent section.
KSSM/CEFR standards remain separate from Unit numbers. No SK/SP mappings
are populated. Textbook and SoW links are in curriculumSourceNote.

Future deterministic document IDs should be `unit_06`, `unit_07`,
`unit_08`, `unit_09`. Global order 1-4 controls StudySis sorting;
sequenceLabel and future chapterNumber preserve textbook numbers 6-9.
Do not infer textbook numbers from order. No documents are created here.

## Registry completeness

All ten subjects have draft items; none has an empty items array.

| Subject ID | Structure | Items | Group usage |
| --- | --- | ---: | --- |
| bahasa_melayu | unit | 36 | 18 Tema |
| english | unit | 4 | 3 SoW themes |
| math | chapter | 13 | None |
| science | chapter | 13 | None |
| sejarah | chapter | 10 | None |
| geography | chapter | 11 | None |
| rbt | chapter | 2 | None |
| pendidikan_islam | lesson | 28 | 6 bidang |
| pjk | unit | 11 | PJ / PK |
| seni | topic | 11 | None |

No empty provisional subject remains. Nine subjects record source provenance;
Mathematics inherits the existing chapter seed and still lacks registry-level
curriculumSource/curriculumSourceNote. Its sequence is regression-tested against
that seed, not independently reverified in this step. Other subjects retain
their existing source notes; this completeness audit is not a fresh external
verification of every title. Draft status is a publication state, not evidence
of complete teaching materials or verified standards coverage.

## Deferred integration

- Keep the existing chapters collection as the curriculum-item storage layer.
  Do not introduce nested Tema/Unit collections.
- Chapter rules accept an optional non-empty string `group`; curriculum setup
  persists it only for registry items that define one.
- Flutter will later need optional group parsing on Chapter, curriculum
  structure labels on Subject, Tema headings in the subject list, and
  Unit-aware labels in chapter/module screens. Preserve document IDs,
  navigation and progress keys.
- The dashboard can now create missing registry structure for every verified
  subject. Publishing remains a separate admin action.
- AI generation and Flutter curriculum display changes remain deferred.

## Generic curriculum setup

The admin-only Content Studio setup action uses this registry directly and
stores every curriculum item in the existing `chapters` collection. Setup is
transactional and create-only: existing documents, statuses, timestamps,
modules, and nested authored content are never updated or deleted.

Deterministic IDs are:

- Mathematics: `chapter-01` through `chapter-13` (existing IDs preserved).
- Science, Sejarah, Geography, and RBT: `chapter_01`, etc.
- Bahasa Melayu: `unit_01` through `unit_36`.
- English: `unit_06` through `unit_09`.
- Pendidikan Islam: `lesson_01` through `lesson_28`.
- PJK: `pj_unit_01` through `pj_unit_08`, then `pk_unit_01` through
  `pk_unit_03`.
- Seni: `topic_01` through `topic_11`.

Tema, Scheme-of-Work theme, Bidang, and PJ/PK section names remain optional
`group` metadata. Setup does not create group parent documents or default
learning modules. New curriculum documents always start as Draft.
