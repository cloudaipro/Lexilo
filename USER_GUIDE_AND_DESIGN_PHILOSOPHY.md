# Lexilo User Guide & Design Philosophy

_Updated for the codebase on August 14, 2026._

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

## 2. The four main areas

Lexilo is organised into four tabs:

| Tab | Purpose |
|---|---|
| **Today** | See today's workload and begin a focused practice session. |
| **Words** | Browse saved, upcoming, and dictionary words; inspect and manage individual senses. |
| **Memory** | Understand retention, future workload, fragile words, and practice history. |
| **Settings** | Adjust practice, speech, language support, imports, backups, sync, and quality controls. |

## 3. Today

The Today screen is the normal starting point. It shows:

- the number of distinct words practised today;
- your current study streak;
- a featured word; and
- the primary action to start practice.

Practice is organised into rounds. The first round contains the configured number of distinct words (five by default) and completes the day's minimum commitment. Lexilo serves due reviews first and fills any remaining places with upcoming words.

After a round, **Next Round** adds another group of the same size to today's cumulative word set. With the default setting, the total therefore grows from 5 to 10 to 15 distinct words, and can continue while eligible words are available. A missed retry or the other card direction does not increase this count: each vocabulary item counts once per day.

**Practice Again** is available after the first practised word, both on Today and on the completion screen. It repeats the whole cumulative set for today: after three five-word rounds it repeats 15 words. Practice Again is schedule-neutral—its answers do not create review logs, change adaptive intervals, add words to today's count, or affect the streak.

The featured word card also shows its current difficulty summary. New content is marked **Baseline** until a review measures it.

### How the featured word is chosen

The featured word is a daily spotlight, not necessarily the exact next card in the practice queue. Lexilo:

1. excludes mastered words (at least two active cards, all mastered);
2. prefers unmastered words with example sentences when any are available;
3. prioritises a word with at least one card due now and not already reviewed today;
4. uses the lowest successful-review count across that word's cards as the next tie-breaker; and
5. uses frequency rank as the final tie-breaker, favouring more common words.

Because new cards are due when they are created, an **Upcoming** word can be featured. The selection does not directly use the adaptive difficulty or retrievability values; those are shown as context, while the practice scheduler independently chooses the session cards.

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

1. Read the definition and part of speech.
2. Type the target word from memory.
3. If needed, request a hint showing the first letter and word length.
4. Tap **Check**.
5. Review the submitted and expected answers, pronunciation, and one example sentence.

Lexilo normalises case, surrounding punctuation, whitespace, and diacritics when checking an answer. Configured accepted variants are also valid. It does not use broad fuzzy matching, so a genuinely different spelling is not treated as correct.

Recall cards require production rather than self-grading. This keeps “I recognised it” separate from “I could produce it.”

## 5. What happens after an answer

Lexilo records more than a binary result. Scheduling can take into account:

- whether the answer was correct;
- how long retrieval took;
- whether a hint was used; and
- whether the item was marked too easy.

After an answer, the card shows a short explanation of when it will return and why. A missed card is scheduled for the next day and can also reappear later in the current active session, giving you an immediate second attempt without pretending the miss never happened.

## 6. Adaptive memory scheduling

Each card maintains its own memory state:

- **Difficulty** estimates how resistant the card is to learning.
- **Stability** estimates how long the memory can remain durable.
- **Retrievability** estimates the chance that you can recall it now.

Lexilo uses those values to choose the next interval. Correct, fast, unaided retrieval generally permits a longer interval. Slow or hinted retrieval is treated more cautiously. A failure sharply shortens the interval.

The default target retention is 90%. It is intentionally hidden during normal use so most people can simply practise. In **Settings → Quality and memory → Advanced scheduling**, it can be adjusted from 80% to 97%.

Higher target retention means more frequent reviews and a larger workload. Lower retention reduces workload but accepts more forgetting between reviews.

## 7. Two-way scheduling stays independent

Knowing one direction does not automatically prove the other. Lexilo therefore keeps separate memory records for:

- understanding a word from its form; and
- recalling the word from its meaning.

When possible, newly introduced sibling cards are placed on separate days. This reduces answer leakage and creates a more honest test of each direction.

In the Words and Memory screens, these abilities appear as separate **Understand** and **Recall** strength axes.

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

## 9. Practice controls and recovery actions

The practice-card menu includes controls for cases where scheduling alone is not enough:

- **Pause this sense** removes its cards from normal practice without deleting it.
- **Wrong sense** reports the mismatch, pauses that sense, and makes the next available sense eligible when possible.
- **Too easy** records an easy outcome so the scheduler can move it forward more aggressively.
- **Report content** records a content-quality issue for later review.

Paused senses can be resumed from the word-detail screen. These actions preserve history; they do not erase the word or its past reviews.

## 10. Words

The Words tab has three sections:

- **My Words** for material already in your learning collection;
- **Upcoming** for words approaching introduction; and
- **Dictionary** for browsing the built-in lexicon.

