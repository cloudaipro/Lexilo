PRODUCT PROPOSAL \| iOS LEXILO A focused vocabulary-learning app built
around simple recall, spaced repetition, and daily consistency.

Working name: Lexilo Prepared August 2026

# 1. Executive Summary

Lexilo is an iOS vocabulary-learning app designed for users who want the
memory benefits of spaced repetition without the setup and complexity of
traditional flashcard systems. The product automatically manages what to
study, when to review it, and how to test recall. Core product idea.
Every vocabulary item generates two independent learning cards: one
tests recognition (word → definition) and the other tests active recall
(definition → word). The paired cards are deliberately prevented from
appearing on the same day, reducing short-term cueing and creating a
more meaningful memory test. \## Product Positioning \## Target Users -
English learners who want a structured daily vocabulary habit. -
Students preparing for academic, professional, or standardized English
use. - Advanced learners who understand words when reading but struggle
to recall them actively. - Users who find Anki powerful but too
configurable or time-consuming. \## Product Principles

# 2. Learning System

## 2.1 Vocabulary Item and Paired Cards

Each vocabulary item is the parent object for two separately scheduled
cards: - Recognition Card --- shows the word first; reveal displays
definition and example. - Recall Card --- shows the definition/context
first; reveal displays the target word. Scheduling constraint: paired
cards for the same vocabulary item must never be served on the same
calendar day. \## 2.2 Review Interaction \## 2.3 Recommended V1 Interval
Model The initial release should use a transparent fixed progression
rather than exposing Anki-style difficulty controls. This keeps the
experience understandable and gives the team clean behavioral data
before adopting a more advanced scheduler. \## 2.4 Daily Session
Composition 1. Due reviews are served first. 1. Failed cards are
recycled to the end of the current session. 1. New vocabulary is
introduced up to the user's daily limit. 1. The paired reverse-direction
card becomes eligible on a later day, never the same day. \## 2.5
Mastery Vocabulary-level mastery is reached only when both directions
independently meet the mastery threshold. A learner who recognizes a
word but cannot retrieve it from meaning remains in Learning status. \#
3. Content & Pronunciation Strategy \## 3.1 Vocabulary Content Lexilo
should ship with a curated, frequency-ranked English vocabulary
database. Each entry should support: - word / lemma - part of speech -
concise definition - 1--3 example sentences - IPA where available -
source/license metadata - frequency or difficulty rank \## 3.2 Source
Strategy Recommended approach: use open or explicitly licensed lexical
sources for bundled content, such as Wiktionary-derived datasets, and
keep source attribution and license notices with the bundled dataset. Do
not make scraping a third-party dictionary website a production
dependency. Vocabulary.com, Anki decks, and commercial dictionary
products can be useful references for product behavior and data shape,
but content redistribution rights must be reviewed separately before any
definitions or examples are bundled. \## 3.3 Pronunciation - Primary:
the bundled Kitten Nano v0.2 model running through sherpa-onnx. Prewarm the
model after launch and cache the featured and upcoming practice words. Keep
synthesis fully offline, expose the packaged American and British voices,
and retain the installed iOS voice only as a runtime failure fallback.
Audio playback must remain optional and never block study.

# 4. User Experience

## 4.1 Information Architecture

## 4.2 Today

-   Current streak and daily goal.
-   Cards due today and new words available.
-   Single primary action: Start Practice.
-   Session completion state with clear progress feedback. \## 4.3
    Practice Card \## 4.4 Widget A small Home Screen widget should
    display one not-yet-mastered word and a short example. The widget
    acts as passive reinforcement rather than a random "word of the
    day."
-   2×2 / small widget as the initial size.
-   Word + short context + streak indicator.
-   Tap opens the corresponding study flow.
-   Widget content should prioritize due or weak vocabulary. \## 4.5
    Streaks and Daily Goal A streak should represent completed learning,
    not merely opening the app. A study day is counted when the
    configured daily goal is completed. This makes the streak meaningful
    and avoids vanity engagement. \# 5. Technical Proposal \## 5.1
    Recommended Stack
-   SwiftUI --- application UI
-   SwiftData --- vocabulary progress, cards, review logs, and study-day
    state
-   WidgetKit --- Home Screen widget and timeline
-   sherpa-onnx / ONNX Runtime / AVAudioPlayer --- local Kitten synthesis and cached playback
-   App Groups --- shared read-only study snapshot for the widget
-   Bundled SQLite/resource dataset --- initial vocabulary content
-   CloudKit --- optional later phase for cross-device sync \## 5.2 Core
    Data Model \## 5.3 Scheduler Responsibilities
-   Select due cards using local calendar-day semantics.
-   Prevent paired cards from appearing on the same day.
-   Reinsert failed cards at the end of the active session.
-   Cap new vocabulary according to user settings.
-   Resolve date collisions by shifting the paired card forward.
-   Keep scheduling deterministic enough to test with unit tests.

# 6. V1 Scope & Delivery Plan

