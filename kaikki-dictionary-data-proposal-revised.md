# Lexilo Kaikki Dictionary Data Proposal (Historical)

> Historical note: this proposal describes the superseded English Wiktionary/
> Kaikki source design. The current Learning Core uses the official Simple
> English Wiktionary Wikimedia dump; see `CONTENT_SOURCES.md` and
> `Lexilo/Resources/LEXICON_NOTICES.md` for the active source policy.

**Status:** Superseded historical proposal
**Date:** 2026-08-15
**Scope:** Offline English dictionary data, pronunciation coverage, compact SQLite packaging, and future downloadable dictionary support

## Current implementation note

This proposal is retained as historical design research. It is not the active
data plan. Lexilo currently uses the official Simple English Wiktionary dump
`simplewiktionary-20260801` from
<https://dumps.wikimedia.org/simplewiktionary/latest/> as its canonical,
user-facing lexical source. The current Learning Core contains 5,591 learning
terms, 6,710 lexemes, 11,731 retained senses, 13,264 validated examples,
9,439 pronunciation rows, and 1,838 forms.

The app does not ship the Kaikki/English Wiktionary extraction described below,
does not use Kaikki as a runtime fallback, and does not bundle a separate Full
Dictionary pack. CMUdict and eSpeak NG only fill pronunciation gaps; optional
OEWN input is build-time ranking evidence and never adds user-facing senses.

## Historical executive summary

Lexilo should adopt a layered dictionary architecture:

```text
Kaikki English JSONL
        ↓
Validate English records and source version
        ↓
Discard non-product metadata
        ↓
Normalize entries, etymology groups, senses, examples, forms, and IPA
        ↓
Add CMUdict and generated pronunciation fallbacks
        ↓
Filter and rank entries for product usefulness
        ↓
SQLite
        ↓
Learning Core bundled with the app
        +
Full Dictionary offered as an optional download
```

Kaikki should become Lexilo's single primary dictionary source for definitions, senses, forms, labels, etymology, and human-authored IPA. Lexilo does not need a separate semantic graph for the proposed dictionary feature. The data model should therefore remain intentionally simple and source-faithful.

The recommended product packaging is:

- **Learning Core:** approximately 30–70 MiB installed, bundled with Lexilo.
- **Full Dictionary:** approximately 135–160 MiB downloaded and 390–430 MiB installed, released with the future Dictionary feature. These figures come from the measured Kaikki-only, no-FTS prototype and leave modest headroom for metadata and indexes.

This approach improves Lexilo's pronunciation and content quality without increasing the initial app installation by approximately 393 MiB for a feature that is not yet public.

## Goals

- Provide modern English definitions and structured senses offline.
- Greatly improve human-authored IPA coverage.
- Preserve pronunciation variants by dialect and etymology.
- Prevent definitions, descriptions, collocations, and unsuitable quotations from being shown as usage examples.
- Support fast exact headword lookup, prefix lookup, and inflected-form lookup at dictionary scale.
- Allow a compact bundled vocabulary database and a larger optional dictionary pack.
- Maintain reproducible builds, source provenance, and license compliance.

### Vocabulary scope principle

Lexilo should not impose an arbitrary 200,000–300,000-word ceiling based on the assumption that a learner could never learn more than that number. Dictionary coverage and learnable vocabulary are different product concepts.

The dictionary may contain substantially more entries than any individual learner will actively study. The purpose of filtering is therefore not to enforce a theoretical human learning limit, but to improve product quality by suppressing low-value noise such as obsolete, highly specialized, taxonomic, malformed, or otherwise unsuitable entries from default discovery.

The final dictionary size should be chosen from empirical product criteria: lookup usefulness, entry quality, storage cost, search quality, and maintenance cost. A compact Learning Core can coexist with a much broader optional Full Dictionary without claiming that the broader vocabulary is inherently unlearnable.

## Non-goals for the first implementation

- Bundling all Wikimedia Commons pronunciation audio.
- Shipping translations for other languages.
- Displaying all historical quotations.
- Automatically treating every Wiktionary relation as learner-facing content.
- Shipping the Full Dictionary in Lexilo v0.9.

## Dataset selection

### Kaikki / English Wiktionary

