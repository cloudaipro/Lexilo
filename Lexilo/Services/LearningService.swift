import Combine
import Foundation
import WidgetKit

enum ReviewScheduler {
    static let defaultDesiredRetention = 0.9
    static let maximumInterval = 3_650

    struct Update {
        let difficulty: Double
        let stability: Double
        let retrievabilityBeforeReview: Double
        let intervalDays: Int
        let nextReviewDate: Date
    }

    static func retrievability(for card: StudyCard, at date: Date) -> Double {
        guard let lastReview = card.lastReviewedDate else { return 1 }
        let elapsedDays = max(0, date.timeIntervalSince(lastReview) / 86_400)
        let stability = max(0.1, card.stability)
        return min(1, max(0, pow(0.9, elapsedDays / stability)))
    }

    /// An independent, compact memory model inspired by the same observable
    /// variables as modern SRS research. It does not incorporate Anki code.
    static func update(
        card: StudyCard,
        outcome: ReviewOutcome,
        responseTime: TimeInterval?,
        usedHint: Bool,
        at date: Date,
        desiredRetention: Double = defaultDesiredRetention,
        calendar: Calendar = .current
    ) -> Update {
        let retrievability = self.retrievability(for: card, at: date)
        let latency = max(0, responseTime ?? 8)
        let speedSignal = min(1.15, max(0.78, 1.1 - latency / 70))
        let hintSignal = usedHint ? 0.72 : 1.0
        var difficulty = card.difficulty
        var stability = max(0.6, card.stability)

        switch outcome {
        case .again:
            difficulty = min(10, difficulty + 0.75)
            stability = max(0.45, stability * (0.42 + 0.18 * retrievability))
        case .correct, .easy:
            let easySignal = outcome == .easy ? 1.35 : 1
            difficulty = min(10, max(1, difficulty - (outcome == .easy ? 0.55 : 0.12) * hintSignal))
            if card.lastReviewedDate == nil {
                stability = max(1, (outcome == .easy ? 3.2 : 1.2) * speedSignal * hintSignal)
            } else {
                let difficultyGain = max(0.18, (11 - difficulty) / 10)
                let forgettingGain = pow(max(retrievability, 0.05), -0.65)
                stability *= 1 + difficultyGain * forgettingGain * 0.72 * speedSignal * hintSignal * easySignal
            }
        }

        let target = min(0.97, max(0.8, desiredRetention))
        let rawInterval = stability * log(target) / log(0.9)
        let interval = outcome == .again ? 1 : min(maximumInterval, max(1, Int(rawInterval.rounded())))
        let start = calendar.startOfDay(for: date)
        let next = calendar.date(byAdding: .day, value: interval, to: start) ?? start
        return Update(
            difficulty: difficulty,
            stability: stability,
            retrievabilityBeforeReview: retrievability,
            intervalDays: interval,
            nextReviewDate: next
        )
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
    @Published private(set) var contentReports: [ContentReport] = []

    let lexicon: LexiconStore

    private struct Snapshot: Codable {
        let words: [VocabularyItem]
        let cards: [StudyCard]
        let logs: [ReviewLog]
        let studyDays: [StudyDay]
        let lexiconVersion: String?
        let retiredLexiconIDs: Set<String>
        let contentReports: [ContentReport]
        let modifiedAt: Date

        init(words: [VocabularyItem], cards: [StudyCard], logs: [ReviewLog], studyDays: [StudyDay], lexiconVersion: String?, retiredLexiconIDs: Set<String>, contentReports: [ContentReport], modifiedAt: Date = .now) {
            self.words = words
            self.cards = cards
            self.logs = logs
            self.studyDays = studyDays
            self.lexiconVersion = lexiconVersion
            self.retiredLexiconIDs = retiredLexiconIDs
            self.contentReports = contentReports
            self.modifiedAt = modifiedAt
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
            contentReports = try container.decodeIfPresent([ContentReport].self, forKey: .contentReports) ?? []
            modifiedAt = try container.decodeIfPresent(Date.self, forKey: .modifiedAt) ?? .distantPast
        }
    }

    private let persistenceURL: URL?
    private let publishesWidgetSnapshot: Bool
    private var persistedLexiconVersion: String?
    private var retiredLexiconIDs: Set<String> = []
    private var lastModifiedAt: Date = .distantPast
    private var isInitializing = true

    private var desiredRetention: Double {
        let configured = UserDefaults.standard.object(forKey: "desiredRetention") as? Double ?? ReviewScheduler.defaultDesiredRetention
        return min(0.97, max(0.8, configured))
    }

    private var iCloudSyncEnabled: Bool { UserDefaults.standard.bool(forKey: "iCloudSyncEnabled") }

    private var iCloudPersistenceURL: URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: nil)?
            .appending(path: "Documents", directoryHint: .isDirectory)
            .appending(path: "lexilo-learning.json")
    }

    private var backupPersistenceURL: URL? {
        persistenceURL?.appendingPathExtension("backup")
    }

    private var configuredDailyGoal: Int {
        let value = UserDefaults.standard.object(forKey: "newWordLimit") as? Int ?? 5
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
        let hadLocalSnapshot = self.persistenceURL.map { FileManager.default.fileExists(atPath: $0.path) } ?? false

        if reset {
            if let persistenceURL = self.persistenceURL {
                try? FileManager.default.removeItem(at: persistenceURL)
                try? FileManager.default.removeItem(at: persistenceURL.appendingPathExtension("backup"))
                try? FileManager.default.removeItem(at: persistenceURL.appendingPathExtension("corrupt"))
            }
            for key in [
                "dailyGoal", "newWordLimit", "vocabularyBand", "includePhrases", "rotationNonce",
                "soundEnabled", "kittenVoiceID", "kittenSpeechRate", "pronunciationLocale",
                "desiredRetention", "iCloudSyncEnabled", "translationEnabled", "translationLanguage",
                "hasCompletedOnboarding", MediumWidgetContent.preferenceKey
            ] {
                UserDefaults.standard.removeObject(forKey: key)
            }
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
        if repairStoredLexiconContent() { changed = true }
        if migrateSenseAwareState() { changed = true }
        if replenishVocabularyIfNeeded() > 0 { changed = true }
        if changed { save() }
        isInitializing = false
        if iCloudSyncEnabled {
            syncFromICloudIfNewer(force: !hadLocalSnapshot)
            save()
        }
#if DEBUG
        if CommandLine.arguments.contains("--ui-testing-recall") {
            for index in cards.indices where cards[index].direction == .recognition { cards[index].isPaused = true }
            save()
        }
#endif
    }

    var lexiconInformation: LexiconInformation { lexicon.information }

    var upcomingWords: [VocabularyItem] {
        words.filter { $0.introducedAt == nil }.sorted { $0.frequencyRank < $1.frequencyRank }
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

        let selectedBand = UserDefaults.standard.object(forKey: "vocabularyBand") as? Int ?? VocabularyBand.intermediate.rawValue
        let includePhrases = UserDefaults.standard.bool(forKey: "includePhrases")
        let existingLexiconIDs = Set(words.compactMap(\.lexiconID))
        let existingWords = Set(words.map { $0.word.lowercased() })
        let calendar = Calendar.current
        let day = calendar.ordinality(of: .day, in: .era, for: now) ?? 0
        let nonce = UserDefaults.standard.integer(forKey: "rotationNonce")
        let references = lexicon.learningCandidateReferences(inBand: selectedBand, includePhrases: includePhrases)
        let orderedReferences = references.sorted {
            let lhsHash = stableRotationHash("\(day):\(nonce):\($0.id)")
            let rhsHash = stableRotationHash("\(day):\(nonce):\($1.id)")
            return lhsHash == rhsHash ? $0.id < $1.id : lhsHash < rhsHash
        }
        var selectedIDs: [String] = []
        var selectedWords = existingWords
        for reference in orderedReferences {
            guard !existingLexiconIDs.contains(reference.id),
                  !retiredLexiconIDs.contains(reference.id),
                  !selectedWords.contains(reference.normalizedWord)
            else { continue }
            selectedIDs.append(reference.id)
            selectedWords.insert(reference.normalizedWord)
            if selectedIDs.count == needed { break }
        }
        let entriesByID = Dictionary(uniqueKeysWithValues: lexicon.entries(ids: selectedIDs).map { ($0.id, $0) })
        let selected = selectedIDs.compactMap { entriesByID[$0] }
        for entry in selected {
            let item = makeVocabularyItem(from: entry)
            words.append(item)
            appendCards(for: item, now: now)
        }
        if !selected.isEmpty { save() }
        return selected.count
    }

    func word(for id: UUID) -> VocabularyItem? {
        words.first { $0.id == id }
    }

    func sense(for card: StudyCard) -> LexicalSense? {
        guard let word = word(for: card.vocabularyID) else { return nil }
        if let senseID = card.senseID, let match = word.senses.first(where: { $0.id == senseID }) { return match }
        return word.coreSense
    }

    func currentRetrievability(for card: StudyCard, now: Date = .now) -> Double {
        ReviewScheduler.retrievability(for: card, at: now)
    }

    func strength(vocabularyID: UUID, direction: CardDirection, now: Date = .now) -> Double {
        let related = cards.filter { $0.vocabularyID == vocabularyID && $0.direction == direction && !$0.isPaused && $0.lastReviewedDate != nil }
        guard !related.isEmpty else { return 0 }
        return related.map { currentRetrievability(for: $0, now: now) }.reduce(0, +) / Double(related.count)
    }

    /// Returns the average card difficulty for a word, sense, or direction.
    /// Difficulty is kept on each StudyCard, so a word with multiple senses
    /// can have a different value for every sense and practice direction.
    func averageDifficulty(
        vocabularyID: UUID,
        senseID: UUID? = nil,
        direction: CardDirection? = nil,
        includePaused: Bool = false
    ) -> Double? {
        let matching = cards.filter {
            $0.vocabularyID == vocabularyID
                && (senseID == nil || $0.senseID == senseID)
                && (direction == nil || $0.direction == direction)
                && (includePaused || !$0.isPaused)
        }
        guard !matching.isEmpty else { return nil }
        return matching.map(\.difficulty).reduce(0, +) / Double(matching.count)
    }

    func hasReviewedCard(
        vocabularyID: UUID,
        senseID: UUID? = nil,
        direction: CardDirection? = nil,
        includePaused: Bool = false
    ) -> Bool {
        cards.contains {
            $0.vocabularyID == vocabularyID
                && (senseID == nil || $0.senseID == senseID)
                && (direction == nil || $0.direction == direction)
                && (includePaused || !$0.isPaused)
                && $0.lastReviewedDate != nil
        }
    }

    func card(vocabularyID: UUID, senseID: UUID, direction: CardDirection) -> StudyCard? {
        cards.first {
            $0.vocabularyID == vocabularyID
                && $0.senseID == senseID
                && $0.direction == direction
        }
    }

    func difficultyLabel(for difficulty: Double) -> String {
        if difficulty < 3.5 { return "Easy" }
        if difficulty < 6.5 { return "Moderate" }
        return "Hard"
    }

    func estimatedRetention(now: Date = .now) -> Double {
        let reviewed = cards.filter { $0.lastReviewedDate != nil && !$0.isPaused }
        guard !reviewed.isEmpty else { return 0 }
        return reviewed.map { currentRetrievability(for: $0, now: now) }.reduce(0, +) / Double(reviewed.count)
    }

    func dueForecast(days: Int = 7, now: Date = .now, calendar: Calendar = .current) -> [MemoryForecastDay] {
        let today = calendar.startOfDay(for: now)
        return (0..<max(1, days)).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: today) ?? today
            let next = calendar.date(byAdding: .day, value: 1, to: date) ?? date
            let count = cards.filter {
                guard !$0.isPaused else { return false }
                return offset == 0 ? $0.nextReviewDate < next : ($0.nextReviewDate >= date && $0.nextReviewDate < next)
            }.count
            return MemoryForecastDay(date: date, count: count)
        }
    }

    func fragileWords(limit: Int = 12, now: Date = .now) -> [VocabularyItem] {
        words.filter { word in
            let active = cards.filter { $0.vocabularyID == word.id && $0.lastReviewedDate != nil && !$0.isPaused }
            return active.contains { currentRetrievability(for: $0, now: now) < 0.82 }
        }
        .sorted { lhs, rhs in
            let left = cards.filter { $0.vocabularyID == lhs.id }.map { currentRetrievability(for: $0, now: now) }.min() ?? 1
            let right = cards.filter { $0.vocabularyID == rhs.id }.map { currentRetrievability(for: $0, now: now) }.min() ?? 1
            return left < right
        }
        .prefix(limit)
        .map { $0 }
    }

    func memoryLabel(for card: StudyCard, now: Date = .now) -> String {
        let value = currentRetrievability(for: card, now: now)
        if value >= 0.9 { return "Strong" }
        if value >= 0.75 { return "Fading" }
        return "Needs recall"
    }

    func pause(vocabularyID: UUID, senseID: UUID?) {
        guard let wordIndex = words.firstIndex(where: { $0.id == vocabularyID }) else { return }
        let target = senseID ?? words[wordIndex].coreSense?.id
        if let target, let senseIndex = words[wordIndex].senses.firstIndex(where: { $0.id == target }) {
            words[wordIndex].senses[senseIndex].isPaused = true
            for index in cards.indices where cards[index].vocabularyID == vocabularyID && cards[index].senseID == target {
                cards[index].isPaused = true
            }
            save()
        }
    }

    func resume(vocabularyID: UUID, senseID: UUID) {
        guard let wordIndex = words.firstIndex(where: { $0.id == vocabularyID }),
              let senseIndex = words[wordIndex].senses.firstIndex(where: { $0.id == senseID })
        else { return }
        words[wordIndex].senses[senseIndex].isPaused = false
        words[wordIndex].senses[senseIndex].isActive = true
        let start = Calendar.current.startOfDay(for: .now)
        appendCards(vocabularyID: vocabularyID, senseID: senseID, start: start)
        for index in cards.indices where cards[index].vocabularyID == vocabularyID && cards[index].senseID == senseID {
            cards[index].isPaused = false
        }
        save()
    }

    func markWrongSense(vocabularyID: UUID, senseID: UUID?) {
        reportContent(vocabularyID: vocabularyID, senseID: senseID, reason: "Wrong sense")
        pause(vocabularyID: vocabularyID, senseID: senseID)
        activateNextSense(vocabularyID: vocabularyID)
        save()
    }

    func markTooEasy(vocabularyID: UUID, senseID: UUID?) {
        let indices = cards.indices.filter { cards[$0].vocabularyID == vocabularyID && (senseID == nil || cards[$0].senseID == senseID) }
        for index in indices {
            cards[index].difficulty = max(1, cards[index].difficulty - 1)
            cards[index].stability = max(7, cards[index].stability * 1.8)
            cards[index].learningState = cards[index].stability >= 21 ? .mastered : .learning
            let interval = min(ReviewScheduler.maximumInterval, max(7, Int(cards[index].stability.rounded())))
            cards[index].nextReviewDate = Calendar.current.date(byAdding: .day, value: interval, to: Calendar.current.startOfDay(for: .now)) ?? .now
            cards[index].lastOutcome = .easy
        }
        save()
    }

    func reportContent(vocabularyID: UUID, senseID: UUID?, reason: String) {
        contentReports.append(ContentReport(vocabularyID: vocabularyID, senseID: senseID, reason: reason))
        save()
    }

    func updateTranslation(vocabularyID: UUID, senseID: UUID, text: String) {
        guard let wordIndex = words.firstIndex(where: { $0.id == vocabularyID }),
              let senseIndex = words[wordIndex].senses.firstIndex(where: { $0.id == senseID })
        else { return }
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        words[wordIndex].senses[senseIndex].translation = clean.isEmpty ? nil : clean
        words[wordIndex].senses[senseIndex].translationProvenance = clean.isEmpty ? nil : .personal
        save()
    }

    func confirmTranslation(vocabularyID: UUID, senseID: UUID) {
        guard let wordIndex = words.firstIndex(where: { $0.id == vocabularyID }),
              let senseIndex = words[wordIndex].senses.firstIndex(where: { $0.id == senseID }),
              words[wordIndex].senses[senseIndex].translation?.isEmpty == false
        else { return }
        words[wordIndex].senses[senseIndex].translationProvenance = .reviewed
        save()
    }

    func setSenseActive(vocabularyID: UUID, senseID: UUID, active: Bool) {
        guard let wordIndex = words.firstIndex(where: { $0.id == vocabularyID }),
              let senseIndex = words[wordIndex].senses.firstIndex(where: { $0.id == senseID })
        else { return }
        words[wordIndex].senses[senseIndex].isActive = active
        words[wordIndex].senses[senseIndex].isPaused = !active
        if active { resume(vocabularyID: vocabularyID, senseID: senseID) }
        else { pause(vocabularyID: vocabularyID, senseID: senseID) }
    }

    var contentQualitySummary: ContentQualitySummary {
        let allSenses = words.flatMap(\.senses)
        let duplicates = words.reduce(0) { count, word in
            let definitions = word.senses.map { AnswerEvaluator.normalize($0.definition) }
            return count + max(0, definitions.count - Set(definitions).count)
        }
        let confusing = allSenses.filter {
            let length = $0.definition.trimmingCharacters(in: .whitespacesAndNewlines).count
            return length < 12 || length > 240
        }.count
        let leakage = words.reduce(0) { count, word in
            count + word.senses.filter { sense in
                AnswerEvaluator.normalize(sense.definition).split(separator: " ").contains(Substring(AnswerEvaluator.normalize(word.word)))
            }.count
        }
        return ContentQualitySummary(
            missingIPA: words.filter { $0.ipa.isEmpty || $0.ipa == "—" }.count,
            missingExamples: allSenses.filter { $0.examples.isEmpty }.count,
            duplicatedSenses: duplicates,
            confusingDefinitions: confusing,
            exampleLeakage: leakage,
            learnerReports: contentReports.count
        )
    }

    @discardableResult
    func importPersonalRows(_ rows: [PersonalImportRow], duplicateResolution: ImportDuplicateResolution, now: Date = .now) -> Int {
        var imported = 0
        for row in rows {
            let cleanWord = row.word.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanMeaning = row.meaning.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanWord.isEmpty, !cleanMeaning.isEmpty else { continue }
            if let existingIndex = words.firstIndex(where: { AnswerEvaluator.normalize($0.word) == AnswerEvaluator.normalize(cleanWord) }) {
                guard duplicateResolution == .mergeSense else { continue }
                let duplicate = words[existingIndex].senses.contains { AnswerEvaluator.normalize($0.definition) == AnswerEvaluator.normalize(cleanMeaning) }
                guard !duplicate else { continue }
                let sense = LexicalSense(
                    definition: cleanMeaning,
                    examples: row.example.isEmpty ? [] : [row.example],
                    collocations: Self.deriveCollocations(word: cleanWord, examples: [row.example]),
                    priority: .extended,
                    isActive: true
                )
                words[existingIndex].senses.append(sense)
                words[existingIndex].tags = Array(Set(words[existingIndex].tags + row.tags)).sorted()
                appendCards(vocabularyID: words[existingIndex].id, senseID: sense.id, start: Calendar.current.startOfDay(for: now))
                imported += 1
            } else {
                let sense = LexicalSense(
                    definition: cleanMeaning,
                    examples: row.example.isEmpty ? [] : [row.example],
                    collocations: Self.deriveCollocations(word: cleanWord, examples: [row.example])
                )
                let item = VocabularyItem(
                    word: cleanWord,
                    partOfSpeech: "personal",
                    ipa: "—",
                    conciseDefinition: cleanMeaning,
                    example: row.example,
                    frequencyRank: Int.max,
                    senses: [sense],
                    acceptedAnswers: [],
                    tags: row.tags,
                    isPersonal: true
                )
                words.append(item)
                appendCards(for: item, now: now)
                imported += 1
            }
        }
        if imported > 0 { save() }
        return imported
    }

    func exportData() throws -> Data {
        try JSONEncoder().encode(Snapshot(
            words: words,
            cards: cards,
            logs: logs,
            studyDays: studyDays,
            lexiconVersion: persistedLexiconVersion,
            retiredLexiconIDs: retiredLexiconIDs,
            contentReports: contentReports,
            modifiedAt: lastModifiedAt
        ))
    }

    func restore(from data: Data) throws {
        let snapshot = try JSONDecoder().decode(Snapshot.self, from: data)
        guard snapshot.words.allSatisfy({ !$0.word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        apply(snapshot)
        _ = migrateSenseAwareState()
        save()
    }

    @discardableResult
    func setICloudSync(enabled: Bool) -> Bool {
        guard !enabled || iCloudPersistenceURL != nil else { return false }
        UserDefaults.standard.set(enabled, forKey: "iCloudSyncEnabled")
        if enabled {
            syncFromICloudIfNewer(force: logs.isEmpty)
            save()
        }
        return true
    }

    func completedReviews(on date: Date = .now, calendar: Calendar = .current) -> Int {
        logs.filter { calendar.isDate($0.reviewedAt, inSameDayAs: date) }.count
    }

    /// Unique vocabulary practised on a calendar day, ordered by first answer.
    /// Repeated attempts for a missed card still count as one word.
    func practicedVocabularyIDs(on date: Date = .now, calendar: Calendar = .current) -> [UUID] {
        let dayLogs = logs
            .filter { calendar.isDate($0.reviewedAt, inSameDayAs: date) }
            .sorted { $0.reviewedAt < $1.reviewedAt }
        var seen = Set<UUID>()
        return dayLogs.compactMap { log in
            guard seen.insert(log.vocabularyID).inserted else { return nil }
            return log.vocabularyID
        }
    }

    func practicedWordCount(on date: Date = .now, calendar: Calendar = .current) -> Int {
        practicedVocabularyIDs(on: date, calendar: calendar).count
    }

    func currentStreak(now: Date = .now, goal: Int? = nil, calendar: Calendar = .current) -> Int {
        let effectiveGoal = max(1, goal ?? configuredDailyGoal)
        let today = calendar.startOfDay(for: now)
        var day = today
        if !isStudyDayComplete(on: day, currentGoal: effectiveGoal, calendar: calendar) {
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = previous
        }

        var streak = 0
        while isStudyDayComplete(
            on: day,
            currentGoal: calendar.isDate(day, inSameDayAs: today) ? effectiveGoal : nil,
            fallbackGoal: effectiveGoal,
            calendar: calendar
        ) {
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

        for card in ordered where card.nextReviewDate <= now && !card.isPaused {
            guard word(for: card.vocabularyID) != nil else { continue }
            guard sense(for: card)?.isPaused != true else { continue }
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

    /// Selects the next group of distinct words for today's cumulative set.
    /// Due reviews remain first; unseen vocabulary fills any remaining slots.
    func roundCards(wordCount: Int? = nil, now: Date = .now, calendar: Calendar = .current) -> [StudyCard] {
        let count = max(1, wordCount ?? configuredNewWordLimit)
        let alreadyPractised = Set(practicedVocabularyIDs(on: now, calendar: calendar))
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
        var result: [StudyCard] = []
        for card in ordered where card.nextReviewDate <= now && !card.isPaused {
            guard word(for: card.vocabularyID) != nil,
                  !alreadyPractised.contains(card.vocabularyID),
                  !servedVocabulary.contains(card.vocabularyID),
                  sense(for: card)?.isPaused != true,
                  !ReviewScheduler.isSameDay(card.lastReviewedDate, now, calendar: calendar),
                  !pairedCardWasPresentedToday(for: card, now: now, calendar: calendar)
            else { continue }

            servedVocabulary.insert(card.vocabularyID)
            result.append(card)
            if result.count == count { break }
        }
        return result
    }

    /// Begins one normal round. Every call selects the next group of words not
    /// yet completed today, so repeated calls grow today's set by the round size.
    @discardableResult
    func startRound(wordCount: Int? = nil, now: Date = .now, calendar: Calendar = .current) -> [StudyCard] {
        let selected = roundCards(wordCount: wordCount, now: now, calendar: calendar)
        guard !selected.isEmpty else { return [] }

        let newVocabularyIDs = Set(selected.compactMap { card in
            words.first(where: { $0.id == card.vocabularyID && $0.introducedAt == nil })?.id
        })
        for index in words.indices where newVocabularyIDs.contains(words[index].id) {
            words[index].introducedAt = now
        }
        for card in selected {
            if let index = cards.firstIndex(where: { $0.id == card.id }) {
                cards[index].lastPresentedDate = now
            }
        }

        upsertStudyDay(on: now, reviewedCount: 0, newWordsIntroduced: newVocabularyIDs.count, calendar: calendar)
        save()
        if !newVocabularyIDs.isEmpty { _ = replenishVocabularyIfNeeded(now: now) }
        return selected.map { card in
            var presented = card
            presented.lastPresentedDate = now
            return presented
        }
    }

    /// Replays every distinct word completed today without changing scheduling.
    func practiceAgainCards(now: Date = .now, calendar: Calendar = .current) -> [StudyCard] {
        let vocabularyIDs = practicedVocabularyIDs(on: now, calendar: calendar)
        let dayLogs = logs
            .filter { calendar.isDate($0.reviewedAt, inSameDayAs: now) }
            .sorted { $0.reviewedAt > $1.reviewedAt }

        return vocabularyIDs.compactMap { vocabularyID in
            let loggedCardIDs = dayLogs.filter { $0.vocabularyID == vocabularyID }.map(\.cardID)
            if let card = loggedCardIDs.lazy.compactMap({ cardID in
                self.cards.first { $0.id == cardID && !$0.isPaused && self.sense(for: $0)?.isPaused != true }
            }).first {
                return card
            }
            return cards
                .filter { $0.vocabularyID == vocabularyID && !$0.isPaused && sense(for: $0)?.isPaused != true }
                .min { currentRetrievability(for: $0, now: now) < currentRetrievability(for: $1, now: now) }
        }
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

    @discardableResult
    func startFocusedSession(vocabularyIDs: Set<UUID>, limit: Int = 10, now: Date = .now, calendar: Calendar = .current) -> [StudyCard] {
        var selected: [StudyCard] = []
        for vocabularyID in vocabularyIDs {
            let candidates = cards.filter {
                $0.vocabularyID == vocabularyID && !$0.isPaused
                    && !ReviewScheduler.isSameDay($0.lastReviewedDate, now, calendar: calendar)
                    && !pairedCardWasPresentedToday(for: $0, now: now, calendar: calendar)
            }
            if let weakest = candidates.min(by: { currentRetrievability(for: $0, now: now) < currentRetrievability(for: $1, now: now) }) {
                selected.append(weakest)
            }
        }
        selected.sort { currentRetrievability(for: $0, now: now) < currentRetrievability(for: $1, now: now) }
        selected = Array(selected.prefix(limit))
        for card in selected {
            if let index = cards.firstIndex(where: { $0.id == card.id }) { cards[index].lastPresentedDate = now }
        }
        if !selected.isEmpty { save() }
        return selected.map { card in
            var copy = card
            copy.lastPresentedDate = now
            return copy
        }
    }

    @discardableResult
    func answer(
        cardID: UUID,
        correct: Bool,
        response: String? = nil,
        responseTime: TimeInterval? = nil,
        usedHint: Bool = false,
        tooEasy: Bool = false,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Int {
        guard let index = cards.firstIndex(where: { $0.id == cardID }) else { return 0 }
        let scheduledFor = cards[index].nextReviewDate
        let outcome: ReviewOutcome = correct ? (tooEasy ? .easy : .correct) : .again
        let update = ReviewScheduler.update(
            card: cards[index],
            outcome: outcome,
            responseTime: responseTime,
            usedHint: usedHint,
            at: now,
            desiredRetention: desiredRetention,
            calendar: calendar
        )

        cards[index].successCount = correct ? cards[index].successCount + 1 : 0
        cards[index].difficulty = update.difficulty
        cards[index].stability = update.stability
        cards[index].retrievability = 1
        cards[index].lastOutcome = outcome
        cards[index].lastReviewLatency = responseTime
        cards[index].learningState = correct && update.stability >= 21 ? .mastered : .learning
        cards[index].nextReviewDate = update.nextReviewDate

        cards[index].lastReviewedDate = now
        cards[index].lastPresentedDate = now
        logs.append(ReviewLog(
            card: cards[index],
            correct: correct,
            scheduledFor: scheduledFor,
            reviewedAt: now,
            response: response,
            responseTime: responseTime,
            usedHint: usedHint,
            outcome: outcome,
            retrievabilityBeforeReview: update.retrievabilityBeforeReview,
            nextIntervalDays: update.intervalDays
        ))
        upsertStudyDay(on: now, reviewedCount: 1, newWordsIntroduced: 0, calendar: calendar)
        unlockNextSenseIfEligible(vocabularyID: cards[index].vocabularyID, now: now)
        save()
        return update.intervalDays
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
        let examples = word.examples.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let primaryExample = examples.first ?? word.example
        let mediumContent = MediumWidgetContent(
            rawValue: UserDefaults.standard.string(forKey: MediumWidgetContent.preferenceKey) ?? ""
        ) ?? .definition
        return WidgetStudySnapshot(
            vocabularyID: word.id,
            word: word.word,
            example: primaryExample,
            definition: word.conciseDefinition,
            additionalExamples: Array(examples.dropFirst()),
            mediumContent: mediumContent,
            streak: currentStreak(now: now, calendar: calendar)
        )
    }

    private func isMastered(vocabularyID: UUID) -> Bool {
        let related = cards.filter { $0.vocabularyID == vocabularyID && !$0.isPaused }
        return related.count >= 2 && related.allSatisfy { $0.learningState == .mastered }
    }

    private func appendCards(for item: VocabularyItem, now: Date = .now) {
        let start = Calendar.current.startOfDay(for: now)
        for sense in item.senses where sense.isActive && !sense.isPaused {
            appendCards(vocabularyID: item.id, senseID: sense.id, start: start)
        }
    }

    private func appendCards(vocabularyID: UUID, senseID: UUID, start: Date) {
        guard !cards.contains(where: { $0.vocabularyID == vocabularyID && $0.senseID == senseID }) else { return }
        cards.append(StudyCard(vocabularyID: vocabularyID, senseID: senseID, direction: .recognition, nextReviewDate: start))
        cards.append(StudyCard(vocabularyID: vocabularyID, senseID: senseID, direction: .recall, nextReviewDate: start))
    }

    private func makeVocabularyItem(from entry: LexiconEntry) -> VocabularyItem {
        let entries = lexicon.senses(relatedToSenseID: entry.id)
        let senseEntries = entries.isEmpty ? [entry] : entries
        let senses = senseEntries.enumerated().map { index, sense in
            let examples = Self.teachingExamples(for: sense.word, in: sense.examples)
            return LexicalSense(
                sourceID: sense.id,
                definition: sense.definition,
                examples: examples,
                usageLabel: sense.usageLabel,
                collocations: Self.deriveCollocations(word: sense.word, examples: examples),
                priority: index == 0 ? .core : (index < 3 ? .extended : .rare),
                isActive: index == 0
            )
        }
        let coreExamples = senses.first?.examples ?? Self.teachingExamples(for: entry.word, in: entry.examples)
        return VocabularyItem(
            lexiconID: entry.id,
            word: entry.word,
            partOfSpeech: entry.partOfSpeech,
            ipa: Self.formattedIPA(for: entry.word, source: entry.ipa),
            conciseDefinition: entry.definition,
            example: coreExamples.first ?? "",
            additionalExamples: Array(coreExamples.dropFirst()),
            frequencyRank: entry.frequencyRank,
            senses: senses
        )
    }

    private func stableRotationHash(_ value: String) -> UInt64 {
        value.utf8.reduce(14_695_981_039_346_656_037) { partial, byte in
            (partial ^ UInt64(byte)) &* 1_099_511_628_211
        }
    }

    private static func deriveCollocations(word: String, examples: [String]) -> [String] {
        let target = AnswerEvaluator.normalize(word)
        guard !target.isEmpty else { return [] }
        var found: [String] = []
        for example in examples {
            let tokens = AnswerEvaluator.normalize(example).split(separator: " ").map(String.init)
            for index in tokens.indices where tokens[index] == target {
                let lower = max(tokens.startIndex, index - 1)
                let upper = min(tokens.endIndex, index + 2)
                let phrase = tokens[lower..<upper].joined(separator: " ")
                if phrase.split(separator: " ").count > 1, !found.contains(phrase) { found.append(phrase) }
            }
        }
        return Array(found.prefix(3))
    }

    private func activateNextSense(vocabularyID: UUID, now: Date = .now) {
        guard let wordIndex = words.firstIndex(where: { $0.id == vocabularyID }),
              let senseIndex = words[wordIndex].senses.firstIndex(where: { !$0.isActive && !$0.isPaused })
        else { return }
        words[wordIndex].senses[senseIndex].isActive = true
        appendCards(vocabularyID: vocabularyID, senseID: words[wordIndex].senses[senseIndex].id, start: Calendar.current.startOfDay(for: now))
    }

    private func unlockNextSenseIfEligible(vocabularyID: UUID, now: Date) {
        guard let word = word(for: vocabularyID) else { return }
        let activeSenseIDs = Set(word.senses.filter { $0.isActive && !$0.isPaused }.map(\.id))
        let activeCards = cards.filter { $0.vocabularyID == vocabularyID && $0.senseID.map(activeSenseIDs.contains) == true && !$0.isPaused }
        guard !activeSenseIDs.isEmpty,
              activeCards.count == activeSenseIDs.count * CardDirection.allCases.count,
              activeCards.allSatisfy({ $0.learningState == .mastered })
        else { return }
        activateNextSense(vocabularyID: vocabularyID, now: now)
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
            studyDays[index].completed = studyDays[index].completed || practicedWordCount(on: date, calendar: calendar) >= studyDays[index].goal
        } else {
            var day = StudyDay(date: startOfDay, goal: configuredDailyGoal, reviewedCount: reviewedCount, newWordsIntroduced: newWordsIntroduced)
            day.completed = practicedWordCount(on: date, calendar: calendar) >= day.goal
            studyDays.append(day)
        }
        studyDays.sort { $0.date < $1.date }
    }

    private func isStudyDayComplete(
        on date: Date,
        currentGoal: Int?,
        fallbackGoal: Int? = nil,
        calendar: Calendar
    ) -> Bool {
        if let day = studyDays.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
            if let currentGoal {
                let uniqueWords = practicedWordCount(on: date, calendar: calendar)
                return uniqueWords > 0 ? uniqueWords >= currentGoal : day.reviewedCount >= currentGoal
            }
            return day.completed || practicedWordCount(on: date, calendar: calendar) >= day.goal || day.reviewedCount >= day.goal
        }
        let uniqueWords = practicedWordCount(on: date, calendar: calendar)
        return uniqueWords >= (currentGoal ?? fallbackGoal ?? configuredDailyGoal)
    }

    private func seed() {
        words = []
        cards = []
        logs = []
        studyDays = []
        contentReports = []
        if replenishVocabularyIfNeeded() == 0 { save() }
    }

    @discardableResult
    private func migrateSenseAwareState() -> Bool {
        var changed = false
        for wordIndex in words.indices {
            if words[wordIndex].senses.count == 1,
               words[wordIndex].senses[0].sourceID == nil,
               let lexiconID = words[wordIndex].lexiconID {
                let entries = lexicon.senses(relatedToSenseID: lexiconID)
                if !entries.isEmpty {
                    words[wordIndex].senses = entries.enumerated().map { index, entry in
                        LexicalSense(
                            sourceID: entry.id,
                            definition: entry.definition,
                            examples: entry.examples,
                            usageLabel: entry.usageLabel,
                            collocations: Self.deriveCollocations(word: entry.word, examples: entry.examples),
                            priority: index == 0 ? .core : (index < 3 ? .extended : .rare),
                            isActive: index == 0
                        )
                    }
                    changed = true
                }
            }
            guard let coreID = words[wordIndex].coreSense?.id else { continue }
            for cardIndex in cards.indices where cards[cardIndex].vocabularyID == words[wordIndex].id && cards[cardIndex].senseID == nil {
                cards[cardIndex].senseID = coreID
                changed = true
            }
            for sense in words[wordIndex].senses where sense.isActive && !sense.isPaused {
                let countBefore = cards.count
                appendCards(vocabularyID: words[wordIndex].id, senseID: sense.id, start: Calendar.current.startOfDay(for: .now))
                if cards.count != countBefore { changed = true }
            }
        }
        return changed
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
            let entry = words[index].lexiconID.flatMap { lexicon.entry(id: $0) }
                ?? lexicon.entry(matching: words[index].word, partOfSpeech: words[index].partOfSpeech)
            guard let entry else { continue }
            apply(entry, toWordAt: index)
        }
        persistedLexiconVersion = lexicon.information.version
        return true
    }

    /// Refresh stored lexical content after quality fixes without touching
    /// cards, review history, translations, or other learner-owned state.
    @discardableResult
    private func repairStoredLexiconContent() -> Bool {
        guard lexicon.isAvailable else { return false }
        var changed = false
        for index in words.indices {
            let entry: LexiconEntry?
            if words[index].examples.isEmpty {
                entry = lexicon.learningEntry(matching: words[index].word)
                    ?? words[index].lexiconID.flatMap { lexicon.entry(id: $0) }
            } else {
                entry = words[index].lexiconID.flatMap { lexicon.entry(id: $0) }
            }
            guard let entry
            else { continue }
            let before = words[index]
            apply(entry, toWordAt: index)
            changed = changed || before != words[index]
        }
        return changed
    }

    private func apply(_ entry: LexiconEntry, toWordAt index: Int) {
        let primaryExamples = Self.teachingExamples(for: entry.word, in: entry.examples)
        words[index].lexiconID = entry.id
        words[index].partOfSpeech = entry.partOfSpeech
        words[index].ipa = Self.formattedIPA(for: entry.word, source: entry.ipa)
        words[index].conciseDefinition = entry.definition
        words[index].example = primaryExamples.first ?? ""
        words[index].additionalExamples = Array(primaryExamples.dropFirst())
        let refreshed = lexicon.senses(relatedToSenseID: entry.id)
        for refreshedSense in refreshed {
            guard let senseIndex = words[index].senses.firstIndex(where: { $0.sourceID == refreshedSense.id }) else { continue }
            let examples = Self.teachingExamples(for: refreshedSense.word, in: refreshedSense.examples)
            words[index].senses[senseIndex].definition = refreshedSense.definition
            words[index].senses[senseIndex].examples = examples
            words[index].senses[senseIndex].usageLabel = refreshedSense.usageLabel
            words[index].senses[senseIndex].collocations = Self.deriveCollocations(word: refreshedSense.word, examples: examples)
        }
    }

    private static func formattedIPA(for word: String, source: String) -> String {
        let value = source.trimmingCharacters(in: CharacterSet(charactersIn: "/").union(.whitespacesAndNewlines))
        guard !value.isEmpty else { return "—" }
        return "/\(value)/"
    }

    private static func teachingExamples(for word: String, in examples: [String]) -> [String] {
        let cleaned = examples.reduce(into: [String]()) { result, example in
            let value = example.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty && !result.contains(value) { result.append(value) }
        }
        let target = AnswerEvaluator.normalize(word).split(separator: " ").map(String.init)
        guard !target.isEmpty else { return cleaned }
        let matching = cleaned.filter { example in
            let tokens = AnswerEvaluator.normalize(example).split(separator: " ").map(String.init)
            guard tokens.count >= target.count else { return false }
            return (0...(tokens.count - target.count)).contains { index in
                return Array(tokens[index..<(index + target.count)]) == target
            }
        }
        return matching.isEmpty ? cleaned : matching
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
        guard let persistenceURL else { return false }
        if let data = try? Data(contentsOf: persistenceURL),
           let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) {
            apply(snapshot)
            return true
        }

        if let backupPersistenceURL,
           let backupData = try? Data(contentsOf: backupPersistenceURL),
           let snapshot = try? JSONDecoder().decode(Snapshot.self, from: backupData) {
            apply(snapshot)
            try? backupData.write(to: persistenceURL, options: .atomic)
            return true
        }

        // Preserve the first unreadable snapshot for support/recovery instead
        // of silently erasing the only copy when a fresh store is seeded.
        if FileManager.default.fileExists(atPath: persistenceURL.path) {
            let corruptURL = persistenceURL.appendingPathExtension("corrupt")
            if !FileManager.default.fileExists(atPath: corruptURL.path) {
                try? FileManager.default.copyItem(at: persistenceURL, to: corruptURL)
            }
        }
        return false
    }

    private func apply(_ snapshot: Snapshot) {
        words = snapshot.words
        cards = snapshot.cards
        logs = snapshot.logs
        studyDays = snapshot.studyDays
        persistedLexiconVersion = snapshot.lexiconVersion
        retiredLexiconIDs = snapshot.retiredLexiconIDs
        contentReports = snapshot.contentReports
        lastModifiedAt = snapshot.modifiedAt
    }

    private func save() {
        if lexicon.isAvailable { persistedLexiconVersion = lexicon.information.version }
        lastModifiedAt = .now
        if let persistenceURL, let data = try? JSONEncoder().encode(Snapshot(words: words, cards: cards, logs: logs, studyDays: studyDays, lexiconVersion: persistedLexiconVersion, retiredLexiconIDs: retiredLexiconIDs, contentReports: contentReports, modifiedAt: lastModifiedAt)) {
            try? FileManager.default.createDirectory(at: persistenceURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            if let currentData = try? Data(contentsOf: persistenceURL),
               (try? JSONDecoder().decode(Snapshot.self, from: currentData)) != nil,
               let backupPersistenceURL {
                try? currentData.write(to: backupPersistenceURL, options: .atomic)
            }
            try? data.write(to: persistenceURL, options: .atomic)
            if iCloudSyncEnabled, !isInitializing, let iCloudPersistenceURL {
                try? FileManager.default.createDirectory(at: iCloudPersistenceURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? data.write(to: iCloudPersistenceURL, options: .atomic)
            }
        }
        publishWidgetSnapshot()
    }

    private func syncFromICloudIfNewer(force: Bool = false) {
        guard let iCloudPersistenceURL,
              let data = try? Data(contentsOf: iCloudPersistenceURL),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data),
              (force || snapshot.modifiedAt > lastModifiedAt)
        else { return }
        apply(snapshot)
        _ = migrateSenseAwareState()
        save()
    }

    private func publishWidgetSnapshot() {
        guard publishesWidgetSnapshot else { return }
        if let snapshot = widgetSnapshot() {
            SharedStudySnapshotStore.save(snapshot)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "LexiloWord")
    }

    func refreshWidgetSnapshot() {
        publishWidgetSnapshot()
    }
}
