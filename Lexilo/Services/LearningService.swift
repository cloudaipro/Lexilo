import Combine
import Foundation
import WidgetKit

enum ReviewScheduler {
    /// The owner-facing rule is intentionally transparent: the nth successful
    /// answer is reviewed again in n days. The cap prevents dates from
    /// becoming impractical while keeping the progression deterministic.
    static let intervals = Array(1...180)

    static func nextDate(successCount: Int, from date: Date, calendar: Calendar = .current) -> Date {
        let startOfDay = calendar.startOfDay(for: date)
        guard successCount > 0 else { return startOfDay }
        let interval = min(max(successCount, 1), intervals.count)
        return calendar.date(byAdding: .day, value: interval, to: startOfDay) ?? startOfDay
    }

    static func isSameDay(_ lhs: Date?, _ rhs: Date, calendar: Calendar = .current) -> Bool {
        guard let lhs else { return false }
        return calendar.isDate(lhs, inSameDayAs: rhs)
    }
}

@MainActor
final class LearningStore: ObservableObject {
    @Published private(set) var words: [VocabularyItem] = []
    @Published private(set) var cards: [StudyCard] = []
    @Published private(set) var logs: [ReviewLog] = []
    @Published private(set) var studyDays: [StudyDay] = []

    let lexicon: LexiconStore

    private struct Snapshot: Codable {
        let words: [VocabularyItem]
        let cards: [StudyCard]
        let logs: [ReviewLog]
        let studyDays: [StudyDay]
        let lexiconVersion: String?
        let retiredLexiconIDs: Set<String>

        init(words: [VocabularyItem], cards: [StudyCard], logs: [ReviewLog], studyDays: [StudyDay], lexiconVersion: String?, retiredLexiconIDs: Set<String>) {
            self.words = words
            self.cards = cards
            self.logs = logs
            self.studyDays = studyDays
            self.lexiconVersion = lexiconVersion
            self.retiredLexiconIDs = retiredLexiconIDs
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            words = try container.decode([VocabularyItem].self, forKey: .words)
            cards = try container.decode([StudyCard].self, forKey: .cards)
            logs = try container.decode([ReviewLog].self, forKey: .logs)
            // These fields were added after the first persisted format.
            studyDays = try container.decodeIfPresent([StudyDay].self, forKey: .studyDays) ?? []
            lexiconVersion = try container.decodeIfPresent(String.self, forKey: .lexiconVersion)
            retiredLexiconIDs = try container.decodeIfPresent(Set<String>.self, forKey: .retiredLexiconIDs) ?? []
        }
    }

    private let persistenceURL: URL?
    private let publishesWidgetSnapshot: Bool
    private var persistedLexiconVersion: String?
    private var retiredLexiconIDs: Set<String> = []

    private var configuredDailyGoal: Int {
        let value = UserDefaults.standard.object(forKey: "dailyGoal") as? Int ?? 10
        return max(1, value)
    }

    private var configuredNewWordLimit: Int {
        let value = UserDefaults.standard.object(forKey: "newWordLimit") as? Int ?? 5
        return max(1, value)
    }

    init(persistenceURL: URL? = nil, reset: Bool = false, lexicon: LexiconStore? = nil) {
        self.lexicon = lexicon ?? LexiconStore()
        publishesWidgetSnapshot = persistenceURL == nil
        if let persistenceURL {
            self.persistenceURL = persistenceURL
        } else {
            self.persistenceURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appending(path: "lexilo-learning.json")
        }

        if reset {
            if let persistenceURL = self.persistenceURL {
                try? FileManager.default.removeItem(at: persistenceURL)
            }
            UserDefaults.standard.removeObject(forKey: "dailyGoal")
            UserDefaults.standard.removeObject(forKey: "newWordLimit")
        }

        var changed = false
        if !load() {
            seed()
        } else if migrateLoadedState() {
            changed = true
        } else {
            publishWidgetSnapshot()
        }

        if migrateLexiconIdentifiers() { changed = true }
        if refreshStoredLexiconContentIfNeeded() { changed = true }
        if repairStoredEntriesMissingExamples() { changed = true }
        if replenishVocabularyIfNeeded() > 0 { changed = true }
        if changed { save() }
    }

    var lexiconInformation: LexiconInformation { lexicon.information }

    var upcomingWords: [VocabularyItem] {
        words.filter { $0.introducedAt == nil }.sorted { $0.frequencyRank < $1.frequencyRank }
    }