Open a word to see its state, part of speech, pronunciation, and two-way memory strength. Its senses are displayed as a stack, with inactive senses visually quieter than the current learning target.

Every learning-word row also shows a **Difficulty** value from 1 to 10. New cards display **Baseline** until a review measures them. Open a word to see the average difficulty for Understand and Recall; each sense then shows its two card-specific values. Higher values mean the scheduler has found that card harder to retain.

Each sense shows the available definition, usage label, collocations, examples, audio controls, priority, learning state, and card difficulty. Its menu lets you pause or resume it, report a mismatch, mark it too easy, or report content.

## 11. Memory

The Memory tab replaces a simple success counter with evidence about the state of your learning. It includes:

- **Estimated retention** across reviewed cards;
- **Due today**;
- the upcoming review load;
- a seven-day forecast;
- **Words at risk** with one-tap focused review;
- **Understand** and **Recall** strength;
- recent practice history; and
- optional advanced memory details.

The strength labels are designed for quick interpretation:

| Estimated strength | Label |
|---|---|
| 90% or higher | **Strong** |
| 75–89% | **Fading** |
| Below 75% | **Needs recall** |

These are estimates, not grades. Their purpose is to suggest an action: leave a strong memory alone, keep an eye on a fading one, or practise a fragile one.

## 12. Focused review

From **Words at risk**, you can start a review containing fragile cards rather than waiting for them to appear incidentally. The same recognition and recall rules still apply; focused review does not bypass the scheduler's evidence or turn a miss into a success.

## 13. Importing personal vocabulary

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

## 14. Backup, restore, and optional iCloud sync

In **Settings → Import and portability**, you can export a complete learning-data JSON backup and restore one later. The backup includes vocabulary, senses, scheduling state, review history, study-day records, reports, and lexicon migration metadata. Device preferences such as voice and words-per-round settings remain outside this snapshot.

Restore validates the incoming snapshot before replacing current data, and Lexilo maintains a rolling local backup for recovery.

Optional iCloud Drive sync can keep the snapshot available across your devices. Local storage remains the primary working copy. When local and iCloud snapshots differ, the newer valid snapshot is used.

No account is required for local use. iCloud availability depends on the device's iCloud configuration and on the app build having the required entitlement.

## 15. First-language support and translation provenance

Translations are optional aids, not replacements for the English definition.

A translation you add is initially labelled as a **personal, unreviewed** translation. After checking it yourself, you can mark it **reviewed by you**. Lexilo keeps this distinction visible so an unverified aid is never presented as authoritative content.

The app does not silently generate or overwrite translations.

## 16. Content quality dashboard

The quality dashboard in Settings helps identify material that may weaken a card. It reports counts for issues such as:

- missing pronunciation;
- missing examples;
- duplicate content;
- unusually long definitions;
- answer leakage; and
- user-submitted reports.

This makes quality work visible and actionable without interrupting every study session.

## 17. Sources and licenses

The bundled dictionary is derived from Open English WordNet 2025, and wordfreq values help order learning candidates. **Settings → Offline dictionary → Dictionary licenses and sources** shows the installed dataset version, entry counts, upstream sources, and license information. Pronunciation model sources are documented there as well.

## 18. Pronunciation and audio

Tap the speaker control on a word or revealed answer to hear it. Lexilo uses local speech components and bundled voices where available, with system speech as a fallback when necessary.

In **Settings → Pronunciation**, you can choose a voice and adjust speaking rate. The app previews the selected configuration so you can find a clear, comfortable voice.

Pronunciation is reinforcement, not proof of recall. On a recall card, audio and the example appear after checking the answer so they cannot reveal the target prematurely.

## 19. Daily rhythm and streaks

A study day follows the device's local calendar. Normal-round answers are recorded as you complete them. Practising the configured number of distinct words—the first round, five by default—completes that study day. Additional rounds grow today's total but are not required for the streak. Practice Again does not affect completion. Consecutive completed days build the streak; missing the first-round commitment for a day ends it.

The streak is a gentle continuity signal, not the main measure of learning. Retention and independent two-way memory remain more important.

## 20. Widget

The widget offers a passive glance at Lexilo from the Home Screen. It is intentionally lightweight: use the app for decisions, answers, and detailed memory information.

## Quick reference

