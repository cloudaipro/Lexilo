import XCTest
@testable import Lexilo

final class ReviewSchedulerTests: XCTestCase {
    private static let preferenceKeys = [
        "dailyGoal", "newWordLimit", "vocabularyBand", "includePhrases", "rotationNonce",
        "soundEnabled", PronunciationEngineChoice.preferenceKey, "kittenVoiceID", "kittenSpeechRate", "pronunciationLocale",
        "desiredRetention", "iCloudSyncEnabled", "translationEnabled", "translationLanguage", "hasCompletedOnboarding",
        MediumWidgetContent.preferenceKey
    ]
    private var savedPreferences: [String: Any] = [:]

    @MainActor
    private static let stableLexicon: LexiconStore = {
        guard let bundledDatabase = Bundle.main.url(forResource: "lexilo-lexicon", withExtension: "sqlite") else {
            return LexiconStore(databaseURL: nil)
        }
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "LexiloTests-\(ProcessInfo.processInfo.processIdentifier)", directoryHint: .isDirectory)
        let database = directory.appending(path: "lexilo-lexicon.sqlite")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: database.path) {
            try? FileManager.default.copyItem(at: bundledDatabase, to: database)
        }
        return LexiconStore(databaseURL: database)
    }()

    @MainActor
    private func makeStore(persistenceURL: URL, reset: Bool = false) -> LearningStore {
        LearningStore(persistenceURL: persistenceURL, reset: reset, lexicon: Self.stableLexicon)
    }

    override func setUp() {
        super.setUp()
        savedPreferences = Dictionary(uniqueKeysWithValues: Self.preferenceKeys.compactMap { key in
            UserDefaults.standard.object(forKey: key).map { (key, $0) }
        })
        for key in Self.preferenceKeys { UserDefaults.standard.removeObject(forKey: key) }
    }

    override func tearDown() {
        for key in Self.preferenceKeys { UserDefaults.standard.removeObject(forKey: key) }
        for (key, value) in savedPreferences { UserDefaults.standard.set(value, forKey: key) }
        savedPreferences = [:]
        super.tearDown()
    }

    func testWidgetSnapshotKeepsCompleteExampleAlternativesAndReadsLegacyData() throws {
        let vocabularyID = UUID()
        let snapshot = WidgetStudySnapshot(
            vocabularyID: vocabularyID,
            word: "resilient",
            example: "The longer complete example remains available.",
            definition: "Able to recover quickly from difficulty.",
            additionalExamples: ["A short complete example.", "A short complete example."],
            mediumContent: .example,
            streak: 2
        )

        let encoded = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(WidgetStudySnapshot.self, from: encoded)
        XCTAssertEqual(decoded.definition, "Able to recover quickly from difficulty.")
        XCTAssertEqual(decoded.mediumContent, .example)
        XCTAssertEqual(decoded.exampleCandidates, [
            "The longer complete example remains available.",
            "A short complete example."
        ])
        XCTAssertEqual(decoded.shortestExample, "A short complete example.")

        let legacyData = """
        {"vocabularyID":"\(vocabularyID.uuidString)","word":"resilient","example":"A legacy complete example.","streak":2}
        """.data(using: .utf8)!
        let legacySnapshot = try JSONDecoder().decode(WidgetStudySnapshot.self, from: legacyData)
        XCTAssertEqual(legacySnapshot.definition, "")
        XCTAssertEqual(legacySnapshot.mediumContent, .definition)
        XCTAssertEqual(legacySnapshot.additionalExamples, [])
        XCTAssertEqual(legacySnapshot.exampleCandidates, ["A legacy complete example."])
    }

    @MainActor
    func testWidgetSnapshotCarriesDefinitionAndSelectedMediumContent() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let persistenceURL = directory.appending(path: "store.json")
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }

        let store = makeStore(persistenceURL: persistenceURL)
        let definitionSnapshot = try XCTUnwrap(store.widgetSnapshot())
        XCTAssertFalse(definitionSnapshot.definition.isEmpty)
        XCTAssertEqual(definitionSnapshot.mediumContent, .definition)

        UserDefaults.standard.set(MediumWidgetContent.example.rawValue, forKey: MediumWidgetContent.preferenceKey)
        let exampleSnapshot = try XCTUnwrap(store.widgetSnapshot())
        XCTAssertEqual(exampleSnapshot.mediumContent, .example)
        XCTAssertEqual(exampleSnapshot.example, definitionSnapshot.example)
    }

    @MainActor
    func testWidgetSnapshotUsesTodayWordsAndCyclesInOrder() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let persistenceURL = directory.appending(path: "store.json")
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }

        let now = Date.now
        let store = makeStore(persistenceURL: persistenceURL)
        let set = try XCTUnwrap(store.ensureDailyStudySet(now: now))
        let snapshot = try XCTUnwrap(store.widgetSnapshot(now: now))

        XCTAssertEqual(snapshot.dailyWordIDs, set.vocabularyIDs)
        XCTAssertEqual(snapshot.dailyWords.count, set.vocabularyIDs.count)

        let second = snapshot.showingDailyWord(at: 1)
        XCTAssertEqual(second.vocabularyID, snapshot.dailyWords[1].vocabularyID)
        XCTAssertEqual(second.dailyRotationIndex, 1)

        let wrapped = snapshot.showingDailyWord(at: snapshot.dailyWords.count)
        XCTAssertEqual(wrapped.vocabularyID, snapshot.dailyWords[0].vocabularyID)
        XCTAssertEqual(wrapped.dailyRotationIndex, 0)
    }

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
        let differentlyCasedKey = first.key(text: "resilient", speakerID: 1, speed: 1.0)
        let otherVoiceKey = first.key(text: "Resilient", speakerID: 3, speed: 1.0)
        let wave = Data([
            82, 73, 70, 70, 36, 0, 0, 0, 87, 65, 86, 69,
            102, 109, 116, 32, 16, 0, 0, 0, 1, 0, 1, 0,
            128, 62, 0, 0, 0, 125, 0, 0, 2, 0, 16, 0,
            100, 97, 116, 97, 0, 0, 0, 0
        ])
        first.store(wave, for: key)

        XCTAssertEqual(first.data(for: key), wave)
        XCTAssertNotEqual(key, differentlyCasedKey)
        XCTAssertNil(first.data(for: otherVoiceKey))
        XCTAssertEqual(KittenAudioCache(directory: directory).data(for: key), wave)

        let corruptKey = first.key(text: "corrupt", speakerID: 1, speed: 1.0)
        let corruptURL = directory.appending(path: "\(corruptKey).wav")
        try Data("not a wave".utf8).write(to: corruptURL)
        XCTAssertNil(first.data(for: corruptKey))
        XCTAssertFalse(FileManager.default.fileExists(atPath: corruptURL.path))
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
            lexiconID: "legacy:dictionary:noun",
            word: "dictionary",
            partOfSpeech: "noun",
            ipa: "",
            conciseDefinition: "legacy definition",
            example: "",
            frequencyRank: 1,
            introducedAt: .now
        )
        let fixture = LearningSnapshotFixture(
            words: [staleNounSense],
            cards: [],
            logs: [],
            studyDays: [],
            lexiconVersion: "legacy",
            retiredLexiconIDs: []
        )
        try JSONEncoder().encode(fixture).write(to: persistenceURL, options: .atomic)

        let store = makeStore(persistenceURL: persistenceURL)
        let repaired = try XCTUnwrap(store.words.first(where: { $0.id == staleID }))
        XCTAssertTrue(repaired.lexiconID?.hasPrefix("simple:") == true)
        XCTAssertEqual(repaired.partOfSpeech, "noun")
        XCTAssertFalse(repaired.examples.isEmpty)
        XCTAssertTrue(repaired.example.localizedCaseInsensitiveContains("dictionary"))
        XCTAssertFalse(store.featuredWord()?.examples.isEmpty ?? true)
    }

    @MainActor
    func testCorruptPrimarySnapshotRecoversFromBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let persistenceURL = directory.appending(path: "store.json")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let historicalDay = StudyDay(date: Date(timeIntervalSince1970: 1_700_006_400), goal: 10, reviewedCount: 7)
        let fixture = LearningSnapshotFixture(
            words: [], cards: [], logs: [], studyDays: [historicalDay],
            lexiconVersion: "2025", retiredLexiconIDs: []
        )
        let backupData = try JSONEncoder().encode(fixture)
        try backupData.write(to: persistenceURL.appendingPathExtension("backup"), options: .atomic)
        try Data("truncated-json".utf8).write(to: persistenceURL, options: .atomic)

        let store = makeStore(persistenceURL: persistenceURL)
        XCTAssertEqual(store.studyDays, [historicalDay])
        XCTAssertNoThrow(try JSONDecoder().decode(LearningSnapshotFixture.self, from: Data(contentsOf: persistenceURL)))
    }

    @MainActor
    func testCorruptSnapshotWithoutBackupIsPreserved() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let persistenceURL = directory.appending(path: "store.json")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let corruptData = Data("truncated-json".utf8)
        try corruptData.write(to: persistenceURL, options: .atomic)

        _ = makeStore(persistenceURL: persistenceURL)
        XCTAssertEqual(try Data(contentsOf: persistenceURL.appendingPathExtension("corrupt")), corruptData)
    }

    @MainActor
    func testBundledLexiconIsSearchableAndHasRotationCandidates() {
        let lexicon = Self.stableLexicon
        XCTAssertTrue(lexicon.isAvailable)
        XCTAssertEqual(lexicon.information.dataset, "Simple English Wiktionary")
        XCTAssertEqual(lexicon.information.version, "simplewiktionary-20260801")
        XCTAssertGreaterThan(lexicon.information.lexemeCount, 5_000)
        XCTAssertGreaterThan(lexicon.information.learningCandidateCount, 5_000)

        let results = lexicon.search("dictionary")
        XCTAssertEqual(results.first?.word.lowercased(), "dictionary")
        XCTAssertFalse(results.first?.definition.isEmpty ?? true)

        let candidates = lexicon.learningCandidates(inBand: VocabularyBand.intermediate.rawValue, includePhrases: false, offset: 0, limit: 100)
        XCTAssertEqual(candidates.count, 100)
        XCTAssertTrue(candidates.allSatisfy { $0.learningBand == VocabularyBand.intermediate.rawValue && !$0.isPhrase && !$0.examples.isEmpty })
    }

    @MainActor
    func testLearningContentUsesWordBearingExamplesAndPronunciationFallbacks() throws {
        let persistenceURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString)
            .appending(path: "store.json")
        let store = makeStore(persistenceURL: persistenceURL)
        addTeardownBlock { try? FileManager.default.removeItem(at: persistenceURL.deletingLastPathComponent()) }

        let recreationEntry = try XCTUnwrap(Self.stableLexicon.learningEntry(matching: "recreation"))
        let recreation = store.addToLearning(recreationEntry)
        XCTAssertFalse(recreation.examples.isEmpty)
        XCTAssertTrue(recreation.examples.allSatisfy { $0.localizedCaseInsensitiveContains("recreation") })
        XCTAssertEqual(recreation.ipa, "/rɛkriˈeɪʃən/")

        let kittenEntry = try XCTUnwrap(Self.stableLexicon.learningEntry(matching: "kitten"))
        let kitten = store.addToLearning(kittenEntry)
        XCTAssertEqual(kitten.ipa, "/kˈɪtən/")
        XCTAssertFalse(kitten.examples.isEmpty)
    }

    @MainActor
    func testCommonLearningExamplesAreCompleteUsageSentences() throws {
        for word in ["lean", "recreation", "harbor"] {
            let entry = try XCTUnwrap(Self.stableLexicon.learningEntry(matching: word))
            XCTAssertFalse(entry.examples.isEmpty, "Expected a usage example for \(word)")
            XCTAssertTrue(entry.examples.allSatisfy { $0.range(of: #"[.!?…][\"’'”»)]*$"#, options: .regularExpression) != nil }, "Gloss-like fragment leaked for \(word): \(entry.examples)")
        }
    }

    @MainActor
    func testAdvancedRotationContainsOnlyAdvancedBandWords() {
        let previousBand = UserDefaults.standard.object(forKey: "vocabularyBand")
        let previousNonce = UserDefaults.standard.object(forKey: "rotationNonce")
        UserDefaults.standard.set(VocabularyBand.advanced.rawValue, forKey: "vocabularyBand")
        UserDefaults.standard.set(0, forKey: "rotationNonce")
        defer {
            if let previousBand { UserDefaults.standard.set(previousBand, forKey: "vocabularyBand") }
            else { UserDefaults.standard.removeObject(forKey: "vocabularyBand") }
            if let previousNonce { UserDefaults.standard.set(previousNonce, forKey: "rotationNonce") }
            else { UserDefaults.standard.removeObject(forKey: "rotationNonce") }
        }

        let persistenceURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).appending(path: "store.json")
        let store = makeStore(persistenceURL: persistenceURL)
        XCTAssertEqual(store.upcomingWords.count, 40)
        XCTAssertTrue(store.upcomingWords.allSatisfy { word in
            guard let lexiconID = word.lexiconID, let entry = store.lexicon.entry(id: lexiconID) else { return false }
            return entry.learningBand == VocabularyBand.advanced.rawValue
        })
        XCTAssertTrue(Set(store.upcomingWords.map { $0.word.lowercased() }).isDisjoint(with: ["on", "like", "up", "out", "time"]))
    }

    @MainActor
    func testReplenishedCardsUseSuppliedSchedulingDate() throws {
        let previousBand = UserDefaults.standard.object(forKey: "vocabularyBand")
        UserDefaults.standard.set(VocabularyBand.intermediate.rawValue, forKey: "vocabularyBand")
        defer {
            if let previousBand { UserDefaults.standard.set(previousBand, forKey: "vocabularyBand") }
            else { UserDefaults.standard.removeObject(forKey: "vocabularyBand") }
        }

        let persistenceURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).appending(path: "store.json")
        let store = makeStore(persistenceURL: persistenceURL)
        let existingIDs = Set(store.words.map(\.id))
        let suppliedDate = Date(timeIntervalSince1970: 1_700_006_400)
        XCTAssertEqual(store.replenishVocabularyIfNeeded(targetUnseen: 41, now: suppliedDate), 1)

        let addedWord = try XCTUnwrap(store.words.first(where: { !existingIDs.contains($0.id) }))
        let addedCards = store.cards.filter { $0.vocabularyID == addedWord.id }
        XCTAssertEqual(addedCards.count, 2)
        XCTAssertTrue(addedCards.allSatisfy {
            Calendar.current.isDate($0.nextReviewDate, inSameDayAs: suppliedDate)
        })
    }

    @MainActor
    func testUITestResetClearsSelectionAndSpeechPreferences() {
        let keys: [String: Any] = [
            "vocabularyBand": VocabularyBand.advanced.rawValue,
            "includePhrases": true,
            "rotationNonce": 9,
            "soundEnabled": false,
            "kittenVoiceID": 7,
            "kittenSpeechRate": 1.2,
            "pronunciationLocale": "en-GB"
        ]
        for (key, value) in keys { UserDefaults.standard.set(value, forKey: key) }

        let persistenceURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).appending(path: "store.json")
        _ = makeStore(persistenceURL: persistenceURL, reset: true)

        XCTAssertTrue(keys.keys.allSatisfy { UserDefaults.standard.object(forKey: $0) == nil })
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
        let store = makeStore(persistenceURL: temporaryURL)
        XCTAssertEqual(store.upcomingWords.count, 40)
        XCTAssertEqual(store.replenishVocabularyIfNeeded(targetUnseen: 40), 0)
        XCTAssertEqual(Set(store.upcomingWords.map { $0.word.lowercased() }).count, 40)
        let originalIDs = Set(store.upcomingWords.compactMap(\.lexiconID))

        XCTAssertEqual(store.replaceUnstartedSuggestions(), 40)
        XCTAssertTrue(originalIDs.isDisjoint(with: Set(store.upcomingWords.compactMap(\.lexiconID))))
        XCTAssertEqual(store.upcomingWords.count, 40)
    }

    func testAdaptiveSchedulerUsesMemoryStateAndSignals() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = Date(timeIntervalSince1970: 1_700_006_400)
        var card = StudyCard(vocabularyID: UUID(), direction: .recall, nextReviewDate: start)
        card.lastReviewedDate = calendar.date(byAdding: .day, value: -3, to: start)
        card.stability = 4

        let fast = ReviewScheduler.update(card: card, outcome: .correct, responseTime: 2, usedHint: false, at: start, calendar: calendar)
        let hinted = ReviewScheduler.update(card: card, outcome: .correct, responseTime: 20, usedHint: true, at: start, calendar: calendar)
        let failed = ReviewScheduler.update(card: card, outcome: .again, responseTime: 20, usedHint: false, at: start, calendar: calendar)

        XCTAssertGreaterThan(fast.stability, hinted.stability)
        XCTAssertGreaterThan(fast.intervalDays, failed.intervalDays)
        XCTAssertEqual(failed.intervalDays, 1)
        XCTAssertEqual(fast.retrievabilityBeforeReview, ReviewScheduler.retrievability(for: card, at: start), accuracy: 0.0001)
    }

    @MainActor
    func testWordDifficultyIsAvailablePerDirection() throws {
        let temporaryURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).appending(path: "store.json")
        let store = makeStore(persistenceURL: temporaryURL)
        let word = try XCTUnwrap(store.words.first)
        let recognition = try XCTUnwrap(store.cards.first { $0.vocabularyID == word.id && $0.direction == .recognition })

        XCTAssertEqual(try XCTUnwrap(store.averageDifficulty(vocabularyID: word.id, direction: .recognition)), 5, accuracy: 0.0001)
        XCTAssertFalse(store.hasReviewedCard(vocabularyID: word.id, direction: .recognition))
        XCTAssertEqual(store.difficultyLabel(for: 5), "Moderate")

        store.answer(cardID: recognition.id, correct: false, responseTime: 2, now: .now)

        XCTAssertEqual(try XCTUnwrap(store.averageDifficulty(vocabularyID: word.id, direction: .recognition)), 5.75, accuracy: 0.0001)
        XCTAssertTrue(store.hasReviewedCard(vocabularyID: word.id, direction: .recognition))
        XCTAssertNotNil(store.card(vocabularyID: word.id, senseID: recognition.senseID!, direction: .recognition))
    }

    func testAdaptiveIntervalCapsAtTenYears() {
        let start = Date.now
        var card = StudyCard(vocabularyID: UUID(), direction: .recognition, nextReviewDate: start)
        card.lastReviewedDate = start.addingTimeInterval(-86_400)
        card.stability = 20_000
        let update = ReviewScheduler.update(card: card, outcome: .easy, responseTime: 1, usedHint: false, at: start)
        XCTAssertEqual(update.intervalDays, ReviewScheduler.maximumInterval)
    }

    func testGreetingChangesWithLocalTime() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = Date(timeIntervalSince1970: 1_700_006_400)

        XCTAssertEqual(TodayGreeting.text(for: calendar.date(byAdding: .hour, value: 8, to: day)!, calendar: calendar), "Good morning")
        XCTAssertEqual(TodayGreeting.text(for: calendar.date(byAdding: .hour, value: 14, to: day)!, calendar: calendar), "Good afternoon")
        XCTAssertEqual(TodayGreeting.text(for: calendar.date(byAdding: .hour, value: 20, to: day)!, calendar: calendar), "Good evening")
    }

    @MainActor
    func testFailureSchedulesTomorrowAndRecordsMemorySignals() {
        let temporaryURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).appending(path: "store.json")
        let store = makeStore(persistenceURL: temporaryURL)
        let now = Date.now
        let selected = store.startSession(limit: 1, now: now, newWordLimit: 1)
        XCTAssertEqual(selected.count, 1)

        let cardID = try! XCTUnwrap(selected.first?.id)
        store.answer(cardID: cardID, correct: false, response: "wrong", responseTime: 4.2, usedHint: true, now: now)

        let updated = try! XCTUnwrap(store.cards.first { $0.id == cardID })
        XCTAssertEqual(updated.successCount, 0)
        XCTAssertEqual(updated.learningState, .learning)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now)!
        XCTAssertTrue(Calendar.current.isDate(updated.nextReviewDate, inSameDayAs: tomorrow))
        XCTAssertEqual(updated.lastOutcome, .again)
        XCTAssertEqual(updated.lastReviewLatency, 4.2)
        XCTAssertEqual(store.logs.last?.response, "wrong")
        XCTAssertEqual(store.logs.last?.usedHint, true)
    }

    @MainActor
    func testDailyNewWordLimitAndPairedPresentationConstraint() {
        let temporaryURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).appending(path: "store.json")
        let store = makeStore(persistenceURL: temporaryURL)
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
    func testDailyStudySetPersistsPositionAndCompletesLearningPass() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let persistenceURL = directory.appending(path: "store.json")
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }

        let now = Date.now
        let store = makeStore(persistenceURL: persistenceURL)
        let set = try XCTUnwrap(store.ensureDailyStudySet(now: now))
        XCTAssertEqual(set.vocabularyIDs.count, 5)
        XCTAssertEqual(set.currentIndex, 0)
        XCTAssertFalse(set.learningCompleted)

        store.updateDailyStudyProgress(index: 2, now: now)
        XCTAssertEqual(store.dailyStudySet?.currentIndex, 2)

        let reloaded = makeStore(persistenceURL: persistenceURL)
        XCTAssertEqual(reloaded.dailyStudySet?.currentIndex, 2)
        XCTAssertFalse(reloaded.dailyLearningCompleted(now: now))

        reloaded.completeDailyLearning(now: now)
        XCTAssertTrue(reloaded.dailyLearningCompleted(now: now))
        XCTAssertEqual(reloaded.wordsIntroduced(on: now).count, 5)
        XCTAssertTrue(reloaded.wordsIntroduced(on: now).allSatisfy { $0.introducedAt != nil })
    }

    @MainActor
    func testLearnMoreExpandsDailySetByOneBatchAndStartsAtFirstNewWord() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let persistenceURL = directory.appending(path: "store.json")
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }

        let now = Date.now
        let store = makeStore(persistenceURL: persistenceURL)
        let firstSet = try XCTUnwrap(store.ensureDailyStudySet(now: now))
        store.completeDailyLearning(now: now)

        let firstPractice = store.startFocusedSession(
            vocabularyIDs: Set(firstSet.vocabularyIDs),
            limit: firstSet.vocabularyIDs.count,
            now: now
        )
        XCTAssertEqual(firstPractice.count, 5)
        for card in firstPractice {
            store.answer(cardID: card.id, correct: true, responseTime: 2, now: now)
        }
        XCTAssertTrue(store.dailyPracticeCompleted(now: now))
        XCTAssertTrue(store.canLearnMoreDailyWords(now: now))

        let added = store.addMoreDailyWords(now: now)
        XCTAssertEqual(added.count, 5)
        XCTAssertEqual(store.dailyStudySet?.vocabularyIDs.count, 10)
        XCTAssertEqual(store.dailyStudySet?.currentIndex, 5)
        XCTAssertFalse(store.dailyStudySet?.learningCompleted ?? true)
        XCTAssertEqual(store.wordsIntroduced(on: now).count, 5)
        XCTAssertEqual(store.wordsForCollection(now: now).count, 10)
        XCTAssertTrue(Set(firstSet.vocabularyIDs).isDisjoint(with: Set(added.map(\.id))))
    }

    @MainActor
    func testLearnMoreExpandsImmediatelyAfterTheFirstLearningPass() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let persistenceURL = directory.appending(path: "store.json")
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }

        let now = Date.now
        let store = makeStore(persistenceURL: persistenceURL)
        let firstSet = try XCTUnwrap(store.ensureDailyStudySet(now: now))
        store.completeDailyLearning(now: now)

        XCTAssertFalse(store.dailyPracticeCompleted(now: now))
        let added = store.addMoreDailyWords(now: now)

        XCTAssertEqual(added.count, 5)
        XCTAssertEqual(store.dailyStudySet?.vocabularyIDs.count, 10)
        XCTAssertEqual(store.dailyStudySet?.currentIndex, firstSet.vocabularyIDs.count)
        XCTAssertFalse(store.dailyStudySet?.learningCompleted ?? true)
        XCTAssertTrue(Set(firstSet.vocabularyIDs).isDisjoint(with: Set(added.map(\.id))))
    }

    @MainActor
    func testStudyHistorySeparatesFirstLearningFromPracticeReviews() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let persistenceURL = directory.appending(path: "store.json")
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }

        let now = Date.now
        let store = makeStore(persistenceURL: persistenceURL)
        let set = try XCTUnwrap(store.ensureDailyStudySet(now: now))
        store.completeDailyLearning(now: now)

        let firstWordID = try XCTUnwrap(set.vocabularyIDs.first)
        let focused = store.startFocusedSession(vocabularyIDs: [firstWordID], now: now)
        let card = try XCTUnwrap(focused.first)
        store.answer(cardID: card.id, correct: true, responseTime: 2, now: now)

        XCTAssertEqual(store.wordsIntroduced(on: now).count, set.vocabularyIDs.count)
        XCTAssertEqual(store.wordsReviewed(on: now).map(\.id), [firstWordID])
        XCTAssertEqual(Set(store.wordsStudied(on: now).map(\.id)), Set(set.vocabularyIDs))
        XCTAssertTrue(store.hasStudyActivity(on: now))
        XCTAssertEqual(store.learningState(for: firstWordID), .learning)
        XCTAssertNotNil(store.lastReviewedDate(for: firstWordID))
    }

    @MainActor
    func testCompletedDailyQuizClearsDueAndRoutesScheduledWordsToReviewQueue() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let persistenceURL = directory.appending(path: "store.json")
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }

        let calendar = Calendar.current
        let firstDay = Date.now
        let secondDay = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: firstDay))
        let thirdDay = try XCTUnwrap(calendar.date(byAdding: .day, value: 2, to: firstDay))
        let store = makeStore(persistenceURL: persistenceURL)
        let firstSet = try XCTUnwrap(store.ensureDailyStudySet(now: firstDay, calendar: calendar))
        store.completeDailyLearning(now: firstDay, calendar: calendar)

        let quiz = store.startFocusedSession(
            vocabularyIDs: Set(firstSet.vocabularyIDs),
            limit: firstSet.vocabularyIDs.count,
            now: firstDay,
            calendar: calendar
        )
        XCTAssertEqual(quiz.count, firstSet.vocabularyIDs.count)
        let firstDirectionByWord = Dictionary(uniqueKeysWithValues: quiz.map { ($0.vocabularyID, $0.direction) })

        for card in quiz {
            store.answer(cardID: card.id, correct: true, responseTime: 2, now: firstDay, calendar: calendar)
        }

        XCTAssertTrue(store.dailyPracticeCompleted(now: firstDay, calendar: calendar))
        XCTAssertTrue(firstSet.vocabularyIDs.allSatisfy {
            !store.isDue(vocabularyID: $0, now: firstDay, calendar: calendar)
        })
        for vocabularyID in firstSet.vocabularyIDs {
            let relatedCards = store.cards.filter { $0.vocabularyID == vocabularyID && !$0.isPaused }
            XCTAssertFalse(relatedCards.isEmpty)
            XCTAssertTrue(relatedCards.allSatisfy {
                calendar.isDate($0.nextReviewDate, inSameDayAs: thirdDay)
            })
        }

        let secondSet = try XCTUnwrap(store.ensureDailyStudySet(now: secondDay, calendar: calendar))
        XCTAssertTrue(Set(firstSet.vocabularyIDs).isDisjoint(with: Set(secondSet.vocabularyIDs)))

        let thirdSet = try XCTUnwrap(store.ensureDailyStudySet(now: thirdDay, calendar: calendar))
        XCTAssertTrue(Set(firstSet.vocabularyIDs).isDisjoint(with: Set(thirdSet.vocabularyIDs)))
        let dueReviews = store.startDueReviewSession(
            limit: firstSet.vocabularyIDs.count,
            now: thirdDay,
            calendar: calendar
        )
        XCTAssertEqual(Set(dueReviews.map(\.vocabularyID)), Set(firstSet.vocabularyIDs))
        XCTAssertTrue(dueReviews.allSatisfy { card in
            card.lastReviewedDate == nil && firstDirectionByWord[card.vocabularyID] != card.direction
        })
    }

    @MainActor
    func testOverdueWordsStayOutOfNextDaysNewWordsAndEnterReviewQueue() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let persistenceURL = directory.appending(path: "store.json")
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }

        let calendar = Calendar.current
        let firstDay = Date.now
        let secondDay = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: firstDay))
        let store = makeStore(persistenceURL: persistenceURL)
        let firstSet = try XCTUnwrap(store.ensureDailyStudySet(now: firstDay, calendar: calendar))
        store.completeDailyLearning(now: firstDay, calendar: calendar)
        let quiz = store.startFocusedSession(
            vocabularyIDs: Set(firstSet.vocabularyIDs),
            limit: firstSet.vocabularyIDs.count,
            now: firstDay,
            calendar: calendar
        )
        let forgottenCard = try XCTUnwrap(quiz.first)
        store.answer(cardID: forgottenCard.id, correct: false, now: firstDay, calendar: calendar)
        for card in quiz.dropFirst() {
            store.answer(cardID: card.id, correct: true, now: firstDay, calendar: calendar)
        }

        let secondSet = try XCTUnwrap(store.ensureDailyStudySet(now: secondDay, calendar: calendar))
        XCTAssertTrue(Set(firstSet.vocabularyIDs).isDisjoint(with: Set(secondSet.vocabularyIDs)))
        XCTAssertTrue(secondSet.vocabularyIDs.allSatisfy { store.word(for: $0)?.introducedAt == nil })
        XCTAssertTrue(secondSet.vocabularyIDs.allSatisfy {
            !store.isDue(vocabularyID: $0, now: secondDay, calendar: calendar)
        })
        XCTAssertTrue(store.isDue(vocabularyID: forgottenCard.vocabularyID, now: secondDay, calendar: calendar))

        let dueReviews = store.dueReviewCards(now: secondDay, calendar: calendar)
        XCTAssertEqual(dueReviews.map(\.vocabularyID), [forgottenCard.vocabularyID])
        XCTAssertTrue(dueReviews.allSatisfy { card in
            guard let introducedAt = store.word(for: card.vocabularyID)?.introducedAt else { return false }
            return !calendar.isDate(introducedAt, inSameDayAs: secondDay)
        })
    }

    @MainActor
    func testDailyQuizIsCompleteOnlyAfterEveryLatestOutcomeSucceeds() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let persistenceURL = directory.appending(path: "store.json")
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }

        let now = Date.now
        let store = makeStore(persistenceURL: persistenceURL)
        _ = try XCTUnwrap(store.ensureDailyStudySet(now: now))
        store.completeDailyLearning(now: now)
        XCTAssertEqual(store.addMoreDailyWords(count: 1, now: now).count, 1)
        let expandedSet = try XCTUnwrap(store.dailyStudySet)
        XCTAssertFalse(expandedSet.learningCompleted)
        let quiz = store.startFocusedSession(
            vocabularyIDs: Set(expandedSet.vocabularyIDs),
            limit: expandedSet.vocabularyIDs.count,
            now: now
        )
        let failedCard = try XCTUnwrap(quiz.first)

        store.answer(cardID: failedCard.id, correct: false, responseTime: 2, now: now)
        for card in quiz.dropFirst() {
            store.answer(cardID: card.id, correct: true, responseTime: 2, now: now)
        }
        XCTAssertFalse(store.dailyPracticeCompleted(now: now))

        store.answer(cardID: failedCard.id, correct: true, responseTime: 2, now: now)
        XCTAssertTrue(store.dailyPracticeCompleted(now: now))
    }

    @MainActor
    func testLegacyPairedCardScheduleIsRepairedWhenLoaded() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let persistenceURL = directory.appending(path: "store.json")
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }

        let calendar = Calendar.current
        let firstDay = Date.now
        let thirdDay = try XCTUnwrap(calendar.date(byAdding: .day, value: 2, to: firstDay))
        let store = makeStore(persistenceURL: persistenceURL)
        let set = try XCTUnwrap(store.ensureDailyStudySet(now: firstDay, calendar: calendar))
        store.completeDailyLearning(now: firstDay, calendar: calendar)
        let vocabularyID = try XCTUnwrap(set.vocabularyIDs.first)
        let card = try XCTUnwrap(store.startFocusedSession(
            vocabularyIDs: [vocabularyID],
            limit: 1,
            now: firstDay,
            calendar: calendar
        ).first)
        store.answer(cardID: card.id, correct: true, responseTime: 2, now: firstDay, calendar: calendar)

        let exported = try store.exportData()
        var snapshot = try XCTUnwrap(JSONSerialization.jsonObject(with: exported) as? [String: Any])
        var cards = try XCTUnwrap(snapshot["cards"] as? [[String: Any]])
        let legacyDueDate = calendar.startOfDay(for: firstDay).timeIntervalSinceReferenceDate
        for index in cards.indices where cards[index]["vocabularyID"] as? String == vocabularyID.uuidString {
            cards[index]["nextReviewDate"] = legacyDueDate
        }
        snapshot["cards"] = cards
        let legacyData = try JSONSerialization.data(withJSONObject: snapshot)
        try legacyData.write(to: persistenceURL, options: .atomic)

        let reloaded = makeStore(persistenceURL: persistenceURL)
        let repairedCards = reloaded.cards.filter { $0.vocabularyID == vocabularyID && !$0.isPaused }
        XCTAssertFalse(repairedCards.isEmpty)
        XCTAssertTrue(repairedCards.allSatisfy {
            calendar.isDate($0.nextReviewDate, inSameDayAs: thirdDay)
        })
        XCTAssertFalse(reloaded.isDue(vocabularyID: vocabularyID, now: firstDay, calendar: calendar))
    }

    @MainActor
    func testDailyStudySetReconstructsAnAlreadyPractisedLegacyDay() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let persistenceURL = directory.appending(path: "store.json")
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }

        let now = Date.now
        let store = makeStore(persistenceURL: persistenceURL)
        let legacyRound = store.startRound(wordCount: 2, now: now)
        for card in legacyRound {
            store.answer(cardID: card.id, correct: true, now: now)
        }
        XCTAssertNil(store.dailyStudySet)

        let reconstructed = try XCTUnwrap(store.ensureDailyStudySet(now: now))
        XCTAssertEqual(reconstructed.vocabularyIDs, legacyRound.map(\.vocabularyID))
        XCTAssertTrue(reconstructed.learningCompleted)
        XCTAssertTrue(store.dailyPracticeCompleted(now: now))
    }

    @MainActor
    func testNextRoundGrowsTodaySetAndPracticeAgainReplaysAllWordsWithoutChangingSchedule() {
        let temporaryURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).appending(path: "store.json")
        let store = makeStore(persistenceURL: temporaryURL)
        let now = Date.now
        let firstRound = store.startRound(wordCount: 5, now: now)
        XCTAssertEqual(firstRound.count, 5)

        if let retriedCard = firstRound.first {
            store.answer(cardID: retriedCard.id, correct: false, responseTime: 2, now: now)
            store.answer(cardID: retriedCard.id, correct: true, responseTime: 2, now: now)
        }
        for card in firstRound.dropFirst() {
            store.answer(cardID: card.id, correct: true, responseTime: 2, now: now)
        }
        XCTAssertEqual(store.practicedWordCount(on: now), 5, "A retry must not count as another word")

        let secondRound = store.startRound(wordCount: 5, now: now)
        XCTAssertEqual(secondRound.count, 5)
        XCTAssertTrue(Set(firstRound.map(\.vocabularyID)).isDisjoint(with: Set(secondRound.map(\.vocabularyID))))
        for card in secondRound {
            store.answer(cardID: card.id, correct: true, responseTime: 2, now: now)
        }
        XCTAssertEqual(store.practicedWordCount(on: now), 10)

        let thirdRound = store.startRound(wordCount: 5, now: now)
        XCTAssertEqual(thirdRound.count, 5)
        XCTAssertTrue(Set((firstRound + secondRound).map(\.vocabularyID)).isDisjoint(with: Set(thirdRound.map(\.vocabularyID))))
        for card in thirdRound {
            store.answer(cardID: card.id, correct: true, responseTime: 2, now: now)
        }
        XCTAssertEqual(store.practicedWordCount(on: now), 15)

        let cardsBeforeSelection = store.cards
        let logsBeforeSelection = store.logs
        let repeated = store.practiceAgainCards(now: now)

        XCTAssertEqual(repeated.count, 15)
        XCTAssertEqual(Set(repeated.map(\.vocabularyID)), Set((firstRound + secondRound + thirdRound).map(\.vocabularyID)))
        XCTAssertEqual(Set(repeated.map(\.vocabularyID)).count, repeated.count)
        XCTAssertEqual(store.cards, cardsBeforeSelection)
        XCTAssertEqual(store.logs, logsBeforeSelection)
    }

    @MainActor
    func testCompletedStudyDayCreatesStreak() {
        let previousGoal = UserDefaults.standard.object(forKey: "newWordLimit")
        UserDefaults.standard.set(2, forKey: "newWordLimit")
        defer {
            if let previousGoal { UserDefaults.standard.set(previousGoal, forKey: "newWordLimit") }
            else { UserDefaults.standard.removeObject(forKey: "newWordLimit") }
        }

        let temporaryURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).appending(path: "store.json")
        let store = makeStore(persistenceURL: temporaryURL)
        let now = Date.now
        let session = store.startRound(wordCount: 2, now: now)
        XCTAssertTrue(store.lexicon.isAvailable)
        XCTAssertEqual(session.count, 2)
        for card in session {
            store.answer(cardID: card.id, correct: true, now: now)
        }

        XCTAssertEqual(store.completedReviews(on: now), 2)
        XCTAssertEqual(store.currentStreak(now: now, goal: 2), 1)
    }

    @MainActor
    func testLoweringGoalDoesNotRetroactivelyCompleteYesterday() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let persistenceURL = directory.appending(path: "store.json")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let today = Date(timeIntervalSince1970: 1_700_006_400)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let incompleteDay = StudyDay(date: yesterday, goal: 10, reviewedCount: 5)
        let fixture = LearningSnapshotFixture(
            words: [], cards: [], logs: [], studyDays: [incompleteDay],
            lexiconVersion: "2025", retiredLexiconIDs: []
        )
        try JSONEncoder().encode(fixture).write(to: persistenceURL, options: .atomic)

        let store = makeStore(persistenceURL: persistenceURL)
        XCTAssertEqual(store.currentStreak(now: today, goal: 5, calendar: calendar), 0)
    }

    @MainActor
    func testRaisingGoalReevaluatesCurrentDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let persistenceURL = directory.appending(path: "store.json")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let today = Date(timeIntervalSince1970: 1_700_006_400)
        let completedAtOldGoal = StudyDay(date: today, goal: 5, reviewedCount: 5)
        let fixture = LearningSnapshotFixture(
            words: [], cards: [], logs: [], studyDays: [completedAtOldGoal],
            lexiconVersion: "2025", retiredLexiconIDs: []
        )
        try JSONEncoder().encode(fixture).write(to: persistenceURL, options: .atomic)

        let store = makeStore(persistenceURL: persistenceURL)
        XCTAssertEqual(store.currentStreak(now: today, goal: 10, calendar: calendar), 0)
    }

    @MainActor
    func testNewStoreUsesOnlySimpleWiktionaryEntries() {
        let temporaryURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).appending(path: "store.json")
        let store = makeStore(persistenceURL: temporaryURL)
        XCTAssertEqual(store.words.count, 40)
        XCTAssertTrue(store.words.allSatisfy { $0.lexiconID != nil })
        XCTAssertTrue(store.words.allSatisfy { $0.lexiconID?.hasPrefix("simple:") == true })
        XCTAssertTrue(store.words.allSatisfy { !$0.word.isEmpty && !$0.conciseDefinition.isEmpty })
    }

    @MainActor
    func testUnavailableSimpleWiktionaryDatabaseDoesNotCreateFallbackVocabulary() {
        let missingDatabase = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).appending(path: "missing.sqlite")
        let lexicon = LexiconStore(databaseURL: missingDatabase)
        let persistenceURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).appending(path: "store.json")
        let store = LearningStore(persistenceURL: persistenceURL, lexicon: lexicon)

        XCTAssertFalse(lexicon.isAvailable)
        XCTAssertEqual(lexicon.information.dataset, "Simple English Wiktionary")
        XCTAssertTrue(store.words.isEmpty)
        XCTAssertTrue(store.cards.isEmpty)
    }

    @MainActor
    func testSessionNeverContainsPairedCards() {
        let temporaryURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).appending(path: "store.json")
        let store = makeStore(persistenceURL: temporaryURL)
        let session = store.sessionCards(limit: 100)
        XCTAssertEqual(Set(session.map(\.vocabularyID)).count, session.count)
    }

    func testObjectiveAnswerNormalizationAndAcceptedVariants() {
        XCTAssertTrue(AnswerEvaluator.isCorrect("  Résumé! ", expected: "resume"))
        XCTAssertTrue(AnswerEvaluator.isCorrect("colour", expected: "color", accepted: ["colour"]))
        XCTAssertFalse(AnswerEvaluator.isCorrect("colored", expected: "color", accepted: ["colour"]))
    }

    func testDelimitedImportHandlesQuotedCSVAndColumnMapping() throws {
        let csv = "Term,Definition,Sentence,Tags\n\"keep, up\",continue,\"Please keep, up.\",phrase;work\nresilient,able to recover,,quality"
        let table = try DelimitedVocabularyImporter.parse(data: Data(csv.utf8))
        let mapping = DelimitedVocabularyImporter.suggestedMapping(headers: table.headers)
        let rows = try DelimitedVocabularyImporter.rows(from: table, mapping: mapping)
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0].word, "keep, up")
        XCTAssertEqual(rows[0].example, "Please keep, up.")
        XCTAssertEqual(rows[0].tags, ["phrase", "work"])
    }

    @MainActor
    func testLexiconExposesSenseStackAndUsageMetadata() throws {
        let entry = try XCTUnwrap(Self.stableLexicon.entry(matching: "run"))
        let senses = Self.stableLexicon.senses(relatedToSenseID: entry.id)
        XCTAssertGreaterThan(senses.count, 1)
        XCTAssertEqual(senses.first?.learnerRank, 1)
        XCTAssertTrue(zip(senses, senses.dropFirst()).allSatisfy { pair in pair.0.learnerRank < pair.1.learnerRank })
    }

    @MainActor
    func testHarborUsesAutomaticallyRankedNounSense() throws {
        let entry = try XCTUnwrap(Self.stableLexicon.entry(matching: "harbor", partOfSpeech: "noun"))
        XCTAssertEqual(entry.learnerRank, 1)
        XCTAssertEqual(entry.definition, "A harbor is some water in a curve of land where it's safe for boats because there are no big waves.")
        XCTAssertTrue(entry.primaryExample.localizedCaseInsensitiveContains("ship in the harbor"))

        let senses = Self.stableLexicon.senses(relatedToSenseID: entry.id)
        XCTAssertEqual(senses.count, 1)
        XCTAssertEqual(senses.first?.learnerRank, 1)
        XCTAssertTrue(senses.first?.definition.localizedCaseInsensitiveContains("boats") == true)
    }

    @MainActor
    func testDictionarySearchReturnsAutomaticallyRankedHarborEntry() throws {
        let results = Self.stableLexicon.search("harbor", limit: 20)
        let noun = try XCTUnwrap(results.first { $0.partOfSpeech == "noun" })
        XCTAssertEqual(noun.learnerRank, 1)
        XCTAssertEqual(noun.definition, "A harbor is some water in a curve of land where it's safe for boats because there are no big waves.")
        XCTAssertTrue(noun.primaryExample.localizedCaseInsensitiveContains("ship in the harbor"))
    }

    @MainActor
    func testPersonalImportCreatesTwoDirectionsAndMergesDuplicateSense() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).appending(path: "store.json")
        let store = makeStore(persistenceURL: url)
        let first = PersonalImportRow(word: "testworthy", meaning: "worthy of being tested", example: "The idea is testworthy.", tags: ["personal"])
        XCTAssertEqual(store.importPersonalRows([first], duplicateResolution: .mergeSense), 1)
        let item = try XCTUnwrap(store.words.first { $0.word == "testworthy" })
        XCTAssertTrue(item.isPersonal)
        XCTAssertEqual(store.cards.filter { $0.vocabularyID == item.id }.count, 2)
        let coreSenseID = try XCTUnwrap(item.coreSense?.id)
        store.updateTranslation(vocabularyID: item.id, senseID: coreSenseID, text: "digno de probar")
        XCTAssertEqual(store.word(for: item.id)?.coreSense?.translationProvenance, .personal)
        store.confirmTranslation(vocabularyID: item.id, senseID: coreSenseID)
        XCTAssertEqual(store.word(for: item.id)?.coreSense?.translationProvenance, .reviewed)

        let second = PersonalImportRow(word: "testworthy", meaning: "useful for a trial", example: "A testworthy claim.", tags: ["research"])
        XCTAssertEqual(store.importPersonalRows([second], duplicateResolution: .mergeSense), 1)
        XCTAssertEqual(store.word(for: item.id)?.senses.count, 2)
        XCTAssertEqual(store.cards.filter { $0.vocabularyID == item.id }.count, 4)
    }

    @MainActor
    func testSecondarySenseUnlocksOnlyAfterEveryActiveDirectionIsStable() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).appending(path: "store.json")
        let store = makeStore(persistenceURL: url)
        let entry = try XCTUnwrap(store.lexicon.entry(matching: "run"))
        let word = store.addToLearning(entry)
        XCTAssertGreaterThan(word.senses.count, 2)
        XCTAssertEqual(store.word(for: word.id)?.activeSenses.count, 1)
        let coreCards = store.cards.filter { $0.vocabularyID == word.id }
        XCTAssertEqual(coreCards.count, 2)

        let start = Date(timeIntervalSince1970: 1_700_006_400)
        for day in 0..<30 {
            let reviewDate = Calendar.current.date(byAdding: .day, value: day * 7, to: start)!
            for card in coreCards { store.answer(cardID: card.id, correct: true, responseTime: 1, now: reviewDate) }
            if store.word(for: word.id)?.activeSenses.count == 2 { break }
        }
        XCTAssertEqual(store.word(for: word.id)?.activeSenses.count, 2)
        XCTAssertEqual(store.cards.filter { $0.vocabularyID == word.id }.count, 4)

        if let coreCard = coreCards.first {
            store.answer(cardID: coreCard.id, correct: true, responseTime: 1, now: start.addingTimeInterval(300 * 86_400))
        }
        XCTAssertEqual(store.word(for: word.id)?.activeSenses.count, 2, "A third sense must wait until the new active sense is stable in both directions")
    }

    @MainActor
    func testBackupRoundTripPreservesPersonalContentAndReports() throws {
        let firstURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).appending(path: "store.json")
        let first = makeStore(persistenceURL: firstURL)
        _ = first.importPersonalRows(
            [PersonalImportRow(word: "roundtrip", meaning: "a journey back", example: "It was a roundtrip.", tags: [])],
            duplicateResolution: .skip
        )
        let item = try XCTUnwrap(first.words.first { $0.word == "roundtrip" })
        first.reportContent(vocabularyID: item.id, senseID: item.coreSense?.id, reason: "Test report")
        let data = try first.exportData()

        let secondURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).appending(path: "store.json")
        let second = makeStore(persistenceURL: secondURL)
        try second.restore(from: data)
        XCTAssertNotNil(second.words.first { $0.word == "roundtrip" })
        XCTAssertEqual(second.contentReports.last?.reason, "Test report")
    }

    @MainActor
    func testPauseRemovesSenseFromSessionsAndQualityCountsReports() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).appending(path: "store.json")
        let store = makeStore(persistenceURL: url)
        let card = try XCTUnwrap(store.cards.first)
        store.pause(vocabularyID: card.vocabularyID, senseID: card.senseID)
        XCTAssertFalse(store.sessionCards(limit: 100).contains { $0.vocabularyID == card.vocabularyID })
        store.reportContent(vocabularyID: card.vocabularyID, senseID: card.senseID, reason: "Test")
        XCTAssertEqual(store.contentQualitySummary.learnerReports, 1)
    }

    @MainActor
    func testSpeechPlayerDefaultsToAppleTTSAndHonorsKittenSelection() {
        let apple = RecordingPronunciationEngine()
        let kitten = RecordingPronunciationEngine()
        let player = SpeechPlayer(appleEngine: apple, kittenEngine: kitten)

        UserDefaults.standard.removeObject(forKey: PronunciationEngineChoice.preferenceKey)
        player.play("hello")
        XCTAssertEqual(apple.spokenTexts, ["hello"])
        XCTAssertTrue(kitten.spokenTexts.isEmpty)

        UserDefaults.standard.set(PronunciationEngineChoice.kitten.rawValue, forKey: PronunciationEngineChoice.preferenceKey)
        player.play("world")
        XCTAssertEqual(kitten.spokenTexts, ["world"])
    }
}

private struct LearningSnapshotFixture: Codable {
    let words: [VocabularyItem]
    let cards: [StudyCard]
    let logs: [ReviewLog]
    let studyDays: [StudyDay]
    let lexiconVersion: String?
    let retiredLexiconIDs: Set<String>
}

@MainActor
private final class RecordingPronunciationEngine: OfflinePronunciationEngine {
    private(set) var spokenTexts: [String] = []

    func stop() {}

    func speak(_ text: String, locale: String) {
        spokenTexts.append(text)
    }
}