Kaikki is the preferred source for:

- Headwords and parts of speech
- Modern definitions and sense structure
- Human-authored IPA
- Dialect and region labels
- Inflected and alternative forms
- Usage labels
- Learner-usable examples after filtering
- Optional etymology in the Full Dictionary

Source: <https://kaikki.org/dictionary/English/index.html>

### CMUdict

CMUdict should supplement missing General American pronunciations. Lexilo should convert ARPAbet directly with a stress-aware converter rather than import an unverified third-party IPA conversion.

Source: <https://github.com/cmusphinx/cmudict>

### Generated pronunciation

eSpeak NG 1.52.0 provides the final generated pronunciation layer for words and especially multiword phrases not covered by Kaikki or CMUdict. Generated values have explicit provenance and are never represented as dictionary-authored IPA.

## Measured Kaikki dataset characteristics

The following results were measured from the Kaikki English extraction produced on 2026-08-12 from the 2026-08-05 English Wiktionary dump.

### Download artifact

| Measurement | Result |
|---|---:|
| File | `kaikki.org-dictionary-English.jsonl` |
| Downloaded bytes | 3,212,295,539 |
| Binary size | Approximately 2.99 GiB |
| SHA-256 | `34b1929e330d52df6a725eb404e0e9456c8ca0dd302fb2ad32354106caf5ff1f` |
| HTTP range requests | Supported |
| JSONL records | 1,487,639 |

The 3.21 GB postprocessed English file already contains English entries with `lang_code=en`. A separate language filtering pass is only required when using the 22.9 GB raw English-Wiktionary extraction, which contains entries for hundreds of languages.

Raw data source: <https://kaikki.org/dictionary/rawdata.html>

### Content counts

| Content | Measured count |
|---|---:|
| Case-sensitive entry headwords | 1,385,953 |
| Case-folded entry headwords | 1,351,576 |
| Records | 1,487,639 |
| Senses | 1,780,482 |
| Forms | 973,096 |
| Examples and quotations | 760,426 |
| IPA values | 283,962 |
| Distinct headwords with IPA | 98,205 |
| Distinct headwords with pronunciation audio | 91,239 |

The website's 1,385,953-word figure is case-sensitive. Lexilo's normalized case-folded lookup space contains 1,351,576 distinct headwords.

### Record structure

A JSONL line represents a source entry approximately equivalent to:

```text
word + part of speech + etymology group
```

It does not necessarily represent one canonical word or one sense. A word can have multiple records for different parts of speech and multiple records with the same part of speech for different etymologies.

This distinction is essential for heteronyms. For example, `recreation` has separate records for:

```text
recreation / noun / etymology 1
  /ˌɹɛkɹiˈeɪʃən/
  an activity that amuses or diverts

recreation / noun / etymology 2
  /ɹiːkɹiˈeɪʃən/
  creating something again
```

Collapsing records by only `word + POS` would mix distinct meanings and pronunciations.

## JSON schema assessment

Kaikki provides a union-style schema browser rather than a permanently versioned schema for the postprocessed English file:

<https://kaikki.org/dictionary/errors/mapping/index.html>

The importer must therefore:

- Ignore unknown fields.
- Treat non-required fields as optional.
- Validate required fields and field types.
- Record the dump date, extraction date, Wiktextract commits, ETag, and SHA-256.
- Fail the build when schema drift changes required semantics.
- Produce a field-frequency and rejection report for every build.

### Top-level field policy

| Field | Purpose | Learning Core | Full Dictionary |
|---|---|---:|---:|
| `word` | Display headword | Keep | Keep |
| `lang_code` | Language validation | Validate | Validate |
| `pos` | Part of speech | Keep | Keep |
| `etymology_number` | Separate heteronyms | Keep | Keep |
| `senses` | Definitions, labels, examples | Keep | Keep |
| `sounds` | IPA, dialect, audio metadata | Keep IPA | Keep IPA |
| `forms` | Inflections and alternatives | Keep | Keep |
| `etymology_text` | Etymology | Remove | Optional |
| `hyphenations` | Syllabification | Optional | Optional |
| `synonyms` and related fields | Lexical relations | Optional | Optional |
| `head_templates` | Wiktionary template metadata | Remove | Remove |
| `etymology_templates` | Template expansion metadata | Remove | Remove |
| `translations` | Multilingual translations | Remove | Future pack |
| `categories` and `links` | Wiki organization metadata | Remove | Remove |
| `ogg_url` and `mp3_url` | Commons audio | Remove | Future licensed pack |

