# Lexilo User Guide & Design Philosophy

_Updated for the codebase on August 16, 2026._

Lexilo is a focused vocabulary-memory coach. It helps you learn precise word senses, practise both understanding and recall, and return to each card when your memory needs it—not merely on a fixed calendar.

The core loop is deliberately small:

> Practise what is due. Retrieve before receiving help. Let the schedule adapt.

This document describes the current app behavior and the product principles behind it.

---

# Part I — User Guide

## 1. First launch

The welcome flow introduces Lexilo's memory-based approach and lets you enable optional first-language support. Available language choices include Spanish, Simplified Chinese, Japanese, Korean, French, German, and Other.

English remains the primary learning language. Enabling language support does not silently machine-translate the dictionary. Translations are added explicitly and carry a visible provenance label.

You can change the language-support setting later in **Settings**.

## 2. The three main areas

Lexilo is organised into three tabs:

| Tab | Purpose |
|---|---|
| **Today** | See today's workload and begin a focused practice session. |
| **Words** | Browse saved and upcoming words; inspect and manage individual senses. |
| **Settings** | Adjust practice, speech, vocabulary, language support, widget content, imports, backups, and sync. |

## 3. Today

The Today screen is the normal starting point. It shows:

- progress through today's round;
- your current study streak when one is active;
- a featured word; and
- the primary action to start practice.

Practice is organised into rounds. The first round contains the configured number of distinct words (five by default) and completes the day's minimum commitment. Lexilo serves due reviews first and fills any remaining places with upcoming words.

After a round, **Next Round** adds another group of the same size to today's cumulative word set. With the default setting, the total therefore grows from 5 to 10 to 15 distinct words, and can continue while eligible words are available. A missed retry or the other card direction does not increase this count: each vocabulary item counts once per day.

**Practice Again** is available after the first practised word, both on Today and on the completion screen. It repeats the whole cumulative set for today: after three five-word rounds it repeats 15 words. Practice Again is schedule-neutral—its answers do not create review logs, change adaptive intervals, add words to today's count, or affect the streak.

### How the featured word is chosen

The featured word is a daily spotlight, not necessarily the exact next card in the practice queue. Lexilo:

1. excludes mastered words (at least two active cards, all mastered);
2. prefers unmastered words with example sentences when any are available;
3. prioritises a word with at least one card due now and not already reviewed today;
4. uses the lowest successful-review count across that word's cards as the next tie-breaker; and
5. uses frequency rank as the final tie-breaker, favouring more common words.

Because new cards are due when they are created, an **Upcoming** word can be featured. The featured word is a calm daily spotlight; the practice scheduler independently chooses the session cards.

## 4. Two different practice directions

Each active sense can generate two independent cards. They train related but different skills.

### Recognition: word → meaning

1. Read the word, part of speech, and pronunciation.
2. Think of its meaning before revealing anything.
3. Tap **Reveal**.
4. Compare your answer with the definition.
5. Choose **Know** or **Don't know**.

This direction measures whether you understand the word when you encounter it.

### Recall: meaning → word

1. Read the complete definition and part of speech. Long definitions wrap across lines instead of being intentionally shortened with an ellipsis.
2. Type the target word from memory.
3. If needed, request a hint showing the first letter and word length.
4. Tap **Check** when you have an answer. If you do not know it yet, tap **Reveal answer** below **Check**.
5. Review the expected answer, pronunciation, and one example sentence. A revealed answer is shown as **Answer revealed**, without an empty “You wrote” response.

Lexilo normalises case, surrounding punctuation, whitespace, and diacritics when checking an answer. Configured accepted variants are also valid. It does not use broad fuzzy matching, so a genuinely different spelling is not treated as correct.

Recall cards require production rather than self-grading. This keeps “I recognised it” separate from “I could produce it.” The two actions are intentionally equal in size: **Check** supports an attempted answer, while **Reveal answer** gives you an honest path when retrieval is not yet available.

## 5. What happens after an answer

Lexilo records more than a binary result. Scheduling can take into account:

- whether the answer was correct;
- how long retrieval took;
- whether a hint was used; and
- whether the item was marked too easy.

After an answer, the card shows a short explanation of when it will return and why. A missed card is scheduled for the next day and can also reappear later in the current active session, giving you an immediate second attempt without pretending the miss never happened.

Using **Reveal answer** counts as an unanswered miss. It records the miss without storing a blank response, shows the answer, and follows the same next-day scheduling and in-session reinforcement path as an incorrect typed answer.

## 6. Adaptive memory scheduling

Lexilo adapts each card's next interval from your actual answers. Correct, fast, unaided retrieval generally permits a longer interval. Slow or hinted retrieval is treated more cautiously, and a failure returns sooner.