    func searchDictionary(_ query: String, limit: Int = 100) -> [LexiconEntry] {
        lexicon.search(query, limit: limit)
    }

    @discardableResult
    func addToLearning(_ entry: LexiconEntry) -> VocabularyItem {
        if let existing = words.first(where: { $0.lexiconID == entry.id }) { return existing }
        if let existing = words.first(where: { $0.word.caseInsensitiveCompare(entry.word) == .orderedSame }) { return existing }
        let item = makeVocabularyItem(from: entry)
        words.append(item)
        appendCards(for: item)
        save()
        return item
    }

    @discardableResult
    func replaceUnstartedSuggestions() -> Int {
        let removableIDs = Set(words.compactMap { item -> UUID? in
            guard item.introducedAt == nil, !logs.contains(where: { $0.vocabularyID == item.id }) else { return nil }
            return item.id
        })
        guard !removableIDs.isEmpty else { return replenishVocabularyIfNeeded() }
        retiredLexiconIDs.formUnion(words.filter { removableIDs.contains($0.id) }.compactMap(\.lexiconID))
        words.removeAll { removableIDs.contains($0.id) }
        cards.removeAll { removableIDs.contains($0.vocabularyID) }
        UserDefaults.standard.set(UserDefaults.standard.integer(forKey: "rotationNonce") + 1, forKey: "rotationNonce")
        let added = replenishVocabularyIfNeeded()
        save()
        return added
    }

    @discardableResult
    func replenishVocabularyIfNeeded(targetUnseen: Int = 40, now: Date = .now) -> Int {
        guard lexicon.isAvailable else { return 0 }
        let needed = max(0, targetUnseen - upcomingWords.count)
        guard needed > 0 else { return 0 }

        let maximumBand = UserDefaults.standard.object(forKey: "vocabularyBand") as? Int ?? VocabularyBand.intermediate.rawValue
        let includePhrases = UserDefaults.standard.bool(forKey: "includePhrases")
        let existingLexiconIDs = Set(words.compactMap(\.lexiconID))
        let existingWords = Set(words.map { $0.word.lowercased() })
        var available: [LexiconEntry] = []
        var availableWords = existingWords
        var offset = 0
        while available.count < needed && offset < lexicon.information.learningCandidateCount {
            let batch = lexicon.learningCandidates(throughBand: maximumBand, includePhrases: includePhrases, offset: offset)
            if batch.isEmpty { break }
            for entry in batch {
                let normalizedWord = entry.word.lowercased()
                guard !existingLexiconIDs.contains(entry.id), !retiredLexiconIDs.contains(entry.id), !availableWords.contains(normalizedWord) else { continue }
                available.append(entry)
                availableWords.insert(normalizedWord)
            }
            offset += batch.count
        }

        let calendar = Calendar.current
        let day = calendar.ordinality(of: .day, in: .era, for: now) ?? 0
        let nonce = UserDefaults.standard.integer(forKey: "rotationNonce")
        let selected = available.sorted {
            stableRotationHash("\(day):\(nonce):\($0.id)") < stableRotationHash("\(day):\(nonce):\($1.id)")
        }.prefix(needed)
        for entry in selected {
            let item = makeVocabularyItem(from: entry)
            words.append(item)
            appendCards(for: item)
        }
        if !selected.isEmpty { save() }
        return selected.count
    }

    func word(for id: UUID) -> VocabularyItem? {
        words.first { $0.id == id }
    }

    func completedReviews(on date: Date = .now, calendar: Calendar = .current) -> Int {
        logs.filter { calendar.isDate($0.reviewedAt, inSameDayAs: date) }.count
    }

