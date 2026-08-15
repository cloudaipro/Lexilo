# Lexilo v0.9 Product Proposal

> Status: implemented in the current source tree
> Updated: August 15, 2026

Lexilo is a focused, local-first iOS vocabulary trainer. It helps learners turn
recognition into active recall through short daily sessions, automatic review
scheduling, and carefully filtered English lexical content.

## Product promise

Learn a small amount today, retrieve it in both directions, and return when
your memory needs it. Lexilo deliberately avoids deck administration, public
leaderboards, decorative memory dashboards, and unnecessary dictionary surface
area.

## v0.9 information architecture

The app has three primary areas:

- **Today** — daily round, streak, featured word, and practice entry point.
- **Words** — learned and upcoming vocabulary, with word/meaning filtering and
  a focused word-detail view.
- **Settings** — practice preferences, pronunciation, translations, imports,
  backup/sync, and source licenses.

There is no Memory or Progress tab. Scheduling evidence remains in the
background, and the Words tab does not expose a Dictionary browser. A broader
Dictionary feature is intentionally deferred to a future release.

## Learning experience

Every active sense produces two independent cards:

1. **Recognition:** word to meaning.
2. **Production:** meaning to word, with typed answer checking.

The two directions cannot be served on the same calendar day. Failed cards can
return later in the same session and are scheduled to return sooner. Practice
Again repeats the words completed today without changing the schedule.

The scheduler is adaptive but intentionally quiet. It uses correctness,
response time, hints, difficulty, stability, retrievability, and recent review
history to choose the next interval. Technical scores are not presented as a
learner task.

## Content and pronunciation

Kaikki's structured English Wiktionary extract is Lexilo's sole lexical source.
Open English WordNet is not bundled or merged. The current Learning Core build
is `2026-08-12-quality-v3` and contains:

- 39,179 learning terms
- 45,477 term/POS lexemes
- 100,588 retained senses
- 115,201 validated usage examples
- 69,889 pronunciation rows
- 79,195 word forms

The importer keeps an example only when it contains the learning word or a
valid inflected form, has at least four tokens, and reads as a complete sentence
with terminal punctuation. Definitions, descriptions, collocations, and bare
phrases are never relabeled as examples. If no valid example exists, the
example field remains empty.

Pronunciation precedence is:

1. Kaikki human-authored IPA.
2. CMUdict General American IPA converted directly from ARPAbet.
3. Explicitly marked eSpeak NG 1.52.0 generated IPA.

Spoken audio uses the bundled Kitten Nano v0.2 model through sherpa-onnx, with
an installed iOS voice retained only as a runtime failure fallback. All core
learning data and audio work offline.

## Data architecture

The lexical database is a read-only SQLite resource. It contains source-aware
terms, lexemes, etymology entries, senses, pronunciations, forms, and examples.
The app uses ordinary SQLite B-tree indexes for exact, prefix, and inflected
form lookup. It does not use FTS5 or a full-text definition search.

Learner state is stored separately as Codable JSON with a rolling backup. A
dictionary update refreshes lexical fields and migrates by stable source sense
ID, normalized word, and part of speech without resetting cards, review history,
or mastery.

## v0.9 release scope

Included:

- Today, Words, and Settings surfaces.
- Recognition and typed production practice.
- Adaptive offline scheduling with separate directions.
- Daily goal, streak, Next Round, and Practice Again.
- Sense-aware word details with examples, pronunciation, collocations, and
  optional personal translations.
- CSV/TSV personal vocabulary import.
- JSON backup/restore and optional iCloud snapshot sync.
- Offline Kitten pronunciation with system-voice fallback.
- WidgetKit study snapshot.

Deferred:

- Full dictionary browsing and downloadable dictionary packs.
- OEWN or any other semantic graph.
- Full-text definition search.
- Human-recorded dictionary audio.
- Cloze, speech assessment, social features, and open-ended AI conversation.

## Source and licensing requirements

The app ships attribution and license notices in
`CONTENT_SOURCES.md` and `Lexilo/Resources/LEXICON_NOTICES.md`. Kaikki and
Wiktionary text remains subject to CC BY-SA 4.0 and GFDL requirements. CMUdict
and eSpeak NG are pronunciation layers only and cannot introduce definitions,
senses, examples, or learning terms.

Commercial dictionary websites are product references only. Lexilo must not
scrape or redistribute their definitions, examples, or audio without an
appropriate license.

## Verification

The current v0.9 source tree was validated on an iPhone 17 Pro, iOS 26.2
Simulator:

- ReviewSchedulerTests: 32/32 passed.
- LexiloPracticeFlowTests: 4/4 passed.
- SQLite integrity check: passed.
- Selected source entries missing pronunciation: 0.
- Full simulator build and unsigned arm64 build: passed.

See `README.md`, `CONTENT_SOURCES.md`, and
`kaikki-dictionary-data-proposal-revised.md` for implementation and data-build
details.