| If you want to… | Go to… |
|---|---|
| Start today's reviews | **Today → Start practice** |
| Add more words today | Round completion or **Today → Next Round** |
| Repeat every word practised today | Round completion or **Today → Practice Again** |
| Understand a shown word | Recognition card → **Reveal → Know / Don't know** |
| Recall a word from meaning | Recall card → type the word → **Check** |
| Get a constrained clue | Recall card → **Hint** |
| Review fragile memories | **Memory → Words at risk** |
| Inspect or manage a sense | **Words → select a word → sense menu** |
| View word and card difficulty | **Words → select a word → MEMORY → DIFFICULTY** |
| Pause or resume a sense | Word detail → sense menu |
| Add personal vocabulary | **Settings → Import and portability → Import CSV/TSV** |
| Export or restore everything | **Settings → Import and portability** |
| Enable cross-device snapshots | **Settings → Import and portability → iCloud Drive** |
| Change the retention target | **Settings → Quality and memory → Advanced scheduling** |
| Check content problems | **Settings → Quality and memory → Content quality** |
| Inspect dictionary and voice sources | **Settings → Offline dictionary → Dictionary licenses and sources** |
| Change voice or speech rate | **Settings → Pronunciation** |
| Add or verify a translation | **Words → word detail → sense translation** |

## Troubleshooting

### No cards are available

Lexilo may have no other eligible due or upcoming words, or the relevant senses may be paused. Check **Words** for paused content and **Memory** for the upcoming forecast. You can still use **Practice Again** whenever today's cumulative set is not empty.

### A missed card appeared again immediately

That is expected. A miss may return later in the active session for reinforcement and is also scheduled for the next day.

### A typed answer was marked wrong

Lexilo ignores case, surrounding punctuation, extra whitespace, and diacritics. It accepts explicitly configured variants, but it does not guess broadly from a near match. Compare the submitted and expected spellings shown after checking.

### Pronunciation does not play

Check the device volume, then try another voice in **Settings → Pronunciation**. If a bundled voice is unavailable, Lexilo attempts to use a system voice.

### An expected meaning is not being practised

It may be an inactive extended or rare sense, or it may have been paused. Open the word in **Words** to inspect and resume the sense. Secondary senses also unlock naturally after the active sense becomes durable in both directions.

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

The target-retention setting expresses the real tradeoff: stronger expected recall costs more reviews. The normal interface hides the machinery; advanced settings expose it for learners who want control.

## 5. Evidence without unnecessary grading complexity

The scheduler benefits from response time, hints, typed correctness, and explicit easy signals. The learner should not have to translate those signals into a complicated rating scale after every card.

Recognition keeps a simple self-assessment. Recall uses an objective typed check. The software carries the administrative burden.

## 6. Delay cues until after retrieval

Audio, examples, related phrasing, and answer text can all become clues. On recall cards, Lexilo withholds them until after the learner commits an answer.

Hints are intentionally constrained and recorded. Help is available, but it changes the evidence the scheduler receives.

## 7. Context should strengthen, not leak

Examples, usage labels, and collocations make a meaning memorable and usable. They belong in the explanation and word-detail layers, where they enrich understanding after a clean retrieval attempt.

Definitions should be concise enough to test one idea. Examples should sound natural and should not reveal the answer on the front of a production card.

## 8. Honest progress should lead to an action

Lexilo avoids presenting raw review totals as mastery. Retention estimates, forecast load, fragile words, and two-way strength are closer to the learner's real questions:

- What is durable?
- What is fading?
- What needs attention now?
- What workload is coming?

“Strong,” “Fading,” and “Needs recall” are not rewards or punishments. They are compact decisions.

## 9. One primary decision at a time

The study surface stays narrow:

**Recognition**

> Prompt → Think → Reveal → Self-assess → Schedule

**Recall**

> Meaning → Think → Type → Check → Correct → Schedule

Secondary controls live in hints, disclosure sections, and menus. The main action remains visually dominant, while expert controls remain reachable.

## 10. A finite round with an optional longer day is a feature

Lexilo is designed for repeatable practice rather than an endless feed. Each round has a clear, configurable size; due cards come first; and the upcoming forecast makes future cost visible. The first round creates a small daily commitment, while **Next Round** gives the learner explicit control over whether today's set grows.

The system should make stopping after any completed round feel valid. Continuing is a deliberate learner choice, and **Practice Again** reinforces the chosen daily set without silently changing its memory schedule.

## 11. Learner agency should preserve history

Real content is imperfect and personal priorities change. Pause, resume, Wrong sense, Too easy, and Report content give the learner direct control without destructive resets.

History remains intact so that scheduling, diagnostics, and recovery continue to have evidence.

## 12. Progressive disclosure protects focus

The default experience should require almost no scheduling knowledge. Detailed memory values, rare senses, provenance, quality diagnostics, and retention tuning appear when they become relevant.

This is not the removal of power. It is the sequencing of power.

## 13. Local-first, portable by choice

Core study, dictionary access, scheduling, history, and supported speech work from local data. The learner does not need an account to begin or continue practising.

Portability is explicit: full backups are exportable, restores are validated, and iCloud snapshot sync is optional. Personal learning data should remain useful even when a network service is absent.

## 14. Content provenance deserves a visible place

Built-in Open English WordNet content, personal imports, and user translations do not have equal authority. Lexilo preserves their source and review status instead of flattening them into one undifferentiated answer.

Personal translations begin unreviewed. Imported meanings remain personal. Reports feed a quality dashboard. Trust comes from showing what the app knows about its content—and what it does not.

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