    func currentStreak(now: Date = .now, goal: Int? = nil, calendar: Calendar = .current) -> Int {
        let effectiveGoal = max(1, goal ?? configuredDailyGoal)
        var day = calendar.startOfDay(for: now)
        if !isStudyDayComplete(on: day, goal: effectiveGoal, calendar: calendar) {
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = previous
        }

        var streak = 0
        while isStudyDayComplete(on: day, goal: effectiveGoal, calendar: calendar) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    func sessionCards(limit: Int = 10, now: Date = .now, newWordLimit: Int? = nil, calendar: Calendar = .current) -> [StudyCard] {
        guard limit > 0 else { return [] }
        let cap = max(0, newWordLimit ?? configuredNewWordLimit)
        let ordered = cards.sorted { lhs, rhs in
            let lhsWord = word(for: lhs.vocabularyID)
            let rhsWord = word(for: rhs.vocabularyID)
            let lhsIsNew = lhsWord?.introducedAt == nil
            let rhsIsNew = rhsWord?.introducedAt == nil

            if lhsIsNew != rhsIsNew { return !lhsIsNew }
            if lhs.nextReviewDate != rhs.nextReviewDate { return lhs.nextReviewDate < rhs.nextReviewDate }
            if lhs.successCount != rhs.successCount { return lhs.successCount < rhs.successCount }
            if lhsWord?.frequencyRank != rhsWord?.frequencyRank { return (lhsWord?.frequencyRank ?? .max) < (rhsWord?.frequencyRank ?? .max) }
            if lhs.direction != rhs.direction { return lhs.direction == .recognition }
            return lhs.id.uuidString < rhs.id.uuidString
        }

        var servedVocabulary = Set<UUID>()
        var introducedVocabulary = Set<UUID>(words.compactMap { item in
            guard let introducedAt = item.introducedAt,
                  calendar.isDate(introducedAt, inSameDayAs: now)
            else { return nil }
            return item.id
        })
        var result: [StudyCard] = []

        for card in ordered where card.nextReviewDate <= now {
            guard word(for: card.vocabularyID) != nil else { continue }
            // A card answered today is available to the active session's
            // recycle queue, but should not start a second queue today.
            guard !ReviewScheduler.isSameDay(card.lastReviewedDate, now, calendar: calendar) else { continue }
            guard !servedVocabulary.contains(card.vocabularyID) else { continue }
            guard !pairedCardWasPresentedToday(for: card, now: now, calendar: calendar) else { continue }

            let isNewWord = word(for: card.vocabularyID)?.introducedAt == nil
            if isNewWord {
                guard introducedVocabulary.count < cap else { continue }
                introducedVocabulary.insert(card.vocabularyID)
            }

            servedVocabulary.insert(card.vocabularyID)
            result.append(card)
            if result.count == limit { break }
        }
        return result
    }

    /// Marks the selected cards as presented and introduces only the number of
    /// new vocabulary items allowed for this day. The returned cards include
    /// the presentation timestamp for callers that keep the queue locally.
    @discardableResult
    func startSession(limit: Int = 10, now: Date = .now, newWordLimit: Int? = nil, calendar: Calendar = .current) -> [StudyCard] {
        let selected = sessionCards(limit: limit, now: now, newWordLimit: newWordLimit, calendar: calendar)
        guard !selected.isEmpty else { return [] }

        let newVocabularyIDs = Set(selected.compactMap { card in
            words.first(where: { $0.id == card.vocabularyID && $0.introducedAt == nil })?.id
        })
        var changed = false

        for index in words.indices where newVocabularyIDs.contains(words[index].id) {
            words[index].introducedAt = now
            changed = true
        }
        for card in selected {
            guard let index = cards.firstIndex(where: { $0.id == card.id }) else { continue }
            cards[index].lastPresentedDate = now
            changed = true
        }

        upsertStudyDay(on: now, reviewedCount: 0, newWordsIntroduced: newVocabularyIDs.count, calendar: calendar)
        if changed { save() }
        if !newVocabularyIDs.isEmpty { _ = replenishVocabularyIfNeeded(now: now) }

        return selected.map { card in
            var presented = card
            presented.lastPresentedDate = now
            return presented
        }
    }

    func answer(cardID: UUID, correct: Bool, now: Date = .now, calendar: Calendar = .current) {
        guard let index = cards.firstIndex(where: { $0.id == cardID }) else { return }
        let scheduledFor = cards[index].nextReviewDate

        if correct {
            cards[index].successCount += 1
            cards[index].learningState = cards[index].successCount >= 7 ? .mastered : .learning
            cards[index].nextReviewDate = ReviewScheduler.nextDate(successCount: cards[index].successCount, from: now, calendar: calendar)
        } else {
            cards[index].successCount = 0
            cards[index].learningState = .learning
            // Zero-day reset: the active practice queue owns the immediate
            // retry; a newly opened session will wait until tomorrow.
            cards[index].nextReviewDate = ReviewScheduler.nextDate(successCount: 0, from: now, calendar: calendar)
        }

        cards[index].lastReviewedDate = now
        cards[index].lastPresentedDate = now
        logs.append(ReviewLog(card: cards[index], correct: correct, scheduledFor: scheduledFor, reviewedAt: now))
        upsertStudyDay(on: now, reviewedCount: 1, newWordsIntroduced: 0, calendar: calendar)
        save()
    }

    func featuredWord(now: Date = .now, calendar: Calendar = .current) -> VocabularyItem? {
        let unmastered = words.filter { !isMastered(vocabularyID: $0.id) }
        let withExamples = unmastered.filter { !$0.examples.isEmpty }
        let candidates = withExamples.isEmpty ? unmastered : withExamples
        return candidates.sorted { lhs, rhs in
            let lhsCards = cards.filter { $0.vocabularyID == lhs.id }
            let rhsCards = cards.filter { $0.vocabularyID == rhs.id }
            let lhsDue = lhsCards.contains { $0.nextReviewDate <= now && !ReviewScheduler.isSameDay($0.lastReviewedDate, now, calendar: calendar) }
            let rhsDue = rhsCards.contains { $0.nextReviewDate <= now && !ReviewScheduler.isSameDay($0.lastReviewedDate, now, calendar: calendar) }
            if lhsDue != rhsDue { return lhsDue }
            let lhsSuccess = lhsCards.map(\.successCount).min() ?? 0
            let rhsSuccess = rhsCards.map(\.successCount).min() ?? 0
            if lhsSuccess != rhsSuccess { return lhsSuccess < rhsSuccess }
            return lhs.frequencyRank < rhs.frequencyRank
        }.first
    }

    func widgetSnapshot(now: Date = .now, calendar: Calendar = .current) -> WidgetStudySnapshot? {
        guard let word = featuredWord(now: now, calendar: calendar) else { return nil }
        return WidgetStudySnapshot(
            vocabularyID: word.id,
            word: word.word,
            example: word.example,
            streak: currentStreak(now: now, calendar: calendar)
        )
    }

    private func isMastered(vocabularyID: UUID) -> Bool {
        let related = cards.filter { $0.vocabularyID == vocabularyID }
        return related.count == 2 && related.allSatisfy { $0.learningState == .mastered }
    }

    private func appendCards(for item: VocabularyItem) {
        let start = Calendar.current.startOfDay(for: .now)
        cards.append(StudyCard(vocabularyID: item.id, direction: .recognition, nextReviewDate: start))
        cards.append(StudyCard(vocabularyID: item.id, direction: .recall, nextReviewDate: start))
    }

    private func makeVocabularyItem(from entry: LexiconEntry) -> VocabularyItem {
        VocabularyItem(
            lexiconID: entry.id,
            word: entry.word,
            partOfSpeech: entry.partOfSpeech,
            ipa: entry.ipa.isEmpty ? "—" : "/\(entry.ipa.trimmingCharacters(in: CharacterSet(charactersIn: "/")))/",
            conciseDefinition: entry.definition,
            example: entry.primaryExample,
            additionalExamples: Array(entry.examples.dropFirst()),
            frequencyRank: entry.frequencyRank
        )
    }

    private func stableRotationHash(_ value: String) -> UInt64 {
        value.utf8.reduce(14_695_981_039_346_656_037) { partial, byte in
            (partial ^ UInt64(byte)) &* 1_099_511_628_211
        }
    }

    private func pairedCardWasPresentedToday(for card: StudyCard, now: Date, calendar: Calendar) -> Bool {
        cards.contains { other in
            other.vocabularyID == card.vocabularyID && other.id != card.id && (
                ReviewScheduler.isSameDay(other.lastPresentedDate, now, calendar: calendar)
                    || ReviewScheduler.isSameDay(other.lastReviewedDate, now, calendar: calendar)
            )
        }
    }

    private func upsertStudyDay(on date: Date, reviewedCount: Int, newWordsIntroduced: Int, calendar: Calendar) {
        let startOfDay = calendar.startOfDay(for: date)
        if let index = studyDays.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: startOfDay) }) {
            studyDays[index].reviewedCount += reviewedCount
            studyDays[index].newWordsIntroduced += newWordsIntroduced
            studyDays[index].goal = configuredDailyGoal
            studyDays[index].completed = studyDays[index].reviewedCount >= studyDays[index].goal
        } else {
            studyDays.append(StudyDay(date: startOfDay, goal: configuredDailyGoal, reviewedCount: reviewedCount, newWordsIntroduced: newWordsIntroduced))
        }
        studyDays.sort { $0.date < $1.date }
    }

    private func isStudyDayComplete(on date: Date, goal: Int, calendar: Calendar) -> Bool {
        if let day = studyDays.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
            return day.completed || day.reviewedCount >= goal
        }
        return completedReviews(on: date, calendar: calendar) >= goal
    }

    private func seed() {
        words = []
        cards = []
        logs = []
        studyDays = []
        if replenishVocabularyIfNeeded() == 0 { save() }
    }

    @discardableResult
    private func migrateLexiconIdentifiers() -> Bool {
        guard lexicon.isAvailable else { return false }
        var changed = false
        var unmatchedWordIDs: Set<UUID> = []
        for index in words.indices where words[index].lexiconID == nil {
            if let entry = lexicon.entry(matching: words[index].word, partOfSpeech: words[index].partOfSpeech) {
                words[index].lexiconID = entry.id
                changed = true
            } else {
                unmatchedWordIDs.insert(words[index].id)
            }
        }
        if !unmatchedWordIDs.isEmpty {
            words.removeAll { unmatchedWordIDs.contains($0.id) }
            cards.removeAll { unmatchedWordIDs.contains($0.vocabularyID) }
            changed = true
        }
        return changed
    }

    @discardableResult
    private func refreshStoredLexiconContentIfNeeded() -> Bool {
        guard lexicon.isAvailable, persistedLexiconVersion != lexicon.information.version else { return false }
        for index in words.indices {
            guard let lexiconID = words[index].lexiconID, let entry = lexicon.entry(id: lexiconID) else { continue }
            apply(entry, toWordAt: index)
        }
        persistedLexiconVersion = lexicon.information.version
        return true
    }

    /// Earlier app versions could persist a dictionary sense that had no
    /// teaching example (for example the rare noun sense of "pragmatic").
    /// Preserve cards/history and replace only its lexical content with the
    /// preferred OEWN learning sense for the same lemma.
    @discardableResult
    private func repairStoredEntriesMissingExamples() -> Bool {
        guard lexicon.isAvailable else { return false }
        var changed = false
        for index in words.indices where words[index].examples.isEmpty {
            guard let replacement = lexicon.learningEntry(matching: words[index].word),
                  !replacement.examples.isEmpty
            else { continue }
            apply(replacement, toWordAt: index)
            changed = true
        }
        return changed
    }

    private func apply(_ entry: LexiconEntry, toWordAt index: Int) {
        words[index].lexiconID = entry.id
        words[index].partOfSpeech = entry.partOfSpeech
        words[index].ipa = entry.ipa.isEmpty ? "—" : "/\(entry.ipa.trimmingCharacters(in: CharacterSet(charactersIn: "/")))/"
        words[index].conciseDefinition = entry.definition
        words[index].example = entry.primaryExample
        words[index].additionalExamples = Array(entry.examples.dropFirst())
    }

    @discardableResult
    private func migrateLoadedState() -> Bool {
        var changed = false
        let firstReviewByWord = Dictionary(grouping: logs, by: \.vocabularyID).compactMapValues { group in
            group.map(\.reviewedAt).min()
        }

        for index in words.indices where words[index].introducedAt == nil {
            if let firstReview = firstReviewByWord[words[index].id] {
                words[index].introducedAt = firstReview
                changed = true
            }
        }

        if studyDays.isEmpty, !logs.isEmpty {
            let grouped = Dictionary(grouping: logs) { Calendar.current.startOfDay(for: $0.reviewedAt) }
            studyDays = grouped.map { date, dayLogs in
                StudyDay(date: date, goal: configuredDailyGoal, reviewedCount: dayLogs.count)
            }.sorted { $0.date < $1.date }
            changed = true
        }
        return changed
    }

    @discardableResult
    private func load() -> Bool {
        guard let persistenceURL,
              let data = try? Data(contentsOf: persistenceURL),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data)
        else { return false }

        words = snapshot.words
        cards = snapshot.cards
        logs = snapshot.logs
        studyDays = snapshot.studyDays
        persistedLexiconVersion = snapshot.lexiconVersion
        retiredLexiconIDs = snapshot.retiredLexiconIDs
        return true
    }

    private func save() {
        if lexicon.isAvailable { persistedLexiconVersion = lexicon.information.version }
        if let persistenceURL, let data = try? JSONEncoder().encode(Snapshot(words: words, cards: cards, logs: logs, studyDays: studyDays, lexiconVersion: persistedLexiconVersion, retiredLexiconIDs: retiredLexiconIDs)) {
            try? FileManager.default.createDirectory(at: persistenceURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: persistenceURL, options: .atomic)
        }
        publishWidgetSnapshot()
    }

    private func publishWidgetSnapshot() {
        guard publishesWidgetSnapshot else { return }
        if let snapshot = widgetSnapshot() {
            SharedStudySnapshotStore.save(snapshot)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "LexiloWord")
    }
}
