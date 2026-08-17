# Learner-Oriented Sense Ranking: Harbor Investigation and Research Brief

**Date:** 2026-08-16
**Project:** Lexilo
**Purpose:** Copy this brief into another AI system for an independent opinion, while preserving the local evidence and research already completed.

**Implementation status:** This brief contains the original investigation and the
recommendation that led to the current implementation. The shipped solution uses
automatic build-time ranking only. It has no hand-authored per-word ranking or
content-replacement layer.

## Copy-paste question for another AI

Lexilo is an offline English vocabulary-learning app. Its bundled dictionary is built from a pinned Kaikki extract of English Wiktionary. The app currently shows a strange-looking primary definition and example for **harbor**:

- Noun primary definition: **“Any place of shelter.”**
- Example: **“The neighborhood is a well-known harbor for petty thieves.”**

The data is technically valid, but it feels wrong for a learner-oriented dictionary. A learner would normally expect the physical nautical meaning first:

- a sheltered area of water where ships can anchor or dock;
- a neutral, modern example such as “The fishing boats returned to the harbor before the storm.”

Please independently evaluate the issue and answer these questions:

1. Is the problem in the Kaikki/Wiktionary source data, Lexilo’s import/ranking logic, the user interface, or a combination?
2. Why can a valid definition and example still be poor for language learners?
3. Should Lexilo keep Kaikki and add automatic learner-oriented sense ranking, or should it adopt another dictionary?
4. Compare Kaikki/English Wiktionary, Simple English Wiktionary, Open English WordNet, WordNet/SemCor, Tatoeba or other open resources, and licensed learner dictionaries such as Oxford, Cambridge, or Collins.
5. Which sources are appropriate for an offline commercial iOS app, considering licensing, local bundling, attribution, and update costs?
6. Propose a practical architecture and a staged implementation plan. Include a method for evaluating whether the top sense and example are genuinely learner-oriented.

Please distinguish clearly between:

- source-data correctness;
- sense-frequency or learner-frequency ranking;
- definition readability;
- example naturalness and pedagogical usefulness;
- licensing and redistribution rights.

Do not assume that a dictionary’s source order equals sense frequency. Do not recommend copying proprietary dictionary content unless the required license permits it.

## Executive conclusion

The **Harbor** result is not primarily a corrupted-dictionary problem. It is the interaction of three legitimate but different layers:

1. **English Wiktionary is a broad community dictionary, not a learner dictionary.** It includes literal, figurative, historical, technical, regional, and quotation-based material. Its sense order is editorial/source order, not a guaranteed learner-frequency order.
2. **Kaikki is an extraction and structuring layer.** It publishes structured data extracted from Wiktionary; it does not turn the source into a carefully sequenced learner dictionary.
3. **Lexilo’s original local ranking heuristic promoted the wrong proxy.** The importer gave a large bonus to senses that had any accepted example and a smaller bonus to short definitions. The app then selected the highest `learner_score`. For `harbor`, that made the abstract “place of shelter” sense narrowly outrank the physical nautical sense. The current ranker separates source order from learner rank and uses automatic cross-source alignment, usage labels, and Kaikki order as fallback evidence.

The best solution is therefore **not to replace Kaikki wholesale**. Lexilo retains Kaikki for broad open coverage and adds an automatic build-time learner-oriented ranking layer:

```text
Kaikki / English Wiktionary
        ↓
structural validation and normalization
        ↓
automatic learner-oriented ranking
        ↓
Core / Extended / Rare sense presentation
```

A second open resource can improve ranking evidence and coverage. A licensed learner dictionary can improve definitions and examples substantially, but it introduces cost, contract restrictions, attribution requirements, and content-distribution constraints. It should be considered a later product decision, not an immediate replacement for Kaikki.

## What Lexilo currently contains for “harbor”

The current bundled database is:

- **Database:** `Lexilo/Resources/lexilo-lexicon.sqlite`
- **Dataset metadata:** `Kaikki / English Wiktionary`
- **Build version:** `2026-08-12-quality-v3`
- **Source URL:** <https://kaikki.org/dictionary/English/>
- **Source licenses recorded by the build:** CC BY-SA 4.0 and GFDL

