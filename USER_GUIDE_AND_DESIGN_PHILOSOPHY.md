# Lexilo User Guide & Design Philosophy

Lexilo is a calm, focused vocabulary trainer for building a daily English-learning habit.

Its promise is simple:

> Open. Learn. Remember.

This document explains how to use the app and why Lexilo is designed the way it is.

## Part I — How to use Lexilo

### 1. Start from Today

The **Today** tab is your home base. It shows:

- Your daily practice progress
- How many cards are due
- Your practice streak, shown as `Day 1`, `Day 2`, `Day 3`, and so on
- One featured word to keep in mind

Tap **Start practice** to begin the session selected for you.

Lexilo chooses due reviews first, then introduces new words within your daily new-word limit. You do not need to build a deck or decide which card comes next.

### 2. Complete a practice card

Every vocabulary item is practiced in two directions:

1. **Word → Meaning**: see the word and recall its meaning.
2. **Meaning → Word**: see the meaning and retrieve the word.

For each card:

1. Read the prompt and try to answer before revealing it.
2. Tap the speaker button if you want to hear the pronunciation.
3. Tap **Reveal answer**.
4. Choose one honest answer:
   - **Know** ✓ — you recalled it successfully.
   - **Don’t know** ✕ — you could not recall it yet.

There is no penalty for choosing **Don’t know**. An honest answer gives the scheduler better information.

### 3. What happens after an answer?

When you tap **Know**, Lexilo increases the card’s successful-review count and schedules it for later:

| Successful reviews | Next review |
| ---: | --- |
| 1 | Tomorrow |
| 2 | In 2 days |
| 3 | In 3 days |
| 4 | In 4 days |
| 5 | In 5 days |
| 6 | In 6 days |
| 7 | In 7 days |
| 8+ | The same number of days, capped at 180 days |

When you tap **Don’t know**:

- The card is reset to the beginning of its learning interval.
- It returns to the end of the current session so you can try again later.
- It will not be scheduled as a normal same-day review in a new session.

### 4. Why the same word can appear twice—but not on the same day

Lexilo deliberately keeps the two directions separate. A word’s **Word → Meaning** card and **Meaning → Word** card cannot be presented on the same calendar day.

This prevents the first card from giving away the answer to the second one. It also tests two different skills:

- Recognizing a word when you see it
- Retrieving the word when you only know the meaning

### 5. Set your daily workload

Open **Settings → Daily practice** to adjust:

- **Daily goal**: the number of cards you want to review each day.
- **New words**: the maximum number of vocabulary items introduced per day.

The daily goal controls the size of a normal practice session. The new-word limit protects you from adding more vocabulary than your future review schedule can support.

### 6. Explore Words

The **Words** tab contains three collections:

You can:

- Browse **My Words**, the items already introduced in practice
- Preview the rotating **Upcoming** queue
- Search the complete bundled **Dictionary** and add a result to learning
- See whether an item is **New**, **Learning**, or **Mastered**
- Open a word to read its definition, pronunciation information, and example sentences
- Review the two-way recall rule for that word

Lexilo considers a word mastered only when both of its directions have reached mastery. Recognizing a word is useful, but it is only half of durable recall.

### 7. Check Progress

The **Progress** tab shows:

- Words currently being learned
- Words mastered in both directions
- Review activity across the current week
- Accuracy for **Word → Meaning** and **Meaning → Word**

Use this page to understand where recall is strong and where active retrieval needs more practice.

### 8. Use pronunciation

Tap the speaker button on a featured word or practice card.

Lexilo uses the bundled Kitten Nano v0.2 neural model through sherpa-onnx for every word. Pronunciation is generated locally and the word is not sent to a server. The model is initialized after launch, and the featured plus upcoming practice words are prepared in a bounded local cache.

If you do not want audio, turn off **Play pronunciation** in Settings. You can select among eight Kitten expressive voices, adjust speech rate, or select the system fallback accent.

### 9. Rotate upcoming vocabulary

Lexilo bundles its dictionary and prepares a queue of 40 unseen suggestions. It chooses from a frequency-based learning range and rotates deterministically on the device; no account or internet connection is required.

Open **Settings → Offline dictionary** to:

- Choose a learning range from Essential through Challenge
- Include or exclude multiword phrases
- Tap **Replace unstarted suggestions** to renew only words you have not started

Started, reviewed, and mastered words are never removed by rotation. Lexilo remembers retired suggestions so an immediate refresh does not return the same seeds. A future app update can replace the versioned dictionary while preserving card IDs and learner history.

### 10. Add the Widget

Add the small Lexilo widget to the iPhone Home Screen:

1. Touch and hold an empty area of the Home Screen.
2. Tap **Edit** and choose **Add Widget**.
3. Search for **Lexilo**.
4. Choose the small widget and add it.

The widget shows a not-yet-mastered word, a short example, and your current practice day when available. Tap it to open Lexilo and start practice.

The widget is passive reinforcement, not a replacement for the practice session. Its purpose is to give one useful word a place in your day.

### 11. Finish a study day

A study day is recorded when you complete the configured daily goal. The streak then advances to the next `Day N`.

Opening the app alone does not count as practice. The streak is intended to represent completed learning, not app launches.