These scheduler calculations stay in the background. You do not need to interpret scores or tune a memory model; the app turns the evidence into the next useful review date.

## 7. Two-way scheduling stays independent

Knowing one direction does not automatically prove the other. Lexilo therefore keeps separate memory records for:

- understanding a word from its form; and
- recalling the word from its meaning.

When possible, newly introduced sibling cards are placed on separate days. This reduces answer leakage and creates a more honest test of each direction.

The two directions remain independent inside the scheduler, even though their internal scores are not shown in the interface.

## 8. Sense-aware learning

A word may have several meanings. Lexilo stores them as separate senses rather than merging them into one oversized card.

Senses can include:

- a definition;
- part of speech;
- pronunciation;
- usage or register labels;
- collocations;
- up to three examples;
- priority: **Core**, **Extended**, or **Rare**; and
- an optional translation with provenance.

Core senses are active first. Extended and rare senses stay de-emphasised until they are useful. Lexilo unlocks secondary senses sequentially after the currently active sense has become durable in both directions. A direction is considered mastered when its stability reaches at least 21 days.

This progression prevents an uncommon meaning from competing with the meaning you are still trying to establish.

## 9. Practice focus

Practice cards intentionally expose only the actions needed for the current learning step: reveal the answer, report whether it was known, check a typed answer, request a hint, and continue. Advanced scheduling and content-management controls stay out of the default learner interface so the practice loop remains focused on learning English rather than internal scheduling or dictionary terminology.

## 10. Words

The Words tab in release builds has two sections:

- **My Words** for material already in your learning collection;
- **Upcoming** for words approaching introduction.

Debug builds may additionally expose a development-only **Dictionary** section for searching the bundled offline lexicon. It does not add anything to your study list automatically.

Open a word to see its state, part of speech, pronunciation, and meanings. Meanings are displayed as a stack, with inactive ones visually quieter than the current learning target.

Each meaning shows the available definition, usage label, common pairings, examples, audio controls, priority, and learning state.

Scheduler difficulty and memory estimates are intentionally not displayed. They influence review timing but do not help with the learner's immediate task: understanding and using the word.

## 11. Importing personal vocabulary

Lexilo can import UTF-8 CSV or TSV files. The importer uses a three-step flow:

1. **Choose** a file.
2. **Map** columns to Lexilo fields.
3. **Preview** the first five rows and confirm the import.

Required fields:

- **Word**
- **Meaning**

Optional fields:

- **Example**
- **Tags**

Existing words are identified during preview. You can merge an imported meaning as a new sense or skip it. Each imported sense receives both recognition and recall cards, just like built-in content.

Imported vocabulary remains distinguishable as personal content and can coexist with dictionary senses.

## 12. Backup, restore, and optional iCloud sync

In **Settings → Your data**, you can export a complete learning-data JSON backup and restore one later. The backup includes vocabulary, senses, scheduling state, review history, study-day records, reports, and lexicon migration metadata. Device preferences such as voice and words-per-round settings remain outside this snapshot.

Restore validates the incoming snapshot before replacing current data, and Lexilo maintains a rolling local backup for recovery.

Optional iCloud Drive sync can keep the snapshot available across your devices. Local storage remains the primary working copy. When local and iCloud snapshots differ, the newer valid snapshot is used.

No account is required for local use. iCloud availability depends on the device's iCloud configuration and on the app build having the required entitlement.

## 13. First-language support and translation provenance

Translations are optional aids, not replacements for the English definition.

A translation you add is initially labelled as a **personal, unreviewed** translation. After checking it yourself, you can mark it **reviewed by you**. Lexilo keeps this distinction visible so an unverified aid is never presented as authoritative content.

The app does not silently generate or overwrite translations.

## 14. Sources and licenses

The bundled Learning Core is derived from the official Simple English Wiktionary Wikimedia dump (`simplewiktionary-20260801`); CMUdict fills IPA gaps only, and wordfreq values help order learning candidates. Example records are kept only when they contain the learning word or a valid inflected form and read as complete usage sentences; a definition, description, or collocation is never presented as an example. **Settings → Vocabulary → Dictionary sources and licenses** shows upstream sources and license information. Pronunciation model sources are documented there as well.

## 15. Pronunciation and audio

Tap the speaker control on a word or revealed answer to hear it. Lexilo uses local speech components and bundled voices where available, with system speech as a fallback when necessary.

In **Settings → Pronunciation**, you can choose a voice and adjust speaking rate. The app previews the selected configuration so you can find a clear, comfortable voice.

Pronunciation is reinforcement, not proof of recall. On a recall card, audio and the example appear after checking the answer so they cannot reveal the target prematurely.