The relevant noun senses in the current bundled database are:

| Part of speech | Source sense order | Learner rank | Learner score | Rank reason | Definition |
|---|---:|---:|---:|---|---|
| noun | 1 | 1 | 41.005 | Simple Wiktionary alignment + OEWN alignment | A sheltered expanse of water, adjacent to land, in which ships may anchor or dock, especially for loading and unloading. |
| noun | 0 | 2 | 5.01 | OEWN alignment | Any place of shelter. |
| noun | 2 | 3 | 5.003333 | Kaikki source order fallback | A mixing box for materials. |

The rank-1 noun example is the retained Kaikki quotation beginning “A harbor,
even if it is a little harbor...”. The petty-thieves example remains available
for the shelter sense, but it no longer determines the primary sense.

The relevant verb senses include:

| Part of speech | Source sense order | Learner rank | Learner score | Rank reason | Definition |
|---|---:|---:|---:|---|---|
| verb | 0 | 1 | 38.26 | Simple Wiktionary alignment | To provide a harbor or safe place for. |
| verb | 1 | 2 | 36.2967 | Simple Wiktionary alignment + OEWN alignment | To take refuge or shelter in a protected expanse of water. |
| verb | 2 | 3 | 19.003333 | Simple Wiktionary alignment + OEWN alignment | To hold or persistently entertain in one's thoughts or mind. |
| verb | 3 | 4 | 5.0025 | Kaikki source order fallback | To drive (a hunted stag) to covert. |