## Quick reference

| If you want to… | Go to… |
| --- | --- |
| Start today’s review | Today → Start practice |
| Hear a word | Speaker button on Today or a card |
| Change the number of new words | Settings → Daily practice |
| Search your vocabulary | Words → My Words → Search |
| Search the offline dictionary | Words → Dictionary |
| See accuracy and mastery | Progress |
| Renew unstarted words | Settings → Offline dictionary |
| Choose pronunciation accent | Settings → Pronunciation |

## Troubleshooting

### “There are no cards due today.”

You are caught up for the current schedule. You can still tap **Practice again** to review available content.

### I chose “Don’t know.” Why did the card come back?

That is intentional. The card is placed at the end of the current session so you can make another attempt after seeing other material.

### I cannot hear pronunciation.

Check that **Play pronunciation** and **Use offline voice when needed** are enabled and that the iPhone volume is on. The selected English voice must be available on the device.

### Upcoming words did not change.

Only unstarted suggestions can be replaced. If the queue is already in progress, complete more practice first. You can also widen **Learning range** or enable phrases.

---

## Part II — Design Philosophy

### 1. Recall over exposure

Seeing a definition and recognizing a familiar word can feel like learning, but recognition is easier than retrieval. Lexilo asks the learner to retrieve information before revealing the answer.

That is why every card has a prompt, a reveal step, and an explicit decision. The app is designed around the moment of remembering—not around the amount of content displayed.

### 2. Two-way recall is the smallest complete unit

Vocabulary knowledge has two directions:

- From the word to its meaning
- From the meaning back to the word

Lexilo treats both as first-class learning tasks. A learner who can recognize *elusive* while reading may still struggle to produce the word when speaking or writing. Mastery therefore requires both cards to become strong.

### 3. Delay the helpful cue

The paired cards never appear on the same calendar day. This is a deliberate constraint, not a missing feature.

If the reverse card immediately follows the first card, the learner can rely on short-term memory or visual familiarity. Separating the cards makes the second encounter a more meaningful test of memory.

### 4. Automate the schedule, preserve learner agency

Traditional flashcard systems can ask users to manage decks, card templates, intervals, and algorithm settings. Lexilo keeps the learning decision visible while hiding the administration:

- The learner decides honestly between **Know** and **Don’t know**.
- Lexilo decides when the card should return.
- Settings expose only the choices that affect workload: daily goal, new-word limit, and sound.

The product should feel like a trusted study companion, not a spreadsheet for memory management.

### 5. Context makes a word usable

A definition explains what a word means. An example shows how the word behaves in real language.

Lexilo therefore keeps example sentences close to the definition and displays them after reveal. Content enrichment may add more examples, but the card remains focused: one word, one meaning, and enough context to make the meaning memorable.

### 6. Honest progress over vanity metrics

Lexilo counts completed study work, not launches, taps, or time spent staring at a screen.

The streak is tied to a completed daily goal. Progress distinguishes learning from mastery, and the Progress tab separates recognition accuracy from active-recall accuracy. These choices make the numbers useful for changing study behavior.

### 7. Small daily consistency beats large occasional sessions

The daily new-word limit prevents the learner from creating an oversized review backlog. The widget keeps one word visible between sessions. The daily goal creates a clear stopping point.

Together, these features make the habit easy to start, finite enough to finish, and sustainable over time.

### 8. Local-first learning

The core study loop should remain dependable:

- Vocabulary progress is stored locally.
- Scheduling and review history work offline.
- Content enrichment is an enhancement, not a requirement for studying.
- The widget receives a small shared snapshot rather than requiring the full learning database.

This keeps the app fast, private by default, and resilient when the network is unavailable.

### 9. Responsible content integration

Lexilo separates learning logic from content providers. This allows the app to use bundled, open, or explicitly licensed sources without rewriting the scheduler or user experience.

Open English WordNet is Lexilo’s sole vocabulary source. Its dataset-level attribution and redistribution licenses ship with the app; individual learning-progress records only store the WordNet identifier and the content required for offline study.

### 10. Calm visual language

Lexilo’s visual system is editorial rather than game-like:

- Warm paper backgrounds create a quiet reading surface.
- Deep ink is reserved for primary text and decisive actions.
- Sage communicates learning and positive progress.
- Brass provides small moments of emphasis.
- Serif display typography gives vocabulary a literary, memorable presence.

The interface avoids trophy-heavy gamification, competing gradients, decorative clutter, and unexplained controls. Visual hierarchy should make the next meaningful action obvious.

### 11. One meaningful decision at a time

The practice screen deliberately reduces cognitive noise. The learner sees one prompt, chooses when to reveal the answer, and records one honest judgment.

The result is a short interaction loop:

```text
Prompt → Think → Reveal → Know / Don’t know → Schedule
```

That loop is the center of Lexilo. Every secondary feature—content sync, pronunciation, progress, and the widget—exists to support it.

## Product promise

Lexilo is not trying to become a general-purpose flashcard platform. It is a focused, beautiful, automatic vocabulary trainer for people who want to learn without managing the machinery of learning.

> Learn the word. Retrieve the meaning. Come back tomorrow.