## V1 --- Product-Complete Core

-   Bundled Open English WordNet database with frequency-ranked learning candidates
-   Word → Definition and Definition → Word cards
-   Paired-card same-day exclusion rule
-   ✕ / ✓ study interaction
-   Daily new-word limit and due-review queue
-   Definition, example sentence, and pronunciation
-   Daily goal and streak
-   Small WidgetKit widget
-   Word search and Learning / Mastered states
-   Fully offline core study flow \## Deferred
-   FSRS or personalized memory modeling
-   Cloze-context cards
-   CloudKit synchronization
-   User-created decks and imports
-   AI-generated examples or definitions
-   Social leaderboards / competitive streaks
-   Web or Android clients \## Success Metrics \# 7. Product
    Recommendation Lexilo should launch as a deliberately narrow
    product: a beautiful, fast, automatic vocabulary trainer rather than
    a general flashcard platform. Its strongest differentiation is not a
    larger feature list; it is the combination of two-way recall,
    separated scheduling, useful context, and an interface that asks the
    learner to make only one meaningful decision at a time. Recommended
    product promise: Open. Learn. Remember.

# Tables

## Table 1

  -------------------------------------------------------------------------------------
  2-WAY RECALL`<br>`{=html}Word ZERO                        DAILY
  → Meaning`<br>`{=html}Meaning FRICTION`<br>`{=html}Only   HABIT`<br>`{=html}Widget,
  → Word                        two                         daily goal,`<br>`{=html}and
                                decisions:`<br>`{=html}✕    streak tracking
                                Don't Know / ✓ Know         
  ----------------------------- --------------------------- ---------------------------

  -------------------------------------------------------------------------------------

## Table 2

  "Learn vocabulary without managing flashcards."
  -------------------------------------------------

## Table 3

  -----------------------------------------------------------------------
  Principle                           Implication
  ----------------------------------- -----------------------------------
  Simple by default                   No deck engineering, card
                                      templates, or scheduler tuning
                                      required.

  Recall over exposure                The learner must retrieve meaning
                                      and word form in separate sessions.

  Automatic scheduling                The system decides when each card
                                      returns.

  Daily continuity                    Progress, streaks, and widgets make
                                      learning visible without adding
                                      friction.

  Local-first                         Core learning and scheduling work
                                      offline; cloud sync can be added
                                      later.
  -----------------------------------------------------------------------

## Table 4

  -----------------------------------------------------------------------
  Action                  Meaning                 Scheduler Behavior
  ----------------------- ----------------------- -----------------------
  ✕ Don't Know            Recall failed           Reset learning
                                                  interval; return card
                                                  to the end of today's
                                                  session.

  ✓ Know                  Recall succeeded        Increase success count
                                                  and schedule a future
                                                  review.
  -----------------------------------------------------------------------

## Table 5

  Consecutive Successful Reviews   Next Interval
  -------------------------------- ---------------
  1                                1 day
  2                                2 days
  3                                3 days
  4                                4 days
  5                                5 days
  6                                6 days
  7                                7 days
  8                                8 days
  9+                               n days, capped at 180

## Table 6

  Today   Words   Progress   Settings
  ------- ------- ---------- ----------

## Table 7

  --------------------------------------------------------------------------------------------------------
  Front                                                             After Reveal
  ----------------------------------------------------------------- --------------------------------------
  elusive`<br>`{=html}`<br>`{=html}🔊`<br>`{=html}`<br>`{=html}Do   difficult to find, catch, or
  you know this word?`<br>`{=html}`<br>`{=html}\[ Reveal \]         achieve`<br>`{=html}`<br>`{=html}The
                                                                    answer remained
                                                                    elusive.`<br>`{=html}`<br>`{=html}✕
                                                                    Don't Know ✓ Know

  --------------------------------------------------------------------------------------------------------

## Table 8

  -----------------------------------------------------------------------
  Entity                              Key Responsibility
  ----------------------------------- -----------------------------------
  VocabularyItem                      Word, definition, examples,
                                      pronunciation metadata, rank.

  StudyCard                           Direction, state, success count,
                                      interval, next review date.

  ReviewLog                           Immutable record of each answer and
                                      scheduling result.

  StudyDay                            Daily goal, completed reviews, new
                                      words, streak qualification.

  UserSettings                        New-word limit, daily goal,
                                      voice/accent, notifications.
  -----------------------------------------------------------------------

## Table 9

  -----------------------------------------------------------------------
  Metric                              What It Measures
  ----------------------------------- -----------------------------------
  Day-7 retention                     Whether the daily study loop
                                      becomes a habit.

  Daily goal completion rate          Whether sessions are appropriately
                                      sized.

  Review accuracy by direction        Recognition vs. active recall
                                      difficulty.

  Backlog size                        Whether new-word intake overwhelms
                                      review capacity.

  Words reaching mastery              Long-term learning output, not just
                                      app engagement.
  -----------------------------------------------------------------------
