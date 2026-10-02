# Form 2 curriculum registry

The registry is descriptive metadata, not a Firestore seeder.

Bahasa Melayu (`bahasa_melayu`) uses three StudySis Sections: Pemahaman,
Tatabahasa and Penulisan. Their deterministic Firestore IDs are `pemahaman`,
`tatabahasa` and `penulisan`. English uses Grammar, Literature and Essay
Writing with IDs `grammar`, `literature` and `essay_writing`. These learning
areas are StudySis navigation, not claims about textbook chapter structure.

Both language subjects use `Subject -> Section -> Topic -> Modules`. Sections
remain in the existing `chapters` collection for compatibility. Topics use:

`curriculum/form2/subjects/{subjectId}/chapters/{sectionId}/topics/{topicId}`

and modules live under each topic's `modules` collection. The other eight
subjects retain `chapters/{itemId}/modules` unchanged.

The verified 36 Bahasa Melayu Units under 18 Tema remain in `referenceItems`.
They are authoring references and are not primary navigation items.
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

## English textbook references

Pulse 2 Units 6-9 remain reference items: Money; Journeys; Good luck, bad
luck; Take care. They represent the Form 2 textbook component, not the
complete English Scheme of Work. Non-textbook lessons, Literature in Action,
teacher-developed cycles and projects are not converted into artificial
StudySis Units.
Future supplementary content requires a separate authoring/coverage design.

Pulse 2 supplies Unit identity; the Scheme of Work supplies theme/context.
The optional group is a SoW theme association, not a textbook parent section.
KSSM/CEFR standards remain separate from Unit numbers. No SK/SP mappings
are populated. Textbook and SoW links are in curriculumSourceNote.

The old deterministic IDs `unit_06` through `unit_09` are retained for safe
legacy detection and migration only.

## Registry completeness

All ten subjects have draft items; none has an empty items array.

| Subject ID | Structure | Items | Group usage |
| --- | --- | ---: | --- |
| bahasa_melayu | section | 3 | None; 36 Units retained as references |
| english | section | 3 | None; Pulse 2 Units 6-9 retained as references |
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

- Keep the existing chapters collection as the top-level curriculum-item
  storage layer. Language Topics are the only new nested curriculum layer.
- Chapter rules accept an optional non-empty string `group`; curriculum setup
  persists it only for registry items that define one.
- Flutter will later need to recognize language `section` metadata, query
  `chapters/{sectionId}/topics`, navigate Section -> Topic -> Modules, and
  include `topicId` in progress/content identity. Existing subject paths must
  remain the fallback for the other eight subjects.
- The dashboard can create missing registry structure for every verified
  subject. Structure management remains Admin-only; trusted editors may
  activate completed draft learning content.
- AI generation and Flutter curriculum display changes remain deferred.

## Generic curriculum setup

The admin-only Content Studio setup action uses this registry directly and
stores every curriculum item in the existing `chapters` collection. Setup is
transactional and create-only: existing documents, statuses, timestamps,
modules, and nested authored content are never updated or deleted.

Deterministic IDs are:

- Mathematics: `chapter-01` through `chapter-13` (existing IDs preserved).
- Science, Sejarah, Geography, and RBT: `chapter_01`, etc.
- Bahasa Melayu Sections: `pemahaman`, `tatabahasa`, `penulisan`.
- English Sections: `grammar`, `literature`, `essay_writing`.
- Pendidikan Islam: `lesson_01` through `lesson_28`.
- PJK: `pj_unit_01` through `pj_unit_08`, then `pk_unit_01` through
  `pk_unit_03`.
- Seni: `topic_01` through `topic_11`.

Tema and Scheme-of-Work themes remain reference metadata. Bidang and PJ/PK
section names remain optional `group` metadata on primary items. Setup does
not create default Topics or learning modules. New curriculum documents and
new Topics always start as Draft.

For BM and English, setup inspects legacy textbook-unit documents before
replacement. Empty legacy parent documents can be removed while creating the
new deterministic Sections. If any legacy unit contains modules, practice
questions or nested topics, setup is blocked and requires manual content
migration. This prevents automatic parent deletion from orphaning Firestore
subcollections.

## Trusted editor activation

An active dashboard editor can author new draft modules and structured content,
then move an existing draft module, Flashcard, Practice item, or Quiz question
to `active`. Notes do not have a separate child status; activating the Notes
module publishes its note sections.

Module activation keeps the existing parent behaviour: the containing Chapter
or Section is activated, and a language Topic is activated as well. Editor
parent writes are status-only and cannot rename, reorder, regroup, create, or
delete curriculum structure. Editors cannot archive content or move active
content back to draft. Withdrawing active content could remove it from a
student's current learning journey, so that transition remains Admin-only.