The exact noun wording and the petty-thieves example are also present in the upstream English Wiktionary entry: [English Wiktionary: harbor](https://en.wiktionary.org/wiki/harbor). This establishes that Kaikki did not invent the unusual-looking content.

The current app shows the automatic `learner_rank` order. The physical nautical
noun sense is now rank 1 because both optional external sources support it; the
other senses remain in the database with their Kaikki provenance.

## How the current pipeline creates the result

### Example filtering is structural, not sense ranking

In [`scripts/build_lexicon.py`](../scripts/build_lexicon.py), `usable_examples` accepts an item when it satisfies conditions such as:

- it contains the learning word or has bold-text offsets;
- its type is `example` or `quotation`;
- it is within the length limit;
- it has at least four tokens;
- it ends like a complete sentence.

The example scorer assigns structural quality values based on source type,
length, and sentence validity. Those values are used to choose among examples
for a sense; they do not alter the automatic sense-ranking model.

The filter is useful for rejecting malformed records, fragments, and gloss-like
phrases. It does **not** determine whether an example is:

- common in modern English;
- neutral in tone;
- appropriate for a beginner or intermediate learner;
- the clearest illustration of that particular sense;
- more useful than an example for another sense.

The local logic therefore correctly recognizes the petty-thieves sentence as a
usable sentence, but it does not claim that the sentence is the best example
for every learner.

### Automatic learner ranking

The current [`scripts/learner_sense_ranker.py`](../scripts/learner_sense_ranker.py)
keeps `source_order` as the final fallback and computes automatic evidence from:

```text
external alignment support
- usage/register penalties
+ a small Kaikki source-order fallback signal
```

The ranker stores `learner_score`, `learner_confidence`, `rank_reason`, and
`rank_model_version`, then assigns contiguous `learner_rank` values. No
hand-authored per-word ranking data is read during the build.

### The app uses the precomputed learner rank

[`Lexilo/Services/LexiconStore.swift`](../Lexilo/Services/LexiconStore.swift) uses:

```sql
ORDER BY s2.learner_rank ASC, s2.id
```

for the preferred sense and for learning-candidate references. The app does not
perform semantic ranking at runtime.

Then [`Lexilo/Services/LearningService.swift`](../Lexilo/Services/LearningService.swift) maps the first returned sense to `.core`, the next two to `.extended`, and the remainder to `.rare`. The data model already has the concepts `core`, `extended`, and `rare` in [`Lexilo/Models/LearningModels.swift`](../Lexilo/Models/LearningModels.swift), but those priorities currently follow the ranked array position.

## Is this a Kaikki problem?

The most accurate diagnosis is:

| Layer | Finding |
|---|---|
| Kaikki | Functioning as a structured extract of its upstream source; not intended to be a complete learner dictionary. |
| English Wiktionary | Contains valid but broad senses, quotations, unusual examples, and ordering that is not guaranteed to reflect learner frequency. |
| Lexilo import validation | Good at rejecting malformed examples and preserving provenance, but does not assess learner naturalness or sense frequency. |
| Lexilo ranking | The original example-presence/shortness heuristic was the principal product-fit problem; the current automatic ranker separates structural example quality from learner sense order. |
| Lexilo presentation | Showing only the selected primary sense makes the ranking problem feel like a dictionary error. |

So the answer is **both source fitness and ranking design, but not source corruption**. Kaikki is a reasonable broad lexical foundation; the automatic ranker supplies the learner-oriented ordering.

## External research

### Kaikki and English Wiktionary

- [Kaikki raw data](https://kaikki.org/dictionary/rawdata.html) explains that Kaikki’s raw structured data is extracted from Wiktionary using Wiktextract and updated regularly.
- [Kaikki English dictionary](https://kaikki.org/dictionary/English/) is the source represented in Lexilo’s metadata.
- [English Wiktionary](https://en.wiktionary.org/) is a broad, community-maintained project. Its breadth is valuable for lexical coverage, but broad coverage is not the same as learner sequencing.
- The [upstream harbor entry](https://en.wiktionary.org/wiki/harbor) contains “Any place of shelter” and the petty-thieves example, as well as the physical nautical sense. This confirms that the odd-looking content originates upstream.

### Oxford Learner’s Dictionaries

- The [Oxford learner dictionary FAQ](https://www.oxfordlearnersdictionaries.com/faq/) says meanings are generally ordered by frequency, while noting editorial exceptions such as familiar original meanings, grouping related meanings, and what learners are likely to encounter.
- The [Oxford Learner’s Dictionaries definition pages](https://www.oxfordlearnersdictionaries.com/us/definition/english/) emphasize clear, simple definitions and real examples.
- The [Oxford 3000 and 5000](https://www.oxfordlearnersdictionaries.com/us/about/wordlists/oxford3000-5000) combine frequency/relevance with learner level and CEFR-oriented selection.
- Oxford’s [harbour page](https://www.oxfordlearnersdictionaries.com/us/definition/english/harbour_1) and [American harbor page](https://www.oxfordlearnersdictionaries.com/us/definition/american_english/harbor_1) put the physical harbor meaning first and use ordinary examples.
- Oxford’s standard [API terms](https://developer.oxforddictionaries.com/api-terms-and-conditions?tab=commercial) restrict caching and local storage in the ordinary API terms; local storage or a standalone dictionary product requires a separate agreement/approval. This is important because Lexilo is an offline app that bundles data.

### Cambridge Dictionary

- The [Cambridge Learner’s Dictionary harbor/harbour page](https://dictionary.cambridge.org/dictionary/learner-english/harbour) puts the physical water meaning first, followed by verb uses such as having an idea/feeling and hiding someone.
- The broader [Cambridge English page](https://dictionary.cambridge.org/us/dictionary/english/harbor) likewise presents the physical harbor sense first.
- The [Cambridge dictionary API/licensing page](https://dictionary-api.cambridge.org/) describes beginner, intermediate, and advanced learner datasets and offline licensing options for specific dictionaries. The page indicates that an application/license inquiry is required; this is not equivalent to an unrestricted open downloadable corpus.
- Cambridge’s [API terms](https://dictionary-api.cambridge.org/api/terms-and-conditions) make clear that evaluation and application use are controlled by terms and API keys, and that the dictionary content is owned or licensed by Cambridge.

### Collins

- The [Collins API page](https://www.collinsdictionary.com/collins-api) advertises monolingual, bilingual, and learner dictionaries with definitions, examples, phrases, and audio. It also publishes API pricing information, so it is a possible commercial route rather than an open-data replacement.
- Collins’ [learner harbor page](https://www.collinsdictionary.com/english-language-learning/harbor) presents the physical harbor sense before figurative or verb senses.

### Simple English Wiktionary

- [Simple English Wiktionary](https://simple.wiktionary.org/wiki/Main_Page) is an open/community dictionary intended to use simpler English and help learners.
- Its [about page](https://simple.wiktionary.org/wiki/Wiktionary%3AAbout), [style guide](https://simple.wiktionary.org/wiki/Wiktionary%3ASTYLE), and [learner-oriented description](https://simple.wiktionary.org/wiki/Wiktionary%3ASimple_English_Wiktionary) explain the simpler-language goal and the expectation that examples should show actual use.
- Its [harbor entry](https://simple.wiktionary.org/wiki/harbor) puts the physical water meaning first and uses a memorable but clear example: “A ship in the harbor is safe -- but that is not what ships are for.” It also retains the shelter and mental-state verb senses.

Simple English Wiktionary is promising as a learner-oriented **supplement**, but it is not guaranteed to have complete coverage, consistent editorial review, or the same sense inventory as the main English Wiktionary. It should not be treated as an automatic authoritative replacement.

### Open English WordNet and WordNet-derived resources

- [Open English WordNet](https://github.com/globalwordnet/english-wordnet) is a manually validated lexical-semantic network with synsets, relations, and definitions. The current project describes a 2025 edition and provides data under [CC BY 4.0](https://github.com/globalwordnet/english-wordnet/blob/main/LICENSE.md).
- [Open English WordNet downloads](https://en-word.net/downloads) provide downloadable releases suitable for offline experimentation, subject to the stated license and attribution conditions.
- In the downloaded 2025 OEWN data, the noun senses for `harbor` place the physical port sense first: “a sheltered port where ships can take on or discharge cargo,” followed by the refuge/comfort sense. This independently supports the learner-intuitive ordering, but it does not by itself provide a learner dictionary’s polished examples.
- [Princeton WordNet sense-count documentation](https://wordnet.princeton.edu/documentation/cntlist5wn) explains the historical sense-count resources and warns that traditional sense ordering should not be assumed to be an accurate current frequency indicator.
- [SemCor documentation](https://www.nltk.org/howto/corpus.html) describes a corpus tagged with WordNet senses. Tagged corpora can provide evidence for sense frequency, but they are not themselves a learner dictionary and may be dated or domain-biased.
- The [Global WordNet annotated-corpora page](https://globalwordnet.github.io/resources/wordnet-annotated-corpora) lists open sense-annotated corpora that could support evaluation or ranking research.

OEWN is useful for semantic structure, POS/sense alignment, and cross-source signals. It should complement, not replace, the learner-facing definitions and examples.

### Tatoeba and word-frequency resources

- [Tatoeba corpus usage/licensing](https://en.www.en.wiki.tatoeba.org/articles/show/using-the-tatoeba-corpus) describes sentence reuse and the default CC BY 2.0 FR context, while noting that sentences can have different licenses. Every sentence’s license and attribution needs to be tracked before bundling.
- [wordfreq](https://github.com/rspeer/wordfreq) supplies word-level frequency estimates built from multiple sources. It is useful for ranking lemmas or determining learning bands, but ordinary word frequency does not identify which sense is most frequent.

Tatoeba can provide additional natural sentences, but sentence-corpus quality, sense alignment, license tracking, and target-word highlighting still need to be solved. wordfreq cannot independently fix the `harbor` noun sense ordering.

## Local coverage checks performed

These were rough lexical-coverage comparisons, not proof of sense-level coverage. They normalized words/titles and compared keys; a matching title does not guarantee matching POS, definition quality, or sense alignment.

### Simple English Wiktionary title overlap

- Local Lexilo learning terms: **39,179**.
- Latest Simple English Wiktionary title list checked: approximately **53,853** normalized titles.
- Exact normalized overlap with all Lexilo terms: **12,309**.
- Local single-word Lexilo terms: **19,216**.
- Single-word overlap: **12,309**, approximately **64%**.
- Approximate single-word overlap by local learning band:

| Learning band | Local single-word terms | Simple Wikt overlap |
|---:|---:|---:|
| 1 | 1,484 | 884 |
| 2 | 3,676 | 2,242 |
| 3 | 5,180 | 3,653 |
| 4 | 7,448 | 4,774 |
| 5 | 1,428 | 756 |

The missing titles include phrases, inflections, spelling differences, and terms absent from Simple English Wiktionary. These figures show that Simple Wikt can be a useful supplement, not that it can replace the existing dictionary.

The latest [Simple English Wiktionary dump index](https://dumps.wikimedia.org/simplewiktionary/latest/) and [Wiktextract project](https://github.com/tatuylonen/wiktextract) provide possible offline extraction routes.

### Open English WordNet key overlap

- OEWN 2025 JSON entry keys checked: approximately **127,311**.
- Exact normalized overlap with all Lexilo terms: approximately **19,415**.
- Exact normalized overlap with local single-word terms: approximately **14,360**, roughly **75%**.

Again, these are title/key comparisons. OEWN’s value is semantic structure and sense relations, not complete learner-facing prose.

## Source and architecture options

| Option | Advantages | Limitations | Recommendation |
|---|---|---|---|
| Keep Kaikki and add automatic ranking | Broad coverage, existing pipeline, open-source provenance, low migration cost | Wiktionary breadth and examples remain source-derived | Current implementation |
| Add Simple English Wiktionary | Simpler definitions and learner intent; open/community supplement | Coverage and consistency gaps; still not a professional learner dictionary | Use as a definition/ranking signal and fallback, not sole source |
| Add Open English WordNet | Sense graph, POS alignment, semantic relations, physical `harbor` sense first | Definitions/examples are not a full learner presentation; license/attribution still matter | Good open augmentation |
| Add WordNet/SemCor signals | Sense-tagged corpus evidence may improve ranking and evaluation | Historical/domain limitations; WordNet order is not enough by itself | Use as one ranking feature, not an authority |
| Add Tatoeba | More natural sentence candidates and multilingual support | Mixed sentence licenses, sense alignment, quality control | Optional example candidate source with provenance |
| License Cambridge learner content | Strong learner definitions, examples, level-oriented editorial work, offline possibilities | Cost, contract, redistribution constraints, dependency on vendor negotiation | Best high-quality commercial option to investigate |
| License Oxford learner content | Very strong learner methodology, frequency/CEFR resources | Standard API terms do not fit unrestricted local bundling; separate product agreement likely required | Consider only with a suitable enterprise/content agreement |
| License Collins content | Learner dictionaries, examples, audio, API route | Commercial cost and terms; local offline packaging must be negotiated | Viable commercial alternative |

## Recommended design

### 1. Separate source order from learner order

Do not overload `learner_score` with structural quality. Keep distinct fields or concepts:

```text
source_order             // order in the upstream source
learner_rank             // automatic product order for learners
learner_score            // build-time ranking evidence
learner_confidence       // confidence in the automatic ranking
rank_reason              // signals that contributed to the rank
rank_model_version       // reproducibility when the model changes
```

`source_order` should be a weak feature at most. A source’s first sense can be useful evidence, but it should not be treated as frequency.

### 2. Use an automatic learner-oriented ranking model

A practical first model can be deterministic and explainable:

```text
learner_rank score =
  lemma_frequency_signal
+ learner-list / CEFR signal
+ sense-frequency signal, when available
+ cross-source agreement
+ source-order signal (small weight)
+ clear-definition signal
+ neutral-example signal
- quotation-only penalty
- archaic/technical/regional penalty when not relevant to the learner band
- obscure or domain-specific penalty
- example ambiguity or social-distraction penalty
```

Important rules:

- A sense should not receive a large bonus merely because it has an example.
- A quotation should normally be secondary evidence or a secondary example, not automatically a primary example.
- Word frequency is lemma-level evidence; use corpus sense annotations or offline evaluation for sense-level ordering.
- A short definition is not automatically a good definition. Simple words, clarity, and semantic completeness matter more than character count.
- Cross-source agreement is useful, but sources can share ancestry and should not be counted as independent evidence without care.

### 3. Keep example selection separate

Example quality should remain separate from sense rank. The current build stores
source type and structural quality and selects retained examples without adding
per-word replacement content. Useful automatic features include:

- modern and ordinary usage;
- clearly demonstrates the target sense;
- contains the target word naturally;
- one main interpretation, with minimal ambiguity;
- suitable vocabulary difficulty;
- neutral and non-distracting context;
- useful collocation or grammatical frame;
- appropriate regional/register label;
- source type and license;
- source provenance.

Keep quotations when they are valuable, but label them as quotations. A valid
sentence involving petty thieves is not automatically a good first example for
a general vocabulary learner.

### 4. Use a fixed regression set

Evaluate a fixed set of approximately 300–500 high-frequency polysemous words.
Include `harbor`, `bank`, `fine`, `bear`, `charge`, `issue`, `run`, `mean`,
`point`, `hold`, and similar words.

For each word, record expected ranking properties:

- preferred learner sense;
- acceptable secondary senses;
- definition clarity score;
- example naturalness score;
- example-to-sense alignment score;
- register/sensitivity concerns;
- target learner level.

Measure:

- top-1 agreement with expected rankings;
- top-3 recall of common senses;
- definition readability;
- example naturalness and sense alignment;
- percentage of examples that fail automatic structural checks;
- ranking changes between rank-model versions.

This prevents optimizing a score that looks good in the database but feels wrong in practice.

### 5. Make the UI resilient to ranking uncertainty

Even with better ranking, the UI should communicate that a word can have multiple meanings:

- show one carefully selected core sense;
- show “Other common meanings” separately;
- retain usage labels such as noun/verb, formal, technical, or British;
- avoid presenting a quotation as if it were the canonical everyday example;
- optionally expose “Why this is the core meaning” internally for debugging.

## Implementation status

The automatic build-time ranking path is implemented:

1. Kaikki remains the canonical user-facing sense inventory.
2. Simple English Wiktionary and OEWN are optional alignment evidence only.
3. `learner_rank`, confidence, reason, and model version are stored in SQLite.
4. The app reads the precomputed rank and performs no semantic ranking at runtime.
5. `harbor` noun ranking is covered by Swift regression tests and the bundled database uses the nautical sense as rank 1.

There is intentionally no hand-authored per-word ranking file, database table,
or content-replacement path. The ranker is fully automatic and falls back to
Kaikki source order when external evidence is unavailable.

## Final recommendation

For Lexilo’s current offline architecture, the best default is:

1. **Keep Kaikki/English Wiktionary** for broad lexical coverage and source transparency.
2. **Add a learner-oriented ranking layer** that is independent of source order.
3. **Use OEWN and Simple English Wiktionary as open supplements**, with provenance and license metadata.
4. **Use frequency resources only for the level they support:** word frequency for lemmas and sense-tagged evidence for sense ranking.
5. **Investigate a Cambridge/Oxford/Collins license only if professional learner-dictionary quality justifies the cost and contractual complexity.**

In short: **the app needs an automatic learner-oriented ranking layer; it does not immediately need a different complete dictionary.** The `harbor` result is a good regression case showing why structural validation and learner-oriented ranking must be separate decisions.

## Local files examined

- [`CONTENT_SOURCES.md`](../CONTENT_SOURCES.md)
- [`scripts/build_lexicon.py`](../scripts/build_lexicon.py)
- [`Lexilo/Services/LexiconStore.swift`](../Lexilo/Services/LexiconStore.swift)
- [`Lexilo/Services/LearningService.swift`](../Lexilo/Services/LearningService.swift)
- [`Lexilo/Models/LearningModels.swift`](../Lexilo/Models/LearningModels.swift)
- [`Lexilo/Resources/LEXICON_NOTICES.md`](../Lexilo/Resources/LEXICON_NOTICES.md)

This document records the research that informed the current implementation;
the active code and bundled database now implement the automatic ranking design
described above.