Practice definitions preserve the complete available text. When a definition is long, the card grows and wraps it rather than replacing the ending with an ellipsis.

## 16. Daily rhythm and streaks

A study day follows the device's local calendar. Normal-round answers are recorded as you complete them. Practising the configured number of distinct words—the first round, five by default—completes that study day. Additional rounds grow today's total but are not required for the streak. Practice Again does not affect completion. Consecutive completed days build the streak; missing the first-round commitment for a day ends it.

The streak is a gentle continuity signal, not a grade or the main measure of learning.

## 17. Widget

Lexilo supports Small and Medium Home Screen widgets. Both use the current featured word described in Section 3; the widget is a glanceable study prompt, not a separate practice queue.

- **Small** shows the LEXILO label, the complete learning word at an adaptive size, and **Tap to practise**. It does not show an example or definition, keeping the word as the focus.
- **Medium** shows the LEXILO label, the learning word, and one secondary text block below it. The default secondary content is the complete definition.
- To choose the Medium widget content, open **Settings → Widget → Medium widget shows** and select **Definition** or **Example**. The setting is Definition by default.
- Medium definitions and examples wrap without intentional truncation or ellipses. If the selected example does not fit at the preferred size, Lexilo tries a smaller presentation and then another complete available example; it never cuts a sentence mid-text.
- Tap either widget to open Lexilo's practice flow. The displayed snapshot is refreshed when learning data or the widget-content setting changes and on the widget's normal timeline schedule.

## Quick reference

| If you want to… | Go to… |
|---|---|
| Start today's reviews | **Today → Start practice** |
| Add more words today | Round completion or **Today → Next Round** |
| Repeat every word practised today | Round completion or **Today → Practice Again** |
| Understand a shown word | Recognition card → **Reveal → Know / Don't know** |
| Recall a word from meaning | Recall card → type the word → **Check** |
| Admit you do not know a recall answer | Recall card → **Reveal answer** |
| Get a constrained clue | Recall card → **Hint** |
| Inspect a meaning | **Words → select a word** |
| Add personal vocabulary | **Settings → Your data → Import CSV or TSV** |
| Export or restore everything | **Settings → Your data** |
| Enable cross-device snapshots | **Settings → Your data → Sync backup with iCloud** |
| Inspect dictionary and voice sources | **Settings → Vocabulary → Dictionary sources and licenses** |
| Choose the Medium widget content | **Settings → Widget → Medium widget shows** |
| Change voice or speech rate | **Settings → Pronunciation** |
| Add or verify a translation | **Words → word detail → sense translation** |

## Troubleshooting

### No cards are available

Lexilo may have no other eligible due or upcoming words, or the relevant meanings may be paused. Check **Words** for paused content. You can still use **Practice Again** whenever today's cumulative set is not empty.

### A missed card appeared again immediately

That is expected. A miss may return later in the active session for reinforcement and is also scheduled for the next day.

### A typed answer was marked wrong

Lexilo ignores case, surrounding punctuation, extra whitespace, and diacritics. It accepts explicitly configured variants, but it does not guess broadly from a near match. Compare the submitted and expected spellings shown after checking.

### I do not know the answer

Tap **Reveal answer** below **Check**. Lexilo will show the expected word, record an unanswered miss, and schedule the card to return tomorrow. You can continue without entering a placeholder response.

### A definition looks cut off

Practice cards wrap long definitions to preserve the complete available text. If the source content itself appears incomplete, note the word and issue for later content review.

### Pronunciation does not play

Check the device volume, then try another voice in **Settings → Pronunciation**. If a bundled voice is unavailable, Lexilo attempts to use a system voice.

### An expected meaning is not being practised

It may be an inactive extended or rare sense. Secondary senses also unlock naturally after the active sense becomes durable in both directions.

### An import row is rejected

Confirm that the file is UTF-8 CSV or TSV and that every imported row maps both **Word** and **Meaning**. Use the preview to verify delimiter detection and column mapping before confirming.

### iCloud sync is unavailable

Confirm that iCloud Drive is enabled on the device. Some development or independently signed builds may not include the required iCloud container entitlement; local storage and manual backup continue to work.

---

# Part II — Design Philosophy

## 1. Retrieval over exposure

Reading a definition feels fluent but gives weak evidence of memory. Lexilo asks the learner to attempt retrieval before showing the answer.

Recognition and recall use different interactions because they test different claims:

- **Recognition:** “I understood this word when I saw it.”
- **Recall:** “I produced this word from its meaning.”

The UI should never confuse exposure with proof.

## 2. Two-way knowledge is complete knowledge

Vocabulary is useful in both reading and expression. A single combined score can hide a serious imbalance, so Lexilo schedules and visualises Understand and Recall separately.

