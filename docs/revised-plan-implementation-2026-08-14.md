# Revised Product Plan Implementation

> Implementation date: August 14, 2026
> Scope: Tasks 1–9 and all UI changes from “Revised product plan after the Anki audit”
> Excluded by request: P2 tasks 10 (licensed human audio) and 11 (curated packs)

## Delivered capabilities

| Plan item | Implementation |
|---|---|
| 1. Adaptive memory model | Each card persists difficulty, stability, retrievability, outcome, latency, and pause state. Scheduling targets 90% retention by default and responds to correctness, latency, hints, and “Too easy.” Advanced settings allow an 80–97% target. |
| 2. Objective production | Meaning-to-word cards require a typed response. Scoring normalizes case, punctuation, and diacritics, supports accepted variants, records the response/latency/hint use, and shows the submitted and expected forms. |
| 3. Sense-aware content | A vocabulary item now acts as the lemma parent for core, extended, and rare senses. Senses store source ID, usage label, examples, collocations, translation provenance, activation, and pause state. Each sense has separate recognition and recall cards. Secondary senses unlock sequentially after every active direction is stable. |
| 4. Recovery actions | Practice and word detail provide Pause, Wrong sense, Too easy, and Report content actions. Actions persist and affect scheduling or sense activation. |
| 5. Memory screen | The former Progress tab is now Memory, with estimated retention, today’s load, seven-day forecast, fading words, one-tap focused review, direction strength, history, and an advanced explanation sheet. |
| 6. Constrained import | A three-step CSV/TSV flow chooses a file, maps Word/Meaning/Example/Tags, previews five rows, identifies existing words, and either skips duplicates or merges them as new senses. Every imported sense generates two directions. |
| 7. Portability | Settings can export and explicitly restore a complete JSON snapshot. Optional iCloud Drive synchronization uses modified timestamps while local storage remains available. Existing local snapshots continue to keep a rolling backup. |
| 8. Content quality | A local dashboard counts missing IPA/examples, duplicate senses, definition-length flags, answer leakage, and learner reports. Usage labels come from Open English WordNet; helpful collocations are derived from examples. |
| 9. First-language support | Onboarding and Settings can enable a first-language layer. English stays primary. Personal translations are visibly unreviewed until the learner confirms them, and the app does not silently generate or present machine translation as authoritative. |

## UI delivery

### Practice

- Recall cards use a native text field and one Check action.
- Feedback includes exact submitted and expected forms, pronunciation, one post-answer example, and the next-review explanation.
- The overflow menu contains recovery actions without crowding the main card.
- Recognition and recall siblings retain the separate-day rule.

### Word detail

- Understand and Recall are shown as separate memory axes.
- Core, extended, and rare senses appear as a stack with register, collocations, examples, pronunciation actions, translation provenance, and per-sense controls.
- Inactive senses are de-emphasized and explain their locked or paused state.

### Memory

- The top summary shows estimated retention, due today, and the upcoming load.
- The forecast and “Words at risk” are actionable.
- Scheduler internals remain behind an Advanced surface.

### Import

- File, mapping, and preview are explicit steps.
- Duplicate words are labeled before import.
- The interface explains that two practice directions are generated.

## Data compatibility and safety

- New fields use tolerant decoding defaults, so earlier JSON snapshots remain loadable.
- Existing cards are migrated to the core sense without losing IDs or review history.
- Restore validates decoded content before replacing active state; normal saving preserves the prior valid snapshot as a backup.
- iCloud is opt-in. Enabling it on a fresh local history prefers an existing cloud snapshot; otherwise the newest modified snapshot wins.
- Enabling iCloud for a signed distribution build requires the corresponding iCloud container capability in the Apple Developer profile. The project entitlement is included.

## Verification

- Simulator build succeeds with code signing disabled.
- 28 unit tests pass, including adaptive scheduling, signal capture, sequential sense unlocking, legacy snapshot recovery, sense loading, CSV quoting/mapping, import/merge, export/restore, translation review, pause behavior, and content reporting.
- The original full recognition practice UI test passes.
- A dedicated typed-production UI test passes and verifies the correction, submitted/expected forms, next-review message, and Continue action.
