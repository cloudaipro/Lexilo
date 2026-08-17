# Lexilo v0.9 Implementation Status

> Updated: August 16, 2026
> Scope: the simplified product direction, Simple English Wiktionary Learning Core, and release validation

This document records what is implemented in the current source tree. It replaces
the earlier plan that described a separate Memory screen, OEWN-backed content,
and a fixed interval scheduler.

## Delivered capabilities

| Area | Current implementation |
|---|---|
| Product surface | Today, Words, and Settings only. There is no Memory or Progress tab. |
| Practice | Recognition and typed meaning-to-word production, with reveal, Know/Don't know, Check, hints, precise correction, and post-answer context. |
| Scheduling | Compact adaptive model using difficulty, stability, retrievability, correctness, response time, hints, and recent history. Technical scores stay out of the normal UI. |
| Card separation | Recognition and production siblings cannot be served on the same calendar day. Failed cards can recycle within a session. |
| Sense model | Source-aware senses with core/extended/rare priority, usage labels, examples, collocations, translations, active state, pause state, and separate direction cards. |
| Recovery | Core answer controls remain available in practice; advanced pause, sense-correction, difficulty, and content-report actions are not exposed in the default UI. |
| Personal content | CSV/TSV import supports Word, Meaning, Example, and Tags, with duplicate detection, preview, and merge-or-skip behavior. |
| Portability | JSON export/restore, rolling local backup, tolerant migration, and optional iCloud snapshot sync. |
| Pronunciation | Simple English Wiktionary IPA, CMUdict conversion, eSpeak NG generated IPA, and offline Kitten Nano speech with system-voice failure fallback. |
| Widget | Small and medium WidgetKit layouts backed by an App Group snapshot. Small is word-first; Medium shows the complete Definition or Example selected in Settings, with Definition as the default. |
| Dictionary scope | The bundled database is a Learning Core. Full Dictionary browsing and downloadable dictionary packs are future work. |

## Lexical data quality

The official Simple English Wiktionary Wikimedia dump is the sole lexical
source. OEWN is not bundled or merged. The production database is
`simplewiktionary-20260801` and contains:

- 5,591 learning terms
- 6,710 term/POS lexemes
- 11,731 retained senses
- 13,264 validated examples
- 9,439 pronunciation rows
- 1,838 word forms

Example quality is enforced during import. A record must contain the learning
word or a valid inflected form, contain at least four tokens, and end with
terminal punctuation after normalization. Phrase-like glosses, descriptions,
collocations, and bare fragments are rejected. Missing examples remain missing;
the importer never copies a definition into the example field.

Lexical content updates use stable source sense IDs and normalized word/POS
fallback matching. A new lexicon version refreshes stored definitions, IPA, and
examples while preserving learner-owned cards, review history, and mastery.

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
required for the v0.9 learning experience.

## UI decisions

- **Today** presents one daily round, a featured word, streak context, and the
  primary practice action.
- **Words** contains My Words and Upcoming, with local word/meaning filtering
  and focused word detail.
- **Settings** contains practice, pronunciation, translation, import, backup,
  sync, attribution, and widget-content controls.
- **Widget** uses the current featured word. Small keeps the word as the focus;
  Medium places the selected complete definition or example below it without
  intentional truncation.
- Memory difficulty, stability, retrievability, and card-level diagnostics stay
  behind the interface. They influence scheduling but are not learner-facing
  content.
- The Words tab does not expose Dictionary browsing in v0.9.

## Verification

Validated on an iPhone 17 Pro, iOS 26.2 Simulator:

- `ReviewSchedulerTests`: 34/34 passed.
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

These additions must preserve the v0.9 principles: simple navigation, local-first
learning, source transparency, no OEWN dependency, and no unnecessary memory
metrics in the learner interface.