### Sense normalization

A Kaikki sense commonly contains a hierarchy:

```json
{
  "id": "en-run-en-verb-4acunXz3",
  "glosses": [
    "To move swiftly.",
    "To move forward quickly upon two feet..."
  ],
  "tags": ["intransitive"],
  "examples": []
}
```

Lexilo should interpret this as:

- `glosses[-1]`: leaf definition displayed for the sense.
- `glosses[0..-2]`: parent breadcrumb or grouping context.
- `tags`: structured usage and grammar labels.

The importer must not concatenate all glosses into one definition.

### Example filtering

Kaikki distinguishes authored examples from quotations:

```json
{
  "text": "Run, and you might still catch the train!",
  "type": "example",
  "bold_text_offsets": [[0, 3]]
}
```

Historical or published excerpts generally use `type=quotation` and may include a `ref` field.

The production quality pipeline applies these rules:

- Prefer `type=example`.
- Permit `type=quotation` only as a lower-priority fallback when it is short, clearly marks or contains the learning word, and reads as a self-contained usage example.
- Exclude long, historical, unmarked, or context-dependent quotations.
- Keep at most three examples per sense.
- Reject examples longer than 300 characters.
- Require at least four tokens and terminal sentence punctuation (`.`, `!`, `?`, or `…`) after normalization.
- Prefer records whose bold offsets identify the headword or an inflected form.

Of 760,426 source examples and quotations, 94,322 remained after filtering. This is approximately 12.4% of the source material.

The absence of a valid example must remain an absence. Lexilo must not substitute a definition, explanation, or collocation and label it as an example.

### Pronunciation normalization

Pronunciations belong to the source entry and etymology group, not merely the case-folded word.

Lexilo should:

- Preserve multiple valid pronunciations internally.
- Prefer phonemic `/.../` values over phonetic `[...]` values for normal display.
- Preserve dialect tags.
- Map tags to normalized dialect codes such as `en-US`, `en-GB`, `en-CA`, and `en-AU`.
- Prefer General American or US for an `en-US` user setting.
- Deduplicate identical IPA and dialect combinations.
- Store generated pronunciation separately with `is_generated=1`.
- Avoid sharing a pronunciation across different etymology groups unless explicitly validated.

## Coverage measurement from the pre-production candidate corpus

The following table records an earlier candidate-corpus comparison used to
choose the production filters. It is not the v0.9 Learning Core count; the
production counts and artifact sizes are reported in the section below.

| Candidate type | Lexilo count | Kaikki matched | Kaikki has IPA |
|---|---:|---:|---:|
| Single words | 10,804 | 10,464 (96.9%) | 8,750 (81.0%) |
| Phrases | 5,314 | 3,381 (63.6%) | 278 (5.2%) |
| All candidates | 16,118 | 13,845 (85.9%) | 9,028 (56.0%) |

Kaikki provides excellent headword coverage for Lexilo's single-word learning vocabulary, but it does not eliminate the pronunciation gap:

- 2,048 single words still lack human-authored IPA.
- 5,036 phrases still lack human-authored IPA.

The production pronunciation sequence should be:

```text
Kaikki human IPA
        ↓ missing
CMUdict General American pronunciation converted to IPA
        ↓ missing
Generated word or phrase pronunciation
```

## SQLite prototype measurements

### Full enriched prototype

- All entries and normalized senses
- Pronunciations
- Forms
- Up to three short authored examples per sense
- Etymology text
- Kaikki lexical relations
- B-tree indexes

| Artifact | Measured size |
|---|---:|
| Installed SQLite | 800 MiB |
| ZIP level 9 | 300 MiB |
| Apple LZFSE | 299 MiB |
| Zstandard level 10 | 261 MiB |

Kaikki lexical relations and their lookup indexes account for approximately 250 MiB. Because they are not required for the core dictionary experience, retaining all relation data in the default pack is not cost-effective.

