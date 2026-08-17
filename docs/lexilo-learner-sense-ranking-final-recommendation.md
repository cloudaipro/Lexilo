# Lexilo Learner-Oriented Sense Ranking — Final Recommendation (Historical)

> Historical note: this recommendation predates the source migration. The
> active implementation now uses the official Simple English Wiktionary dump
> as its canonical inventory; the ranking concepts below remain useful as
> background only.

## Final Conclusion

The recommended direction for Lexilo is to build a **learner-oriented sense ranking pipeline at database build time**.

The main issue is not that Kaikki / English Wiktionary contains invalid data. The issue is that source order and structural quality are being treated as if they represented learner priority.

For example, with **harbor**, the figurative sense can outrank the normal nautical sense because the current score rewards source position, example presence, and definition length. Those are useful for data-quality checks, but they are not reliable indicators of which meaning a learner should see first.

The best solution is therefore:

- Keep **Kaikki / English Wiktionary** as the canonical sense inventory.
- Use **Simple English Wiktionary**, **Open English WordNet (OEWN)**, usage labels, and sense-frequency signals as ranking evidence.
- Compute the final learner-oriented rank before shipping the SQLite database.
- Keep the iOS app runtime simple: it only reads the precomputed order.

---

## Recommended Architecture

```text
                         BUILD TIME

Kaikki / Wiktionary
        ↓
Normalize + validate senses
        ↓
Learner Sense Ranker
        │
        ├─ Simple English Wiktionary alignment
        ├─ Open English WordNet alignment
        ├─ Sense-frequency / learner evidence
        ├─ Usage / register labels
        └─ Kaikki source order as final fallback
        ↓
Final learner_rank
        ↓
Regression / consistency validation
        ↓
lexilo.sqlite


                         RUNTIME

lexilo.sqlite
        ↓
ORDER BY learner_rank
        ↓
Lexilo UI
```

This keeps all complex semantic work out of the app. Runtime cost is effectively negligible.

---

## Core Design Principle

**Kaikki remains the canonical user-facing sense inventory.**

Simple English Wiktionary and OEWN should normally be used as **evidence for ranking Kaikki senses**, not inserted as additional user-facing sense rows.

This avoids duplicate or competing definitions.

For example:

```text
Kaikki:
"A sheltered expanse of water, adjacent to land..."

Simple English Wiktionary:
"a protected area of water where ships are safe"

OEWN:
"a sheltered port where ships can..."
```

These should all support the conclusion that the same Kaikki nautical sense is the learner-oriented primary meaning.

They should not become three separate definitions shown to the user.

---

## Why Cross-Dictionary Alignment Is the Hard Part

Rebuilding SQLite scores is easy.

Runtime ranking is easy.

The difficult part is:

```text
Kaikki sense
       ↕
Simple Wiktionary sense
       ↕
OEWN synset
```

Sense inventories do not align one-to-one.

Possible cases include:

- Simple Wiktionary combines two senses that Kaikki separates.
- OEWN splits a dictionary sense into multiple synsets.
- Some Kaikki senses have no OEWN match.
- Same lemma + same part of speech does not imply same meaning.
- External source order is not automatically learner-frequency order.

Therefore, automatic alignment should produce **evidence and confidence**, not unquestionable truth.

---

## Recommended Ranking Policy

Use a hierarchy rather than one giant weighted score.

### Priority order

1. **Strong learner-oriented or sense-frequency evidence**
2. **Cross-source semantic agreement**
3. **General/common usage vs. technical, archaic, regional, or rare labels**
4. **External source rank as supporting evidence**
5. **Kaikki source order as the final fallback**

A numeric score can still be used internally for tie-breaking, but the architecture should not depend entirely on a large opaque formula.

---

## Separate Sense Ranking from Example Quality

This is one of the most important changes.

The questions:

- “Which sense should a learner see first?”
- “Which example best demonstrates this sense?”

should be handled separately.

The existence of a good example should not strongly increase a sense's learner priority.

The current `harbor` problem demonstrates why: a mediocre but structurally valid example can cause a less useful sense to outrank the normal everyday meaning.

