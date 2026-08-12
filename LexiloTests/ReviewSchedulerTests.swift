import XCTest
@testable import Lexilo

final class ReviewSchedulerTests: XCTestCase {
    func testBundledKittenPackWarmsAndGeneratesWaveform() throws {
        let synthesizer = try XCTUnwrap(KittenSynthesizer())
        XCTAssertTrue(synthesizer.prewarm())
        let wave = try XCTUnwrap(synthesizer.generateWave(text: "resilient", speakerID: 1, speed: 1.0))
        XCTAssertGreaterThan(wave.count, 44)
        XCTAssertEqual(String(data: wave.prefix(4), encoding: .ascii), "RIFF")
        XCTAssertEqual(String(data: wave.dropFirst(8).prefix(4), encoding: .ascii), "WAVE")
    }

    func testKittenAudioCachePersistsWaveformBySynthesisSettings() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }

        let first = KittenAudioCache(directory: directory)
        let key = first.key(text: "Resilient", speakerID: 1, speed: 1.0)
        let otherVoiceKey = first.key(text: "Resilient", speakerID: 3, speed: 1.0)
        let wave = Data("RIFFtest-wave".utf8)
        first.store(wave, for: key)

        XCTAssertEqual(first.data(for: key), wave)
        XCTAssertNil(first.data(for: otherVoiceKey))
        XCTAssertEqual(KittenAudioCache(directory: directory).data(for: key), wave)
    }

    @MainActor
    func testPersistedSenseWithoutExampleIsRepairedToLearningSense() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let persistenceURL = directory.appending(path: "store.json")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }

        let staleID = UUID()
        let staleNounSense = VocabularyItem(
            id: staleID,
            lexiconID: "oewn:pragmatic%1:10:00::",
            word: "pragmatic",
            partOfSpeech: "noun",
            ipa: "/præɡˈmætɪk/",
            conciseDefinition: "an imperial decree that becomes part of the fundamental law of the land",
            example: "",
            frequencyRank: 1,
            introducedAt: .now
        )
        let fixture = LearningSnapshotFixture(
            words: [staleNounSense],
            cards: [],
            logs: [],
            studyDays: [],
            lexiconVersion: "2025",
            retiredLexiconIDs: []
        )
        try JSONEncoder().encode(fixture).write(to: persistenceURL, options: .atomic)

        let store = LearningStore(persistenceURL: persistenceURL)
        let repaired = try XCTUnwrap(store.words.first(where: { $0.id == staleID }))
        XCTAssertEqual(repaired.lexiconID, "oewn:pragmatic%5:00:00:practical:00")
        XCTAssertEqual(repaired.partOfSpeech, "adjective")
        XCTAssertFalse(repaired.examples.isEmpty)
        XCTAssertEqual(repaired.example, "a matter-of-fact (or pragmatic) approach to the problem")
        XCTAssertFalse(store.featuredWord()?.examples.isEmpty ?? true)
    }

    @MainActor
    func testBundledLexiconIsSearchableAndHasRotationCandidates() {
        let lexicon = LexiconStore()
        XCTAssertTrue(lexicon.isAvailable)
        XCTAssertEqual(lexicon.information.version, "2025")
        XCTAssertGreaterThan(lexicon.information.lexemeCount, 100_000)
        XCTAssertGreaterThan(lexicon.information.learningCandidateCount, 10_000)

        let results = lexicon.search("resilient")
        XCTAssertEqual(results.first?.word.lowercased(), "resilient")
        XCTAssertFalse(results.first?.definition.isEmpty ?? true)

        let candidates = lexicon.learningCandidates(throughBand: VocabularyBand.intermediate.rawValue, includePhrases: false, offset: 0, limit: 100)
        XCTAssertEqual(candidates.count, 100)
        XCTAssertTrue(candidates.allSatisfy { $0.learningBand <= VocabularyBand.intermediate.rawValue && !$0.isPhrase && !$0.examples.isEmpty })
    }

    @MainActor
    func testOfflineRotationAddsUniqueWordsAndCanRenewUnstartedQueue() {
        let priorBand = UserDefaults.standard.object(forKey: "vocabularyBand")
        let priorNonce = UserDefaults.standard.object(forKey: "rotationNonce")
        UserDefaults.standard.set(VocabularyBand.intermediate.rawValue, forKey: "vocabularyBand")
        UserDefaults.standard.set(0, forKey: "rotationNonce")
        defer {
            if let priorBand { UserDefaults.standard.set(priorBand, forKey: "vocabularyBand") }
            else { UserDefaults.standard.removeObject(forKey: "vocabularyBand") }
            if let priorNonce { UserDefaults.standard.set(priorNonce, forKey: "rotationNonce") }
            else { UserDefaults.standard.removeObject(forKey: "rotationNonce") }
        }

        let temporaryURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).appending(path: "store.json")
        let store = LearningStore(persistenceURL: temporaryURL)
        XCTAssertEqual(store.upcomingWords.count, 40)
        XCTAssertEqual(store.replenishVocabularyIfNeeded(targetUnseen: 40), 0)
        XCTAssertEqual(Set(store.upcomingWords.map { $0.word.lowercased() }).count, 40)
        let originalIDs = Set(store.upcomingWords.compactMap(\.lexiconID))

        XCTAssertEqual(store.replaceUnstartedSuggestions(), 40)
        XCTAssertTrue(originalIDs.isDisjoint(with: Set(store.upcomingWords.compactMap(\.lexiconID))))
        XCTAssertEqual(store.upcomingWords.count, 40)
    }

    func testFixedIntervals() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = Date(timeIntervalSince1970: 1_700_006_400)
        for (index, interval) in ReviewScheduler.intervals.enumerated() {
            let next = ReviewScheduler.nextDate(successCount: index + 1, from: start, calendar: calendar)
            XCTAssertEqual(calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: next).day, interval)
        }
    }

    func testIntervalCapsAt180Days() {
        let start = Date()
        let next = ReviewScheduler.nextDate(successCount: 200, from: start)
        XCTAssertEqual(Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: start), to: next).day, 180)
    }

    @MainActor
    func testFailureResetsToZeroDayAndLearning() {
        let temporaryURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).appending(path: "store.json")
        let store = LearningStore(persistenceURL: temporaryURL)
        let now = Date.now
        let selected = store.startSession(limit: 1, now: now, newWordLimit: 1)
        XCTAssertEqual(selected.count, 1)

        let cardID = try! XCTUnwrap(selected.first?.id)
        store.answer(cardID: cardID, correct: false, now: now)

        let updated = try! XCTUnwrap(store.cards.first { $0.id == cardID })
        XCTAssertEqual(updated.successCount, 0)
        XCTAssertEqual(updated.learningState, .learning)
        XCTAssertTrue(Calendar.current.isDate(updated.nextReviewDate, inSameDayAs: now))
    }

    @MainActor
    func testDailyNewWordLimitAndPairedPresentationConstraint() {
        let temporaryURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).appending(path: "store.json")
        let store = LearningStore(persistenceURL: temporaryURL)
        let session = store.startSession(limit: 100, newWordLimit: 3)

        XCTAssertEqual(session.count, 3)
        XCTAssertEqual(Set(session.map(\.vocabularyID)).count, 3)
        XCTAssertTrue(session.allSatisfy { $0.lastPresentedDate != nil })

        _ = store.startSession(limit: 100, newWordLimit: 3)
        let introducedToday = store.words.filter { item in
            guard let introducedAt = item.introducedAt else { return false }
            return Calendar.current.isDateInToday(introducedAt)
        }
        XCTAssertEqual(introducedToday.count, 3)
    }

    @MainActor
    func testCompletedStudyDayCreatesStreak() {
        let previousGoal = UserDefaults.standard.object(forKey: "dailyGoal")
        UserDefaults.standard.set(2, forKey: "dailyGoal")
        defer {
            if let previousGoal { UserDefaults.standard.set(previousGoal, forKey: "dailyGoal") }
            else { UserDefaults.standard.removeObject(forKey: "dailyGoal") }
        }

        let temporaryURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).appending(path: "store.json")
        let store = LearningStore(persistenceURL: temporaryURL)
        let now = Date.now
        let session = store.startSession(limit: 2, now: now, newWordLimit: 2)
        for card in session {
            store.answer(cardID: card.id, correct: true, now: now)
        }

        XCTAssertEqual(store.currentStreak(now: now, goal: 2), 1)
    }

    @MainActor
    func testNewStoreUsesOnlyOpenEnglishWordNetEntries() {
        let temporaryURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).appending(path: "store.json")
        let store = LearningStore(persistenceURL: temporaryURL)
        XCTAssertEqual(store.words.count, 40)
        XCTAssertTrue(store.words.allSatisfy { $0.lexiconID != nil })
        XCTAssertTrue(store.words.allSatisfy { !$0.word.isEmpty && !$0.conciseDefinition.isEmpty })
    }

    @MainActor
    func testUnavailableWordNetDoesNotCreateFallbackVocabulary() {
        let missingDatabase = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).appending(path: "missing.sqlite")
        let lexicon = LexiconStore(databaseURL: missingDatabase)
        let persistenceURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).appending(path: "store.json")
        let store = LearningStore(persistenceURL: persistenceURL, lexicon: lexicon)

        XCTAssertFalse(lexicon.isAvailable)
        XCTAssertEqual(lexicon.information.dataset, "Open English WordNet")
        XCTAssertTrue(store.words.isEmpty)
        XCTAssertTrue(store.cards.isEmpty)
    }

    @MainActor
    func testSessionNeverContainsPairedCards() {
        let temporaryURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).appending(path: "store.json")
        let store = LearningStore(persistenceURL: temporaryURL)
        let session = store.sessionCards(limit: 100)
        XCTAssertEqual(Set(session.map(\.vocabularyID)).count, session.count)
    }
}

private struct LearningSnapshotFixture: Encodable {
    let words: [VocabularyItem]
    let cards: [StudyCard]
    let logs: [ReviewLog]
    let studyDays: [StudyDay]
    let lexiconVersion: String?
    let retiredLexiconIDs: Set<String>
}