### Full Lexilo Core prototype

The Full Core removed:

- Kaikki lexical relations
- Etymology text
- Quotations
- Translations
- Templates
- Categories
- Audio URLs

It retained:

- 1,487,639 source-entry records
- 1,779,280 senses with usable glosses
- 283,821 normalized pronunciation rows
- 972,820 forms
- 94,322 short examples
- Exact, prefix-friendly, and form lookup indexes

| Artifact | Measured size |
|---|---:|
| Installed SQLite | 393 MiB |
| Apple LZFSE | 154 MiB |
| Zstandard level 10 | 136 MiB |

This is the recommended basis for the future downloadable Dictionary pack.

### Historical production Learning Core (pre-migration)

The pre-migration Learning Core derived candidates directly from Kaikki using
frequency, modern-sense, and verified-usage criteria. It did not use a second
dictionary's headword list or an arbitrary maximum word count. This was a
packaging choice for the historical app experience, not a proposed upper bound
on learnable English vocabulary.

The historical production build (quality pipeline v3) contained 39,179 learning
terms, 45,477 term/POS lexemes, 100,588 retained senses, 69,889 pronunciation
rows, 115,201 validated examples, and 79,195 forms. These numbers do not
describe the current bundle. Example filtering additionally rejected
phrase-like records without sentence-ending punctuation, so definitions and
gloss fragments were not displayed as usage examples.

| Artifact | Measured size |
|---|---:|
| Installed SQLite | 67.0 MiB |
| Apple LZFSE | 26.5 MiB |
| Zstandard level 10 | 22.1 MiB |

The historical proposal recommended a compact Kaikki-based database. The
active source and counts are defined in `CONTENT_SOURCES.md`.

## Proposed production schema

The production schema should preserve source boundaries and etymology groups.

```text
term
 └─ lexeme
     └─ source_entry
         ├─ pronunciation
         ├─ word_form
         └─ sense
             └─ example
```

### Provenance

```sql
CREATE TABLE source (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    version TEXT NOT NULL,
    source_url TEXT NOT NULL,
    license TEXT NOT NULL,
    dump_date TEXT,
    extraction_date TEXT,
    sha256 TEXT NOT NULL
);
```

### Canonical terms and lexemes

```sql
CREATE TABLE term (
    id INTEGER PRIMARY KEY,
    word TEXT NOT NULL,
    normalized_word TEXT NOT NULL,
    is_phrase INTEGER NOT NULL,
    frequency_rank INTEGER,
    learning_band INTEGER,
    is_learning_candidate INTEGER NOT NULL DEFAULT 0
);

CREATE UNIQUE INDEX term_normalized
ON term(normalized_word, word);

CREATE TABLE lexeme (
    id INTEGER PRIMARY KEY,
    term_id INTEGER NOT NULL REFERENCES term(id),
    part_of_speech TEXT NOT NULL
);

CREATE UNIQUE INDEX lexeme_term_pos
ON lexeme(term_id, part_of_speech);
```

### Source-specific entries

```sql
CREATE TABLE source_entry (
    id INTEGER PRIMARY KEY,
    lexeme_id INTEGER NOT NULL REFERENCES lexeme(id),
    source_id TEXT NOT NULL REFERENCES source(id),
    source_key TEXT NOT NULL,
    etymology_number INTEGER,
    etymology_text TEXT,
    UNIQUE(source_id, source_key)
);
```

`source_key` should be derived deterministically from the source record rather than from JSONL line order.

### Senses

```sql
CREATE TABLE sense (
    id INTEGER PRIMARY KEY,
    source_entry_id INTEGER NOT NULL REFERENCES source_entry(id),
    source_sense_id TEXT NOT NULL,
    sense_order INTEGER NOT NULL,
    parent_gloss TEXT,
    definition TEXT NOT NULL,
    usage_labels TEXT,
    is_form_of INTEGER NOT NULL DEFAULT 0,
    is_obsolete INTEGER NOT NULL DEFAULT 0,
    learner_score REAL,
    UNIQUE(source_entry_id, source_sense_id)
);

CREATE INDEX sense_entry_order
ON sense(source_entry_id, sense_order);
```

### Pronunciations