Example quality should primarily affect **example selection**, not **sense selection**.

---

## Recommended Database Fields

Do not overwrite the original source order.

Keep learner ranking as separate metadata.

Suggested fields:

```text
source_order
learner_rank
learner_score
learner_confidence
rank_reason
rank_model_version
```

### Meaning of the fields

- `source_order`: Original upstream order for provenance.

- `learner_rank`: Final deterministic display order: 1, 2, 3, ...

- `learner_score`: Internal build-time ranking evidence.

- `learner_confidence`: Confidence in the automatic ranking decision.

- `rank_reason`: Explanation of why the rank was assigned.

- `rank_model_version`: Allows reproducible rebuilds and regression analysis.

The app mainly needs `learner_rank`. The other values are extremely useful for QA and debugging.

---

## Confidence Handling

Automatic alignment should be confidence-aware.

Conceptually:

```text
high confidence
    → use as ranking evidence

medium confidence
    → use only as weak supporting evidence

low confidence
    → ignore and fall back
```

An important invariant should be:

> An uncertain external match must never make the ranking worse than simply falling back to Kaikki source order.

The exact thresholds can be tuned later.

---

## Role of Each Source

### Kaikki / English Wiktionary

Use for:

- broad lexical coverage;
- canonical sense storage;
- definitions, examples, labels, and provenance.

Do not assume source order equals learner frequency.

### Simple English Wiktionary

Use for:

- learner-oriented signal;
- simpler sense presentation;
- supporting evidence for common sense ordering.

Do not depend on it for complete coverage.

### Open English WordNet

Use for:

- semantic alignment;
- synset structure;
- cross-source sense confirmation.

Do not treat it as a complete learner-facing dictionary.

### Frequency Resources

Distinguish:

- **lemma frequency** — tells whether the word itself is common;
- **sense frequency** — helps determine which meaning is common.

Lemma frequency alone cannot determine which sense of a polysemous word should rank first.

---

## Build Pipeline

Recommended database generation flow:

```text
Import Kaikki
    ↓
Validate definitions/examples
    ↓
Align Simple English Wiktionary
    ↓
Align OEWN
    ↓
Calculate learner-oriented features
    ↓
Produce automatic learner ranking
    ↓
Validate ranking invariants
    ↓
Build SQLite database
```

The iOS app then performs only a simple query such as:

```sql
SELECT *
FROM senses
WHERE lexeme_id = ?
ORDER BY learner_rank ASC;
```

---

## Regression Testing

Do not evaluate the system only by looking at scores.

Evaluate whether the learner-oriented ordering is actually correct for a reviewed set of words.

Recommended regression cases:

- harbor
- bank
- run
- bear
- charge
- fine
- issue
- hold

Tests should verify that:

- the intended primary sense is rank 1;
- ranks are deterministic;
- every lexeme/POS has exactly one primary sense;
- low-confidence matches do not displace safe fallback behavior;
- technical or rare senses do not unexpectedly outrank common everyday meanings.

`harbor` should become a permanent regression test:

```text
harbor / noun
→ nautical sense must be primary
```

---

## Final Engineering Goal

Avoid claiming:

> Lexilo will always produce the objectively correct sense order.

There is often no single universally correct order across all learners, corpora, regions, and editorial philosophies.

A better goal is:

> **Lexilo generates a deterministic learner-oriented sense ranking from multiple lexical signals, with confidence scoring and Kaikki order as the final fallback.**

---

## Final Recommendation

Proceed with the build-time **Learner Sense Ranker**.

The strongest architecture is:

- **Kaikki** as the canonical dictionary source;
- **Simple English Wiktionary** as learner-oriented evidence;
- **OEWN** as semantic alignment evidence;
- **sense-frequency and usage signals** as supporting features;
- **Kaikki order** only as the final fallback;
- **precomputed `learner_rank`** stored in SQLite;
- **regression testing** against a reviewed learner-oriented gold set.

This approach is efficient, deterministic, offline-friendly, and substantially better aligned with Lexilo's purpose than either replacing Kaikki or dynamically combining multiple dictionaries inside the app. It contains no hand-authored per-word ranking or content-replacement path.
