# Lexilo Current Implementation Status

> Updated: August 17, 2026
> Scope: the current learning flow, Simple English Wiktionary Learning Core, and release validation

This document records the behavior implemented in the current source tree. It
supersedes the earlier plan that described a separate Memory screen, a
Kaikki-based Learning Core, OEWN-backed user content, a fixed interval
scheduler, and a multi-round practice flow.

## Delivered capabilities

| Area | Current implementation |
|---|---|
| Product surface | Today, Words, History, and Settings. There is no Memory or Progress tab. |
| Daily learning | Today opens directly on a persistent daily word-study pager. The learner moves left/right through the set; the final card offers Learn More. |
| Daily expansion | The first batch is five words by default. Learn More appends another configured batch after the current set has been studied; Words updates from the same planned set. |
| Daily quiz | The top-right Quiz action tests only the current Today set using recognition and typed meaning-to-word recall. There is no Next Round flow. |
| Practice | Recognition uses Reveal and Know/Don't know. Recall uses typed Check or Reveal answer, with hints, precise correction, and post-answer context. |
| Scheduling | Compact adaptive model using difficulty, stability, retrievability, correctness, response time, hints, and recent history. Technical scores stay out of the normal UI. |
| Card separation | Recognition and production siblings cannot be served on the same calendar day. Failed cards can recycle within a session. |
| Sense model | Source-aware senses with Core/Extended/Rare priority, usage labels, examples, collocations, optional personal translations, and separate direction cards. |
| History | Calendar selection opens one combined list of words studied on the selected day. Relearn these words starts a historical study pager; there are no First learned/Reviewed sections or Practice these words action. |
| Words | My Words, Upcoming, and DEBUG-only Dictionary search. My Words filters All, Learning, Mastered, and Due; the current planned Today set is included immediately. Word detail has no Study this word button. |
| Recovery | Core answer controls remain available in practice; advanced pause, sense-correction, difficulty, and content-report actions are not exposed in the default UI. |
| Personal content | CSV/TSV import supports Word, Meaning, Example, and Tags, with duplicate detection, preview, and merge-or-skip behavior. |
| Portability | JSON export/restore, rolling local backup, tolerant migration, and optional iCloud snapshot sync. |
| Pronunciation | Apple TTS is the default offline engine. Kitten Nano is an optional offline engine with eight voices, rate control, and Apple fallback. |
| Widget | Small and medium WidgetKit layouts use the current daily set. Each timeline refresh advances one word in order and wraps around; tapping a widget opens Today’s words directly, while Medium shows the complete Definition or Example selected in Settings. |

## Lexical data quality

The official Simple English Wiktionary Wikimedia dump is the sole lexical
source. OEWN is not bundled or merged into user-facing content. The production
database is `simplewiktionary-20260801` and contains:

- 5,591 learning terms
- 6,710 term/POS lexemes
- 11,731 retained senses
- 13,264 validated examples
- 9,439 pronunciation rows
- 1,838 word forms

Example quality is enforced during import. A record must contain the learning
word or a valid inflected form, contain at least four tokens, and end with
terminal punctuation after normalization. Phrase-like glosses, descriptions,
collocations, and bare fragments are rejected. Missing examples remain
missing; the importer never copies a definition into the example field.

Lexical content updates use stable source sense IDs and normalized word/POS
fallback matching. A new lexicon version refreshes stored definitions, IPA,
and examples while preserving learner-owned cards, review history, and mastery.

## SQLite design

The app opens the bundled database read-only. The schema preserves source-entry
and etymology boundaries:

```text
term → lexeme → source_entry → sense → example
                         ├→ pronunciation
                         └→ word_form
```

Lookup uses ordinary B-tree indexes for exact headword, prefix, and inflected
form resolution. No FTS5 virtual table or full-text definition search is
required for the current learning experience.

## User-facing decisions

- Onboarding is intentionally minimal: it explains the learning approach and
  starts with Begin learning. Optional first-language support is configured
  later in Settings, not during onboarding.
- Today is the default entry point. The learner studies the prepared set first,
  then chooses Quiz. Learn More is the only action that increases today's set.
- History is the place to inspect a calendar date and relearn its combined
  studied-word list.
- The interface keeps memory scores, scheduler diagnostics, and dictionary
  administration behind the normal learning actions.

## Verification

Validated on an iPhone 17 Pro, iOS 26.2 Simulator:

- `ReviewSchedulerTests`: 43/43 passed.
- `LexiloPracticeFlowTests`: 4/4 passed.
- Full simulator build: passed.
- Unsigned arm64 iPhone build: passed.
- SQLite integrity check: passed.
- Selected source entries missing pronunciation: 0.
- Regression coverage confirms complete usage sentences for `lean`,
  `recreation`, and `harbor`, and validates the Simple Wiktionary parser.
- Widget snapshot tests cover complete definition/example payloads, the
  Definition default, Example selection, and decoding older snapshots.

## Deferred work

- Full Dictionary feature and optional downloadable pack.
- Human-recorded pronunciation where licensing is appropriate.
- Additional practice modes such as cloze or speech assessment.
- Curated academic, workplace, exam, and personal packs.
- Broader analytics only if they lead to a clear learner action.

These additions must preserve the current principles: simple navigation,
local-first learning, source transparency, no OEWN dependency, no unnecessary
memory metrics in the learner interface, and a clear separation between
learning, quizzing, and historical review.