```sql
CREATE TABLE pronunciation (
    id INTEGER PRIMARY KEY,
    source_entry_id INTEGER NOT NULL REFERENCES source_entry(id),
    ipa TEXT NOT NULL,
    dialect TEXT,
    notation TEXT NOT NULL,
    provenance TEXT NOT NULL,
    is_generated INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX pronunciation_entry
ON pronunciation(source_entry_id, dialect, is_generated);
```

Recommended provenance values include:

```text
kaikki-wiktionary
cmudict-converted
generated-g2p
```

### Examples

```sql
CREATE TABLE example (
    id INTEGER PRIMARY KEY,
    sense_id INTEGER NOT NULL REFERENCES sense(id),
    text TEXT NOT NULL,
    quality_score REAL NOT NULL,
    source_type TEXT NOT NULL
);

CREATE INDEX example_sense
ON example(sense_id, quality_score DESC);
```

### Word forms

```sql
CREATE TABLE word_form (
    id INTEGER PRIMARY KEY,
    lexeme_id INTEGER NOT NULL REFERENCES lexeme(id),
    form TEXT NOT NULL,
    normalized_form TEXT NOT NULL,
    form_tags TEXT
);

CREATE INDEX word_form_lookup
ON word_form(normalized_form, lexeme_id);
```

## Sense and learner ranking

A learner-facing sense score should reward:

- High corpus frequency
- Common part of speech
- A short authored example
- General and modern usage
- A concise definition
- Early source ordering when other signals are equal

It should penalize:

- `form-of` and `alt-of` entries
- Obsolete, archaic, historical, or rare usage
- Highly technical or taxonomic usage
- Offensive or vulgar senses as the default sense
- Missing or excessively long definitions

Suggested ranking inputs:

```text
frequency score
+ valid learner example
+ general-use label
+ concise definition
- obsolete/archaic/rare
- form-of/alt-of
- specialized domain
- offensive/vulgar default
```

All source senses can remain available in the Full Dictionary even when they are excluded from the learning scheduler.

## Lookup design

Lexilo does not require full-text definition search. The dictionary should optimize for the lookup patterns users actually need:

1. Exact headword lookup.
2. Prefix/autocomplete lookup.
3. Inflected-form lookup that resolves back to the canonical entry.

Exact headword lookup should use a B-tree:

```sql
SELECT id, word
FROM term
WHERE normalized_word = ?;
```

Prefix lookup should use an indexable range or another verified index-friendly prefix strategy. It should not use an unbounded substring query such as:

```sql
LIKE '%query%'
```

Forms should be resolved through `word_form_lookup`, then linked back to the canonical lexeme.

No FTS5 virtual table is required. This reduces database size, build complexity, runtime dependencies, and implementation scope.

## Product packaging

### Bundled Learning Core

The bundled database should contain:

- Current learning vocabulary
- Preferred Kaikki senses
- Valid short examples
- Kaikki and CMUdict pronunciations
- Generated pronunciation metadata where required
- Frequency and learning-band fields

Expected installed size should be validated from the final selected historical
Kaikki vocabulary and retained content. The prototype demonstrated that a
focused learning dataset can remain compact without introducing a second
lexical database.

### Optional Full Dictionary

The future Dictionary feature should download a versioned data pack rather than increase the initial app binary.

Expected sizes:

```text
Download: approximately 135–160 MiB
Installed: approximately 390–430 MiB
```

### Installation and update flow

```text
Download signed/versioned manifest
        ↓
Check schema compatibility and available storage
        ↓
Resume compressed download if needed
        ↓
Verify expected byte count and SHA-256
        ↓
Decompress into Application Support/<version>.tmp
        ↓
Run PRAGMA quick_check or integrity_check
        ↓
Open database and validate metadata/schema
        ↓
Atomically switch active version
        ↓
Remove old version only after successful activation
```

The update process should reserve approximately 1.2 GB of free space because the compressed download, new database, and old database may coexist temporarily.

## Licensing and attribution

Kaikki states that its extracted data is available under the same licenses as Wiktionary: CC BY-SA and GFDL.

Source: <https://kaikki.org/dictionary/>

Lexilo must include:

- Source name and URL
- Wiktionary/Kaikki attribution
- Applicable license notices and links
- Dump date and extraction date
- A statement that Lexilo filtered and normalized the source data
- A way to obtain the corresponding derived dictionary data as required by the selected compliance approach
- Source provenance in the database
- A link from an entry to the corresponding Wiktionary page where appropriate

Commons audio should remain excluded until Lexilo can track and comply with the license and attribution requirements of every bundled audio file.

This proposal is an engineering recommendation, not legal advice. A final license review is required before commercial distribution.

## Reproducible build pipeline

```text
1. Fetch pinned Kaikki artifact
2. Verify Content-Length, ETag, Last-Modified, and SHA-256
3. Stream JSONL without loading the full file into memory
4. Validate lang_code and required field types
5. Normalize Unicode, apostrophes, hyphens, whitespace, and lookup case
6. Preserve display spelling separately from normalized spelling
7. Split source entry, sense, pronunciation, form, and example rows
8. Filter examples and learner senses
9. Import CMUdict and generated pronunciation fallbacks
10. Build B-tree indexes after bulk insertion
11. Run database integrity and content QA
12. Vacuum/optimize the release database
13. Compress, hash, sign, and publish the manifest
```

Every build should emit a machine-readable report containing:

- Source versions and hashes
- Accepted and rejected record counts
- Unknown field counts
- POS distribution
- Sense and example counts
- Pronunciation coverage by candidate type
- Database table and index sizes
- Compression size
- Integrity-check result
- Regression results for known problem words

## Quality gates

The release pipeline should include regression fixtures for at least:

- `junk`: correct human IPA `/d͡ʒʌŋk/`
- `recreation`: separate meanings and pronunciations by etymology
- `furniture`: valid authored usage examples
- `lead`: metal and guide heteronyms remain separate
- `record`: noun and verb stress differences remain separate
- `read`: present and past pronunciations remain distinguishable
- Multiword phrases: generated pronunciation is marked as generated
- Definitions without examples: no fabricated or mislabeled example

Required automated checks:

- Every displayed sense has a non-empty definition.
- Every displayed example has `source_type=example`, or is a short validated `quotation` retained under the explicit fallback rule above.
- Every pronunciation has provenance.
- Generated IPA is never preferred over matching human IPA.
- Obsolete and offensive senses are not selected as the default without an explicit reason.
- Source records with different etymology groups are never automatically collapsed.
- `PRAGMA integrity_check` returns `ok`.

## Implementation phases

### Phase 1 — Importer and schema

- Implement a streaming Kaikki importer.
- Add source provenance and schema versioning.
- Implement entry, sense, pronunciation, form, and example normalization.
- Produce a Learning Core database only.

### Phase 2 — Pronunciation completeness

- Select preferred Kaikki dialect IPA.
- Add a stress-aware CMUdict converter.
- Add generated fallback values for remaining words and phrases.
- Remove manually coded word-specific pronunciation fallbacks.

### Phase 3 — Content quality

- Implement learner sense scoring.
- Enforce example filtering.
- Add regression tests for heteronyms and known content defects.
- Update Lexilo's current data access layer for the new schema.

### Phase 4 — Full Dictionary download

- Build and publish the Full Core pack.
- Add resumable download, verification, decompression, and atomic activation.
- Add storage management and database version UI.
- Release the Dictionary feature separately from the v0.9 learning experience.

## Historical decision (superseded)

Proceed with:

```text
Kaikki as the dictionary source
+ CMUdict and generated pronunciation fallbacks
+ SQLite optimized for exact, prefix, and form lookup
+ bundled Learning Core
+ optional broader Full Dictionary download in a future release
```

Do not proceed with:

- Shipping the unfiltered 3.21 GB JSONL.
- Treating unvalidated quotations or descriptions as learner examples.
- Treating a word-level pronunciation as valid for every etymology.
- Bundling the approximately 393 MiB Full Dictionary in Lexilo v0.9.
- Bundling Commons audio without per-file license handling.

## Current decision

Use the Simple English Wiktionary Learning Core as the product source. Keep the
Kaikki measurements and schema discussion above only as historical context for
future source comparisons; any new content-source proposal must start from the
active policy in `CONTENT_SOURCES.md`.
