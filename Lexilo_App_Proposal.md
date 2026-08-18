# Lexilo v0.9.1 Product Proposal

> Status: implemented in the current source tree
> Updated: August 17, 2026

Lexilo is a focused, local-first iOS vocabulary trainer. It helps learners turn
recognition into active recall through short daily sessions, automatic review
scheduling, and carefully filtered English lexical content.

## Product promise

Learn a small amount today, retrieve it in both directions, and return when
your memory needs it. Lexilo deliberately avoids deck administration, public
leaderboards, decorative memory dashboards, and unnecessary dictionary surface
area.

## v0.9.1 information architecture

The app has four primary areas:

- **Today** — the daily word-study pager, Quiz entry point, and Learn More action.
- **Words** — learned and upcoming vocabulary, with word/meaning filtering and
  a focused word-detail view.
- **History** — calendar-based study history with a combined list of words studied on a selected date and a relearning entry point.
- **Settings** — practice preferences, pronunciation, translations, imports,
  backup/sync, and source licenses.

There is no Memory or Progress tab. Scheduling evidence remains in the
background. The Words tab's Dictionary browser is development-only, and a
broader Dictionary feature is intentionally deferred to a future release.

## Learning experience

Every active sense produces two independent cards:

1. **Recognition:** word to meaning.
2. **Production:** meaning to word, with typed answer checking.

The two directions cannot be served on the same calendar day. Failed cards can
return later in the same session and are scheduled to return sooner. Today first
shows the daily words for study; the top-right Quiz tests only that current set.
When the learner reaches the last word, Learn More appends another configured
batch (five by default) and returns the pager to the first new word.

The scheduler is adaptive but intentionally quiet. It uses correctness,
response time, hints, difficulty, stability, retrievability, and recent review
history to choose the next interval. Technical scores are not presented as a
learner task.

## Content and pronunciation

The official Simple English Wiktionary Wikimedia dump is Lexilo's sole lexical
source. The build parses the dump locally and does not use the English
Wiktionary/Kaikki extract.
Open English WordNet is not bundled or merged. The current Learning Core build
is `simplewiktionary-20260801` and contains:

- 5,591 learning terms
- 6,710 term/POS lexemes
- 11,731 retained senses
- 13,264 validated usage examples
- 9,439 pronunciation rows
- 1,838 word forms

The importer keeps an example only when it contains the learning word or a
valid inflected form, has at least four tokens, and reads as a complete sentence
with terminal punctuation. Definitions, descriptions, collocations, and bare
phrases are never relabeled as examples. If no valid example exists, the
example field remains empty.

Pronunciation precedence is:

1. Simple English Wiktionary human-authored IPA.
2. CMUdict General American IPA converted directly from ARPAbet.
3. Explicitly marked eSpeak NG 1.52.0 generated IPA.

Spoken audio defaults to Apple's offline `AVSpeechSynthesizer`. Kitten Nano
v0.2 remains available as an optional offline engine through sherpa-onnx; when
Kitten is selected but cannot run, Apple TTS is used as a runtime fallback. All
core learning data and audio work offline.

## Data architecture

The lexical database is a read-only SQLite resource. It contains source-aware
terms, lexemes, etymology entries, senses, pronunciations, forms, and examples.
The app uses ordinary SQLite B-tree indexes for exact, prefix, and inflected
form lookup. It does not use FTS5 or a full-text definition search.

Learner state is stored separately as Codable JSON with a rolling backup. A
dictionary update refreshes lexical fields and migrates by stable source sense
ID, normalized word, and part of speech without resetting cards, review history,
or mastery.

## v0.9.1 release scope

Included:

- Today, Words, History, and Settings surfaces.
- Learning-first daily pager, Quiz for the current daily set, and Learn More for
  adding another batch of words.
- Recognition and typed production practice.
- Adaptive offline scheduling with separate directions.
- Daily goal, streak, combined calendar history, and historical relearning.
- Sense-aware word details with examples, pronunciation, collocations, and
  optional personal translations.
- CSV/TSV personal vocabulary import.
- JSON backup/restore and optional iCloud snapshot sync.
- Offline Apple TTS by default, with optional Kitten pronunciation and fallback.
- Small and medium WidgetKit study widgets backed by an App Group snapshot. The
  small widget is word-first; the medium widget places the complete selected
  definition or example below the word, with Definition as the default setting.

Deferred:

- Full dictionary browsing and downloadable dictionary packs.
- OEWN or any other semantic graph.
- Full-text definition search.
- Human-recorded dictionary audio.
- Cloze, speech assessment, social features, and open-ended AI conversation.

## Source and licensing requirements

The app ships attribution and license notices in
`CONTENT_SOURCES.md` and `Lexilo/Resources/LEXICON_NOTICES.md`. Simple English
Wiktionary text remains subject to CC BY-SA 4.0 and GFDL requirements. CMUdict
and eSpeak NG are pronunciation layers only and cannot introduce definitions,
senses, examples, or learning terms.

Commercial dictionary websites are product references only. Lexilo must not
scrape or redistribute their definitions, examples, or audio without an
appropriate license.

## Verification

The current v0.9.1 source tree was validated on an iPhone 17 Pro, iOS 26.2
Simulator:

- ReviewSchedulerTests: 43/43 passed.
- LexiloPracticeFlowTests: 4/4 passed.
- SQLite integrity check: passed.
- Selected source entries missing pronunciation: 0.
- Full simulator build and unsigned arm64 build: passed.

See `README.md`, `CONTENT_SOURCES.md`, and
`Lexilo/Resources/LEXICON_NOTICES.md` for implementation and data-build details.
