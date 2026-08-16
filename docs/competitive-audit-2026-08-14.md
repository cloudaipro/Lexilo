# LEXILO Competitive Audit and Product Improvement Plan

> Research date: August 14, 2026
> Code-state refresh: August 16, 2026
> Market: United States iPhone App Store
> Scope: English-learning category leaders, Anki and the English 60K deck ecosystem, LEXILO product audit, SWOT analysis, gap analysis, and UI/product roadmap

## Executive conclusion

LEXILO should not compete as a smaller Duolingo or another generic AI conversation app. Its strongest position is:

> A private, focused vocabulary-memory coach that turns words you recognize into words you can actively use.

The foundation is strong: calm editorial UI, two-way recall on different days, an offline Kaikki Learning Core, neural pronunciation, adaptive scheduling, a bounded daily session, and a useful widget.

The current release now verifies meaning-to-word production with typed input and precise correction, while recognition still uses a deliberate Know/Don’t know self-assessment. The main remaining product risk is content trust at scale: examples, pronunciations, and sense selection must remain useful as the source refreshes.

## Research method and limitations

Apple does not publish a stable “English learning” subcategory. The benchmark set was selected using:

- Apple’s current US iPhone Education chart, where Duolingo and Learna appeared among leading downloads. Rankings change frequently: [US Education chart](https://apps.apple.com/us/iphone/charts/6017?chart=top-free).
- Apple’s editorial collection of recommended language-learning apps: [The Best Language-Learning Apps](https://apps.apple.com/us/iphone/room/1496256633).
- Current App Store product pages, feature descriptions, ratings, and selected review themes.
- Published research on receptive versus productive retrieval and spaced vocabulary learning.

App Store positions, rating totals, prices, and product features are time-sensitive. Strengths and reported features below are sourced from current product pages; weaknesses, opportunities, and threats are strategic inferences based on the products’ models and visible user feedback.

## Market structure

Leading products largely win through four learning loops:

1. **Habit and gamification:** Duolingo.
2. **Structured curriculum:** Babbel and Busuu.
3. **Speaking feedback:** Speak, ELSA Speak, and Learna.
4. **Contextual vocabulary:** WordUp, Memrise, and Cake.

LEXILO has the foundation for a distinct fifth loop: **quiet, private, bidirectional memory training**.

## Competitive SWOT analysis

### Duolingo

Source: [Duolingo on the App Store](https://apps.apple.com/us/app/duolingo-language-lessons/id570060128)

- **Strengths:** Category-leading habit loop; short lessons; reading, writing, listening, and speaking; strong social proof with millions of ratings; clear progression and frequent rewards.
- **Weaknesses:** Rewards can become the goal; individual words receive limited semantic depth; broad product expansion can dilute the language-learning focus.
- **Opportunities:** AI role-play, richer advanced courses, and better transfer from exercises to real conversation.
- **Threats:** Subscription fatigue and learners graduating to specialist speaking, exam, or vocabulary products.

### Learna

Source: [Learna on the App Store](https://apps.apple.com/us/app/speak-learn-english-learna/id6478287397)

- **Strengths:** High current Education-chart visibility; AI tutor covers speaking, grammar, reading, pronunciation, and vocabulary; large rating base; easy-to-understand virtual-tutor proposition.
- **Weaknesses:** Broad “all-in-one” positioning is difficult to differentiate; reviews raise trial-transparency and speech-recognition concerns.
- **Opportunities:** More personalized goals, scenarios, explanations, and adaptive practice plans.
- **Threats:** AI-avatar tutors are increasingly commoditized; cloud inference, privacy, and subscription costs may erode trust.

### Speak

Source: [Speak on the App Store](https://apps.apple.com/us/app/speak-language-learning/id1286609883)

- **Strengths:** Strong four-step loop—lesson, repetition, AI feedback, then conversation; gets users speaking on day one; personalized feedback, bookmarks, and real-life scenarios.
- **Weaknesses:** Subscription and cloud dependency; less suitable when a learner cannot speak aloud; smaller language breadth than generalist leaders.
- **Opportunities:** Connect saved phrases and conversation mistakes to durable spaced review.
- **Threats:** High inference costs and competition from general-purpose AI voice products.

### ELSA Speak

Source: [ELSA Speak on the App Store](https://apps.apple.com/us/app/elsa-speak-english-learning/id1083804886)

- **Strengths:** Specialist pronunciation diagnostics; analysis of stress, pace, fluency, and grammar; career and exam paths; strong rating base.
- **Weaknesses:** Recognition errors directly damage trust; current reviews note that the virtual tutor can consume too much screen space.
- **Opportunities:** Join pronunciation diagnostics with vocabulary production and personally relevant study sets.
- **Threats:** Speech assessment may become a platform-level commodity; accent fairness and recognition bias remain product risks.

### Babbel

Source: [Babbel on the App Store](https://apps.apple.com/us/app/babbel-language-learning/id829587759)

- **Strengths:** Structured real-life curriculum, contextual grammar, smart review, offline lessons, and practical 10-minute sessions.
- **Weaknesses:** Full curriculum requires a subscription; the habit loop is less playful than Duolingo’s; professionally authored content is expensive to scale.
- **Opportunities:** Guided conversation and AI speaking can extend its trusted curriculum.
- **Threats:** Free competitors and AI tutors compress willingness to pay for conventional lessons.

### Busuu

Source: [Busuu on the App Store](https://apps.apple.com/us/app/busuu-language-learning-app/id379968583)

- **Strengths:** Complete course structure, writing and speaking exercises, and corrections from native-speaker community members.
- **Weaknesses:** Community feedback quality and response speed vary; the experience is more complex than a focused trainer.
- **Opportunities:** Hybrid human-plus-AI correction and more personalized review paths.
- **Threats:** Moderation cost, privacy concerns, and declining willingness to wait for peer feedback.

### Memrise

Source: [Memrise on the App Store](https://apps.apple.com/us/app/memrise-easy-language-learning/id635966718)

- **Strengths:** Native-speaker video creates authentic listening and usage context; vocabulary review and speaking practice connect study to real language.
- **Weaknesses:** The free plan is limited; content quality and feature availability can vary by language pair.
- **Opportunities:** Personalize authentic clips around vocabulary the learner is close to forgetting.
- **Threats:** Video licensing and content-production costs; abundant free short-form language content.

### Cake

Source: [Cake on the App Store](https://apps.apple.com/us/app/cake-learn-english-korean/id1350420987)

- **Strengths:** Real-world clips, slang, daily expressions, pronunciation feedback, saved phrases, and daily goals; strong rating average.
- **Weaknesses:** Media browsing may become passive consumption; learning content can feel fragmented rather than cumulative.
- **Opportunities:** Convert saved words and phrases into systematic active-recall sessions.
- **Threats:** YouTube and TikTok are free substitutes; content rights and subscription pricing can be volatile.

### WordUp

Source: [WordUp on the App Store](https://apps.apple.com/us/app/wordup-vocabulary-builder/id1365078730)

- **Strengths:** LEXILO’s closest direct competitor: 25,000 words, a personalized knowledge map, spaced repetition, nine challenge types, usage context, writing feedback, phrases, AI features, and offline support.
- **Weaknesses:** High feature density increases cognitive load; current reviews mention crashes and unreliable multi-device synchronization.
- **Opportunities:** Become a comprehensive active-vocabulary platform for advanced and professional learners.
- **Threats:** Feature complexity, AI novelty, and questionable content can weaken focus and trust.

## Practices worth adopting

The leaders repeatedly use these patterns:

1. Personalize before prescribing: determine level, goal, available time, and usage context.
2. Give one obvious daily action with a concrete duration.
3. Require output rather than exposure—typing, speaking, choosing, or constructing.
4. Correct mistakes immediately and explain them.
5. Recycle errors into both the current session and future reviews.
6. Teach real-life phrases, collocations, and situations.
7. Present progress as a learning diagnosis rather than an activity total.
8. Let learners save personally relevant words and sentences.
9. Make onboarding interactive and delay permissions or purchase prompts until the learner has experienced value.

LEXILO’s two-way practice model is supported by vocabulary-learning research. Productive retrieval is particularly beneficial for productive vocabulary knowledge, while spaced retrieval plus semantic elaboration is stronger than massed repetition or passive study:

- [The Effects of Receptive and Productive Word Retrieval Practice on Second Language Vocabulary Learning](https://www.jstage.jst.go.jp/article/katejournal/30/0/30_11/_article)
- [A Review of Laboratory Studies of Adult Second Language Vocabulary Training](https://www.cambridge.org/core/journals/studies-in-second-language-acquisition/article/abs/review-of-laboratory-studies-of-adult-second-language-vocabulary-training/18F0A5D1FFC829CE05931B2EEE83124A)

## LEXILO product audit

### Current strengths

- Clear, research-aligned two-way recall model.
- Paired recognition and production cards cannot appear on the same calendar day.
- Calm, recognizable editorial identity instead of category-standard cartoon gamification.
- Local learning history, Kaikki Learning Core, adaptive scheduler, and neural text-to-speech.
- 39,179 learning terms, 115,201 validated usage examples, and complete pronunciation coverage for selected source entries.
- Fast, finite daily sessions with failed-card recycling.
- Direction-specific progress and a Home Screen widget.
- Deterministic scheduler tests, persistence recovery, UI-flow tests, and a healthy build.

### Current weaknesses

- **Recognition remains self-reported.** “Know” and “Don’t know” are intentionally lightweight; production cards now verify typed word recall. See [`PracticeSessionView.swift`](../Lexilo/Views/PracticeSessionView.swift#L138).
- **Speech is playback, not assessment.** Lexilo provides offline pronunciation but does not yet grade spoken output.
- No placement check, exam target, or interest profile; onboarding currently focuses on optional first-language support.
- No cloze, listening discrimination, or pronunciation assessment.
- Dictionary content is not organized around collocations, confusable words, word families, or learner-friendly senses.
- There is no separate Progress or Memory dashboard; scheduling diagnostics remain intentionally behind the interface.
- No reminders, subscription strategy, or cross-platform continuity. Optional iCloud snapshot sync is available for portability.
- The widget supports Small and Medium layouts and carries the displayed
  vocabulary ID in its URL, but the application currently opens a generic
  practice session instead of targeting that exact word. See
  [`LexiloWidget.swift`](../LexiloWidget/LexiloWidget.swift#L45) and
  [`RootView.swift`](../Lexilo/Views/RootView.swift#L17).

### Opportunities

- Own the “active vocabulary” position for intermediate and advanced English learners.
- Make privacy and offline operation a primary acquisition promise.
- Offer career, academic, IELTS/TOEFL, and personal word packs without becoming a full language course.
- Build a differentiated “Memory Health” diagnostic.
- Offer a one-time purchase or privacy-first premium model rather than an aggressive AI subscription.

### Threats

- WordUp already competes directly with broader personalization and exercise variety.
- Learners increasingly expect speaking feedback from English-learning products.
- Generic, obsolete, or context-poor source definitions can reduce perceived content quality; the Kaikki quality pipeline now rejects definition-like example fragments.
- A calm visual experience can feel static unless feedback and progress remain emotionally rewarding.
- A narrow product may struggle with App Store discovery without exceptionally clear positioning and screenshots.

## Gap analysis

| Capability | LEXILO today | Competitive standard | Priority |
|---|---|---|---|
| Objective recall | Typed production correction plus self-reported recognition | Typed, spoken, multiple-choice, and corrected | High |
| Personalization | Difficulty band and new-word limit | Goal, level, interests, scenario, and adaptive path | Critical |
| Scheduling | Compact adaptive model with hidden memory variables | Recall-probability or adaptive review | Medium |
| Vocabulary depth | Definition, IPA, and examples | Collocations, word families, confusables, and saved context | High |
| Speaking | Playback only | Recording, recognition, and pronunciation feedback | Medium |
| Habit support | Streak, goal, and widget | Reminders, recovery, and explicit time estimate | High |
| Progress | Daily goal, streak, and completion feedback; no separate dashboard | Weak-skill diagnosis and recommended next action | Medium |
| Sync | Device-local plus optional iCloud snapshot backup | Multi-device and web continuity | Medium |
| Privacy/offline | Excellent | Often cloud-dependent | Defensible advantage |
| Visual identity | Strong and distinctive | Many competitors are generic or game-heavy | Preserve |

Not every feature gap should be closed. LEXILO should deliberately avoid competing on course breadth, social leaderboards, video feeds, or open-ended AI chat until its vocabulary-memory loop is objectively excellent.

## Product roadmap

The estimates below assume one primary iOS engineer with part-time design and content support.

### Phase 1: Protect content trust

1. Keep the Kaikki quality pipeline reproducible and publish the source hash,
   database version, row counts, and rejection counts with each release.
2. Expand regression fixtures around common failure modes: definition-like
   fragments, missing headword examples, duplicate pronunciations, heteronyms,
   and inflected forms.
3. Review learner content reports and feed confirmed fixes back into the next
   offline database build without changing learner-owned scheduling history.
4. Run Dynamic Type, VoiceOver, contrast, Reduce Motion, and oldest-device
   performance audits before each App Store submission.

### Phase 2: Add dictionary breadth separately

1. Build the future Full Dictionary as an optional, versioned download rather
   than expanding the v0.9 bundle.
2. Keep the future pack Kaikki-only, source-attributed, and free of OEWN,
   FTS5, and unlicensed commercial dictionary content.
3. Support exact headword, prefix, and inflected-form lookup with ordinary
   indexes; do not add full-text definition search unless a later product need
   proves it necessary.
4. Verify compressed size, integrity, schema compatibility, and atomic update
   behavior before exposing the pack to learners.

### Phase 3: Extend practice selectively

1. Evaluate cloze, listening, and on-device speech assessment as optional modes.
2. Add academic, workplace, exam, or personal packs only when they reuse the
   same automatic workload and scheduler.
3. Keep open-ended AI conversation, social competition, and broad grammar
   curriculum outside the focused vocabulary product until retention evidence
   supports the expansion.

## UI design plan

### Recommended design direction

Use an **editorial memory-coach** direction: evolve the existing warm visual identity by combining generous editorial restraint with clearer information architecture. Preserve the warm paper, ink, sage, brass, serif vocabulary, leaf mark, and single-decision practice philosophy.

The interface should add information only when it proves learning or guides the next action. It should not adopt trophy grids, decorative data, cartoon currencies, or generic AI avatars.

### Today screen

- Keep one dominant daily CTA.
- Replace the generic session label with concrete workload and duration:
  - `8 reviews · 2 new`
  - `About 4 minutes`
  - `Begin today’s practice`
- Add one diagnostic statement below the CTA, such as `Meaning → Word needs attention`.
- Move the permanent “Two-way recall” explanation into onboarding and context-sensitive tips.
- Keep the featured word, but give it real actions: hear, save, or practice.
- After completion, replace the primary card with a compact “Today complete” state and the next scheduled review.

### Practice screen

- Label the two modes in plain language: `Recognize` and `Produce`.
- Preserve one focused canvas while reducing unused vertical space.
- In production mode, place the text field at the center and retain one primary submit button.
- After an incorrect answer, show:
  - The learner’s answer.
  - The correct answer.
  - A one-line explanation.
  - One useful collocation or contrast.
- Show `8 remaining` instead of a denominator that changes when a failed card is appended.
- Preserve the red and sage response colors, but always pair them with text and symbols.
- Use subtle haptic and motion feedback, respecting Reduce Motion.

Apple recommends accurate determinate progress indicators: [Apple Human Interface Guidelines: Progress indicators](https://developer.apple.com/design/human-interface-guidelines/progress-indicators).

### Completion screen

Replace a generic completion message with a learning summary:

- `8 remembered`
- `2 need another pass`
- `Production improved from 62% to 71%`
- `Next review tomorrow`
- Primary action: `Finish`
- Secondary action: `Review the 2 misses`

### Words screen

Keep the **Words** name and its two simple sections:

- **My Words** for learned material.
- **Upcoming** for words approaching introduction.

Each row should display the word, concise meaning, and learning state. The
current screen also supports local word/meaning filtering and focused word
detail. Full Dictionary browsing remains a future feature rather than a third
Words section.

### Future diagnostics

If a future diagnostics surface is added, it should answer three questions:

1. What have I retained?
2. Where am I weak?
3. What should I do next?

Recommended modules:

- Memory Health summary.
- Recognition versus production balance.
- Words at risk.
- Seven-day review forecast.
- Recently mastered words.
- A contextual action such as `Practice 5 weak production words`.

Avoid decorative charts and trophy collections. Every metric should lead to an action. Until then, keep memory estimates and scheduler internals out of the learner-facing navigation.

### Settings

- Keep daily workload and offline-voice controls.
- Move the learning goal and level to a “Learning plan” section.
- Add reminder time and optional iCloud sync.
- Add an explicit privacy summary: what remains local and what, if anything, leaves the device.
- Keep licenses and dataset attribution accessible but visually secondary.

### Widget

- Preserve the current small editorial widget. **Implemented:** it is
  word-first and keeps the learning word visible without an example or
  definition.
- Make tapping it open the displayed word. **Partially implemented:** the
  widget URL carries the vocabulary ID, but the app still opens a generic
  practice session.
- Add medium-size support with one word, one complete secondary content block,
  and a practice tap. **Implemented:** the medium widget places the word above
  a complete selected definition or example, with Definition as the default;
  the choice is available in Settings.
- Consider an interactive “Hear” action where supported.
- Ensure the widget works with tinted and high-contrast appearances.

## Visual directions to test

### Direction A: Editorial evolution — recommended

- Warm paper field and serif vocabulary.
- Fewer but more informative surfaces.
- Sage communicates learning; brass provides restrained emphasis.
- The signature moment is the reveal transition from prompt to contextual understanding.
- Best balance of differentiation, trust, and implementation risk.

### Direction B: Precision coach

- Denser information architecture.
- Compact review forecast and direction-strength indicators.
- Less paper texture and fewer large cards.
- Appropriate for academic, professional, and advanced learners.

### Direction C: Spoken studio

- Dark, audio-led practice environment.
- Waveform, recording status, and live pronunciation feedback.
- Strongly differentiated from the calm library surfaces.
- Reserve this direction for the later speaking mode rather than redesigning the entire application around it.

The recommended final system is Direction A with selected diagnostic components from Direction B. Direction C should remain a specialized mode.

## Success metrics

The proposed north-star metric is:

> Words objectively recalled in both directions after 30 days per minute of practice.

Supporting measures:

- First-session completion.
- Day-1, Day-7, and Day-30 retention.
- Objective recognition and production accuracy.
- Median time to a mastered word.
- Percentage of failed cards recovered within seven days.
- Daily-goal completion.
- Content-report rate.
- Reminder and widget re-entry conversion.
- Crash-free sessions.

## Recommended decision

Prioritize objective typed recall, lightweight learner-fit onboarding, and actionable memory diagnostics. These three changes close the most important trust and outcome gaps without damaging LEXILO’s focused position.

Preserve:

- Two-way recall on separate days.
- Local-first architecture.
- Calm editorial brand.
- Automatic administration.
- Finite daily workload.

Defer:

- General grammar curriculum.
- Social leaderboards.
- Video-content feed.
- Multiple new languages.
- Open-ended AI conversation.

## Technical validation

- The project was inspected at the SwiftUI view, model, scheduling, persistence, pronunciation, widget, and test levels.
- `xcodebuild -project Lexilo.xcodeproj -scheme Lexilo -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build` completed successfully on August 14, 2026.
- No application source files were changed as part of the audit.
- Pre-existing modifications to `Lexilo/Info.plist` and `LexiloWidget/Info.plist` were left untouched.

## Anki ecosystem deep dive

This section compares two different layers of the same ecosystem:

- [Anki](https://github.com/ankitects/anki) is a mature, general-purpose spaced-repetition platform.
- [anki-english-60k-decks](https://github.com/5mdld/anki-english-60k-decks) is a large English vocabulary content package built to run inside Anki.

LEXILO combines those layers into one opinionated product: it owns the content selection, scheduler, practice method, audio, and interface. Raw feature count is therefore a poor comparison. The useful questions are whether LEXILO models memory well enough, presents the right lexical content, and removes enough administrative work to justify a closed, focused experience.

### Research method

The review covered the current source trees, documentation, licenses, scheduler implementation, card templates, and deck-source data as of August 14, 2026. The 60K source file was also profiled directly rather than relying only on its marketing description.

Primary sources:

- [Anki source repository](https://github.com/ankitects/anki)
- [Anki manual: getting started](https://docs.ankiweb.net/getting-started.html)
- [Anki manual: deck options and FSRS](https://docs.ankiweb.net/deck-options.html)
- [Anki manual: card templates](https://docs.ankiweb.net/templates/intro.html)
- [Anki manual: statistics](https://docs.ankiweb.net/stats.html)
- [Anki manual: syncing](https://docs.ankiweb.net/syncing.html)
- [Anki manual: add-ons](https://docs.ankiweb.net/addons.html)
- [English 60K deck source and documentation](https://github.com/5mdld/anki-english-60k-decks)
- [Anki license](https://github.com/ankitects/anki/blob/main/LICENSE)
- [English 60K deck licensing notes](https://github.com/5mdld/anki-english-60k-decks/blob/main/LICENSE)

Repository popularity and commit counts are volatile and are not treated as product-quality metrics. The comparison concentrates on capabilities and learner consequences.

## Anki analysis

### What Anki is

Anki is a local-first flashcard platform with desktop, mobile, web, and community implementations. Its data model separates **notes** from **cards**: one structured note can generate several card directions through templates. A learner can create fields, card types, HTML/CSS layouts, tags, cloze deletions, image occlusion cards, filtered decks, and custom study sessions. Shared decks and add-ons extend the system further.

The current application uses a Rust backend, a Python bridge, and a Qt/web-based desktop interface, with Protocol Buffers across internal boundaries. That architecture is evidence of platform scope and maturity, not an architecture LEXILO needs to reproduce.

### Scheduler and memory model

Anki’s largest substantive advantage is its Free Spaced Repetition Scheduler, or FSRS. FSRS estimates three memory variables:

- **Difficulty:** how hard the item is for this learner.
- **Stability:** how long the memory is likely to endure.
- **Retrievability:** the current probability of successful recall.

It learns parameters from review history, targets a chosen retention level, and schedules the next interval accordingly. The default desired retention is 90%; Anki warns that workload rises rapidly at very high targets. It also exposes parameter optimization, evaluation, simulation, rescheduling, maximum intervals, easy days, per-preset settings, and—in current documentation—per-deck desired retention.

LEXILO’s current scheduler advances by successful-review count to fixed day intervals. It cannot distinguish an instantly recalled easy word from a fragile word recalled after hesitation, cannot estimate current recall probability, and cannot target a predictable retention/workload trade-off. This is the most important technical gap in the comparison.

### Review operations

Anki supports four self-rating outcomes: Again, Hard, Good, and Easy. It distinguishes new, learning, review, and relearning states; can apply lapse steps; detect leeches; suspend or bury cards; avoid showing sibling cards together; and alter display order. Its statistics include future due load, review count and time, interval distribution, answer-button history, stability, difficulty, retrievability, and true retention.

Four visible grading buttons are not automatically superior to LEXILO’s binary choice. They impose calibration work on the learner, and Anki explicitly advises that Hard still means a successful recall. LEXILO can preserve a simpler interface while feeding a richer scheduler with objective answer correctness, response time, hints, edits, and recent failures.

LEXILO’s strict rule that recognition and production siblings never appear on the same day is also a stronger English-learning default than making sibling burying an optional setting.

### Authoring and ecosystem

Anki is far ahead in learner ownership and interoperability:

- Arbitrary fields, note types, templates, and multiple cards per note.
- Typed-answer fields, cloze deletion, image occlusion, media, LaTeX, and HTML/CSS.
- Text and packaged-deck import/export with field mapping.
- Search, tags, deck hierarchy, filtered decks, and custom study.
- Optional AnkiWeb sync and media sync across devices.
- Shared decks and a large add-on ecosystem.

This power creates setup and maintenance costs. Learners must choose or construct content, understand cards versus notes, tune options, and manage problematic items. Add-ons can also lag or break after application updates, as Anki’s own manual notes. LEXILO’s single-purpose model removes most of that administration.

### Anki SWOT relative to LEXILO

- **Strengths:** State-of-the-art adaptive scheduling; long product history; deep statistics; cross-device sync; flexible authoring; import/export; mature recovery and review controls; broad ecosystem.
- **Weaknesses:** High setup and configuration burden; inconsistent shared-deck quality; self-grading remains common; utilitarian and fragmented experience; no opinionated English lexical pathway by default.
- **Opportunities:** Better defaults, automatic answer assessment, stronger platform-wide content quality controls, and simpler language-specific workflows.
- **Threats:** Specialist apps can hide the machinery and provide clearer learning paths; add-on fragility and ecosystem inconsistency can erode trust; general AI tools lower the cost of generating practice content.

### Gap: Anki versus LEXILO

| Capability | Anki | LEXILO today | Assessment |
|---|---|---|---|
| Scheduling | Personalized FSRS memory model and retention target | Compact adaptive model with hidden memory variables | Smaller LEXILO gap |
| Recall signal | Four self-ratings; typed answers possible through templates | Typed production correction plus binary recognition self-report | Material LEXILO gap |
| Bidirectional study | Configurable through sibling card templates | Built-in recognition and production directions | LEXILO has the better default |
| Sibling separation | Configurable burying | Enforced on separate days | LEXILO advantage |
| Authoring/import | General note types, fields, templates, import/export | Closed built-in content flow | Material gap for personal vocabulary |
| Difficult-item handling | Lapses, leeches, suspend, bury, custom study | Failure returns to the session; limited item controls | Material gap |
| Analytics | Retention, forecast, time, memory state, answer history | Basic learning/mastery and recent activity | Material gap |
| Sync and reach | Desktop, mobile, web, optional sync | iOS, local-first, optional iCloud snapshot sync | Material gap for multi-device learners |
| Content pathway | Platform is content-agnostic | Curated English-first discovery and workload | LEXILO advantage |
| Cognitive load | Powerful but administration-heavy | Focused, automatic, finite | LEXILO advantage |
| Offline pronunciation | Depends on each deck’s media | Bundled offline neural TTS | LEXILO advantage |
| Visual cohesion | Highly configurable and platform-like | Calm, coherent native product | LEXILO advantage |

The product lesson is to borrow Anki’s memory science and learner-control primitives, not its entire configuration surface.

## English 60K deck analysis

### What the deck actually contains

The repository describes a frequency-organized English deck with roughly 66,000 cards, based mainly on Merriam-Webster Learner’s Dictionary material and supplemented with Wiktionary-derived data. It splits the collection into 20 frequency subdecks from the first 1,000 ranks through the 60,000 range. Each definition becomes an atomic note, and sense-priority tags distinguish `core`, `extend`, and `rare` material where available.

A direct audit of `deck-source/notes.csv` found:

| Measure | Audited result |
|---|---:|
| Sense-level notes | 66,332 |
| Unique normalized surface words | 32,381 |
| Words represented by multiple sense cards | 12,328 |
| Maximum sense cards for one surface word | 66 |
| Frequency subdecks | 20 |
| Notes with IPA | 62,982 (94.9%) |
| Notes with headword audio URL | 60,399 (91.1%) |
| Notes with at least one example | 56,206 (84.7%) |
| Notes with a second example | 32,829 (49.5%) |
| Notes with a third example | 15,083 (22.7%) |
| `core` priority notes | 28,008 |
| `extend` priority notes | 13,393 |
| `rare` priority notes | 4,863 |
| Notes without those priority tags | 20,068 |

“60K” is therefore best understood as **coverage extending through a 60,000-word frequency ranking**, not 60,000 unique spellings. The larger note count results partly from separate cards for different senses; some dictionary entries are unavailable or omitted, as the project documentation also explains.

### Card behavior and learning implications

The package currently defines one card template. The front shows the word, part of speech, IPA, pronunciation control, and one randomly selected example sentence. The back shows the definition, usage label, up to three displayed examples, optional Simplified Chinese translations, dictionary link, and example-sentence text-to-speech.

This has several consequences:

- It primarily tests **word-to-meaning recognition**. It does not generate a meaning-to-word production sibling by default. Anki can support a reverse template, but this deck does not provide one.
- Showing a random example before recall provides useful context but can leak the answer. That can increase apparent fluency without proving unaided retrieval.
- Reviews use Anki’s normal self-rating unless the learner modifies the template; the supplied card does not objectively check a typed word.
- Splitting definitions into atomic notes is good for polysemy, but studying many senses of one headword can become repetitive and inflate workload.
- Translation is available for Chinese-speaking learners, but the repository describes it as AI-generated and replaceable. It should not be treated as an authoritative semantic reference without validation.
- Headword audio is stored as a remote URL, and example TTS calls online services. The text deck can be reviewed locally, but this specific audio experience is internet-dependent. LEXILO’s bundled TTS is more consistent and private.

The CSV contains a fourth example/translation pair in its field structure, while the supplied card template displays only the first three. This is not a major learning defect, but it shows that dataset richness and the actual review interface are not identical.

### Content and licensing constraints

The deck does not have one uniform license. Its own licensing file says original project material is offered under CC0, Wiktionary/Kaikki-derived material is subject to CC BY-SA 4.0, individual media may have separate terms, and Merriam-Webster definitions, examples, pronunciations, audio, and branding remain copyrighted and are not granted for redistribution or commercial use by the repository.

LEXILO should therefore **not copy or bundle this deck’s content** without a field-level provenance audit and appropriate permission. Its taxonomy and workflow can inspire independent product design, but any content ingestion needs separate rights review. Likewise, Anki’s code is principally AGPL-3.0-or-later; directly incorporating it can create source-disclosure obligations. This report is a product and engineering assessment, not legal advice.

### English 60K deck SWOT relative to LEXILO

- **Strengths:** Exceptional long-tail breadth; atomic sense cards; frequency organization; priority tags; learner-dictionary definitions; usage labels; IPA; many examples; optional translation; access to Anki’s scheduling and ecosystem.
- **Weaknesses:** Only about half the notes have two examples and fewer than one quarter have three; remote/incomplete audio; one-direction template; answer cueing from the front example; manual suspension/deletion is part of the intended workflow; mixed content rights; no unified quality guarantee.
- **Opportunities:** Add production cards, typed checking, bundled licensed audio, better sense sequencing, collocations, CEFR mappings, and validated multilingual glosses.
- **Threats:** Copyright or redistribution restrictions; overwhelming novice workload; dictionary senses that are technically valid but irrelevant to the learner; online media dependencies; learner abandonment caused by deck administration.

### Gap: English 60K deck versus LEXILO

| Capability | English 60K deck | LEXILO today | Assessment |
|---|---|---|---|
| Breadth | 66,332 sense notes / 32,381 unique surface forms | 39,179 Learning Core terms; broader Full Dictionary deferred | 60K has deeper ready-to-study long tail |
| Sense modeling | One note per definition; core/extend/rare tags | Usually one selected learning sense; no visible sense progression | Material LEXILO gap |
| Workload selection | Frequency subdecks plus manual suspend/delete | Automatic suggestions, level bands, finite active workload | LEXILO advantage |
| Practice direction | Supplied template is word to meaning | Recognition and production, separated by day | Strong LEXILO advantage |
| Objective recall | Self-rated; supplied template has no typed check | Typed production correction; recognition remains self-rated | LEXILO has a stronger production default |
| Context | Usage labels and up to three displayed examples; random front cue | Up to three examples with simpler metadata | 60K is richer, but front cue can weaken retrieval |
| Pronunciation | Mostly available remote dictionary audio | Consistent offline synthesized audio | Authenticity favors 60K where present; reliability/privacy favor LEXILO |
| Translation | Optional AI-generated Simplified Chinese | English-only | Potential accessibility gap, not necessarily a core-product gap |
| Administration | Requires Anki import and deck/card management | Integrated and automatic | LEXILO advantage |
| Content rights | Mixed and field-specific | Kaikki/Wiktionary with explicit attribution and license notices | LEXILO advantage and lower product risk |

## Revised product plan after the Anki audit

### Delivered in v0.9

The audit recommendations that became product work are now implemented:

1. A compact adaptive scheduler stores difficulty, stability, retrievability,
   outcome, latency, and hint signals while keeping the scores out of the main UI.
2. Meaning-to-word cards use typed input, tolerant normalization, accepted
   variants, and precise submitted/expected correction.
3. Sense-aware content supports core, extended, and rare senses, independent
   directions, sequential unlocking, and item-level recovery actions.
4. CSV/TSV import, JSON backup/restore, optional iCloud snapshots, and
   first-language support are available.
5. The Kaikki-only quality pipeline validates examples and pronunciation and
   refreshes lexical content without resetting learner progress.

### Next priorities

1. Keep regression fixtures and source-quality reports growing with each Kaikki
   refresh.
2. Ship a separately versioned Full Dictionary download only when its licensing,
   integrity, size, and update flow are ready.
3. Evaluate cloze, listening, speech assessment, and curated learning packs as
   optional extensions, without adding a Memory dashboard by default.

### UI changes arising from this comparison

#### Practice card

- Keep the current restrained full-screen focus.
- Keep the large native text field and single **Check** action on production cards.
- After checking, show the expected word, the learner’s exact difference, part of speech, one non-leaking example, and pronunciation.
- Keep advanced recovery and content-report actions out of the current practice card; keep the primary card focused on the learning response.
- Continue separating recognition and production siblings by day.

#### Word detail

- Keep the compact sense stack headed by the core meaning, followed by locked or de-emphasized extended senses.
- Keep scheduler difficulty and memory estimates out of the word-detail interface.
- Place register, collocations, examples, and audio within each sense instead of flattening them under the headword.
- Allow the learner to activate or pause individual senses without exposing Anki terminology.

#### Future diagnostics (optional)

- If a future diagnostics surface is added, consider a top summary of due today and upcoming load.
- Show a “Words at risk” list with one-tap focused review.
- Explain schedule changes in human language: “Correct and quick — next review in 12 days.”
- Keep parameter optimization, stability values, and desired-retention settings behind an Advanced panel, if exposed at all.

#### Import flow

- Use a three-step sheet: choose file, map four supported fields, preview five generated items.
- Explain that every accepted entry creates two practice directions.
- Detect duplicates and let the learner merge into an existing lemma or add a new sense.

### Deliberate non-goals

LEXILO should not reproduce:

- Arbitrary card-template HTML/CSS.
- General note-type construction.
- Deep deck hierarchies and dozens of scheduler toggles.
- A plug-in/add-on runtime.
- Four visible grading buttons as the primary interaction.
- A 60,000-rank content dump that requires manual cleanup.
- Unlicensed Merriam-Webster material or copied AGPL implementation code.

The target is **Anki-grade memory adaptation with LEXILO-grade focus**: rigorous scheduling and sense-aware content delivered through an interface that makes vocabulary administration nearly invisible.