This principle shapes the data model, card design, progress display, and the rule that sibling directions should not teach each other on the same day.

## 3. Meanings are the learning unit

The product is sense-aware. A word is a container; the practical learning unit is one meaning in one context.

Core senses lead. Extended and rare senses arrive progressively. This keeps prompts precise, makes wrong-sense reports recoverable, and avoids turning a familiar spelling into a confusing bundle of unrelated definitions.

## 4. Memory should adapt, not march through a fixed ladder

A fixed sequence of intervals treats every memory and every answer as equal. Lexilo instead updates difficulty, stability, and retrievability from observed performance.

Stronger expected recall costs more reviews, so the scheduler uses a balanced default and handles that tradeoff consistently. The learner should not need to tune the model.

## 5. Evidence without unnecessary grading complexity

The scheduler benefits from response time, hints, typed correctness, and explicit easy signals. The learner should not have to translate those signals into a complicated rating scale after every card.

Recognition keeps a simple self-assessment. Recall uses an objective typed check. The software carries the administrative burden.

## 6. Delay cues until after retrieval

Audio, examples, related phrasing, and answer text can all become clues. On recall cards, Lexilo withholds them until after the learner commits an answer.

Hints are intentionally constrained and recorded. Help is available, but it changes the evidence the scheduler receives.

## 7. Context should strengthen, not leak

Examples, usage labels, and collocations make a meaning memorable and usable. They belong in the explanation and word-detail layers, where they enrich understanding after a clean retrieval attempt.

Definitions should be concise enough to test one idea. When the source definition is longer, the interface wraps it rather than hiding its ending with an ellipsis. Examples should sound natural and should not reveal the answer on the front of a production card.

## 8. Scheduling evidence should stay behind the action

Lexilo uses answer quality, timing, hints, and review history to decide when a card should return. Those signals are valuable to the scheduler, but raw retention, difficulty, and forecast values ask the learner to manage the algorithm instead of learning the word.

The interface therefore presents the result of the calculation—a clear practice queue and a simple next-review explanation—rather than a dashboard of internal estimates.

## 9. One primary decision at a time

The study surface stays narrow:

**Recognition**

> Prompt → Think → Reveal → Self-assess → Schedule

**Recall**

> Meaning → Think → Type → Check → Correct → Schedule

> Meaning → Think → Reveal answer → Review → Needs recall → Schedule

Secondary controls live in hints, disclosure sections, and menus. The main action remains visually dominant, while expert controls remain reachable.

## 10. A finite round with an optional longer day is a feature

Lexilo is designed for repeatable practice rather than an endless feed. Each round has a clear, configurable size, and due cards come first. The first round creates a small daily commitment, while **Next Round** gives the learner explicit control over whether today's set grows.

The system should make stopping after any completed round feel valid. Continuing is a deliberate learner choice, and **Practice Again** reinforces the chosen daily set without silently changing its memory schedule.

## 11. Learner agency should preserve history

Real content is imperfect and personal priorities change. Direct answer feedback, repeat practice, and preserved history give the learner control without requiring a dense set of recovery controls or destructive resets.

History remains intact so that scheduling, diagnostics, and recovery continue to have evidence.

## 12. Progressive disclosure protects focus

The default experience should require no scheduling knowledge. Memory scores, forecast diagnostics, quality counters, and retention tuning stay out of the learner interface. Rare meanings and provenance appear only where they help someone understand or manage content.

This is not the removal of adaptive learning. It is the removal of algorithm management from the learning task.

## 13. Local-first, portable by choice

Core study, dictionary access, scheduling, history, and supported speech work from local data. The learner does not need an account to begin or continue practising.

Portability is explicit: full backups are exportable, restores are validated, and iCloud snapshot sync is optional. Personal learning data should remain useful even when a network service is absent.

## 14. Content provenance deserves a visible place

Built-in Simple English Wiktionary content, personal imports, and user translations do not have equal authority. Lexilo preserves their source and review status instead of flattening them into one undifferentiated answer.

Personal translations begin unreviewed. Imported meanings remain personal. Reports feed internal quality review. Trust comes from showing what the app knows about its content—and what it does not.

## 15. Calm visual language supports hard thinking

The interface uses restrained color, generous spacing, rounded cards, and strong typography. Visual emphasis communicates hierarchy:

- the current prompt is dominant;
- the next action is obvious;
- inactive senses recede;
- warnings and fragile memories are visible without becoming alarming; and
- advanced detail does not compete with daily practice.

The design should feel quiet because retrieval itself is demanding.

---

# Product Promise

Lexilo does not promise effortless fluency or reward endless tapping. It promises a clear daily practice, honest evidence about memory, precise sense-based content, and control over the data and material that shape your learning.
