import Foundation

enum CardDirection: String, Codable, CaseIterable {
    case recognition
    case recall
    var label: String { self == .recognition ? "Word → Meaning" : "Meaning → Word" }
}

enum LearningState: String, Codable {
    case new, learning, mastered
}

enum SensePriority: String, Codable, CaseIterable {
    case core, extended, rare

    var label: String {
        switch self {
        case .core: "Core meaning"
        case .extended: "Extended meaning"
        case .rare: "Rare meaning"
        }
    }
}

enum TranslationProvenance: String, Codable {
    case reviewed, personal
}

struct LexicalSense: Identifiable, Codable, Hashable {
    let id: UUID
    var sourceID: String?
    var definition: String
    var examples: [String]
    var usageLabel: String
    var collocations: [String]
    var priority: SensePriority
    var translation: String?
    var translationProvenance: TranslationProvenance?
    var isActive: Bool
    var isPaused: Bool

    init(
        id: UUID = UUID(),
        sourceID: String? = nil,
        definition: String,
        examples: [String] = [],
        usageLabel: String = "",
        collocations: [String] = [],
        priority: SensePriority = .core,
        translation: String? = nil,
        translationProvenance: TranslationProvenance? = nil,
        isActive: Bool = true,
        isPaused: Bool = false
    ) {
        self.id = id
        self.sourceID = sourceID
        self.definition = definition
        self.examples = examples
        self.usageLabel = usageLabel
        self.collocations = collocations
        self.priority = priority
        self.translation = translation
        self.translationProvenance = translationProvenance
        self.isActive = isActive
        self.isPaused = isPaused
    }
}

struct VocabularyItem: Identifiable, Codable, Hashable {
    let id: UUID
    var lexiconID: String?
    let word: String
    var partOfSpeech: String
    var ipa: String
    var conciseDefinition: String
    var example: String
    var additionalExamples: [String]
    let frequencyRank: Int
    var introducedAt: Date?
    var senses: [LexicalSense]
    var acceptedAnswers: [String]
    var tags: [String]
    var isPersonal: Bool

    init(
        id: UUID = UUID(),
        lexiconID: String? = nil,
        word: String,
        partOfSpeech: String,
        ipa: String,
        conciseDefinition: String,
        example: String,
        additionalExamples: [String] = [],
        frequencyRank: Int,
        introducedAt: Date? = nil,
        senses: [LexicalSense] = [],
        acceptedAnswers: [String] = [],
        tags: [String] = [],
        isPersonal: Bool = false
    ) {
        self.id = id
        self.lexiconID = lexiconID
        self.word = word
        self.partOfSpeech = partOfSpeech
        self.ipa = ipa
        self.conciseDefinition = conciseDefinition
        self.example = example
        self.additionalExamples = additionalExamples
        self.frequencyRank = frequencyRank
        self.introducedAt = introducedAt
        self.senses = senses.isEmpty ? [LexicalSense(definition: conciseDefinition, examples: [example] + additionalExamples)] : senses
        self.acceptedAnswers = acceptedAnswers
        self.tags = tags
        self.isPersonal = isPersonal
    }

    var examples: [String] {
        var result: [String] = []
        for candidate in [example] + additionalExamples where !candidate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if !result.contains(candidate) {
                result.append(candidate)
            }
        }
        return result
    }

    var activeSenses: [LexicalSense] { senses.filter { $0.isActive && !$0.isPaused } }
    var coreSense: LexicalSense? { senses.first(where: { $0.priority == .core }) ?? senses.first }

    private enum CodingKeys: String, CodingKey {
        case id, lexiconID, word, partOfSpeech, ipa, conciseDefinition, example, additionalExamples
        case frequencyRank, introducedAt, senses, acceptedAnswers, tags, isPersonal
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        lexiconID = try container.decodeIfPresent(String.self, forKey: .lexiconID)
        word = try container.decode(String.self, forKey: .word)
        partOfSpeech = try container.decode(String.self, forKey: .partOfSpeech)
        ipa = try container.decode(String.self, forKey: .ipa)
        conciseDefinition = try container.decode(String.self, forKey: .conciseDefinition)
        example = try container.decode(String.self, forKey: .example)
        additionalExamples = try container.decodeIfPresent([String].self, forKey: .additionalExamples) ?? []
        frequencyRank = try container.decode(Int.self, forKey: .frequencyRank)
        introducedAt = try container.decodeIfPresent(Date.self, forKey: .introducedAt)
        senses = try container.decodeIfPresent([LexicalSense].self, forKey: .senses) ?? []
        if senses.isEmpty {
            senses = [LexicalSense(definition: conciseDefinition, examples: [example] + additionalExamples)]
        }
        acceptedAnswers = try container.decodeIfPresent([String].self, forKey: .acceptedAnswers) ?? []
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        isPersonal = try container.decodeIfPresent(Bool.self, forKey: .isPersonal) ?? false
    }
}

enum ReviewOutcome: String, Codable {
    case again, correct, easy
}

struct StudyCard: Identifiable, Codable, Hashable {
    let id: UUID
    let vocabularyID: UUID
    let direction: CardDirection
    var learningState: LearningState
    var successCount: Int
    var nextReviewDate: Date
    var lastReviewedDate: Date?
    var lastPresentedDate: Date?
    var senseID: UUID?
    var difficulty: Double
    var stability: Double
    var retrievability: Double
    var lastOutcome: ReviewOutcome?
    var lastReviewLatency: TimeInterval?
    var isPaused: Bool

    init(id: UUID = UUID(), vocabularyID: UUID, senseID: UUID? = nil, direction: CardDirection, nextReviewDate: Date) {
        self.id = id
        self.vocabularyID = vocabularyID
        self.direction = direction
        self.learningState = .new
        self.successCount = 0
        self.nextReviewDate = nextReviewDate
        self.lastReviewedDate = nil
        self.lastPresentedDate = nil
        self.senseID = senseID
        self.difficulty = 5
        self.stability = 0.6
        self.retrievability = 1
        self.lastOutcome = nil
        self.lastReviewLatency = nil
        self.isPaused = false
    }


    private enum CodingKeys: String, CodingKey {
        case id, vocabularyID, direction, learningState, successCount, nextReviewDate, lastReviewedDate, lastPresentedDate
        case senseID, difficulty, stability, retrievability, lastOutcome, lastReviewLatency, isPaused
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        vocabularyID = try container.decode(UUID.self, forKey: .vocabularyID)
        direction = try container.decode(CardDirection.self, forKey: .direction)
        learningState = try container.decode(LearningState.self, forKey: .learningState)
        successCount = try container.decode(Int.self, forKey: .successCount)
        nextReviewDate = try container.decode(Date.self, forKey: .nextReviewDate)
        lastReviewedDate = try container.decodeIfPresent(Date.self, forKey: .lastReviewedDate)
        lastPresentedDate = try container.decodeIfPresent(Date.self, forKey: .lastPresentedDate)
        senseID = try container.decodeIfPresent(UUID.self, forKey: .senseID)
        difficulty = try container.decodeIfPresent(Double.self, forKey: .difficulty) ?? 5
        stability = try container.decodeIfPresent(Double.self, forKey: .stability) ?? max(0.6, Double(successCount))
        retrievability = try container.decodeIfPresent(Double.self, forKey: .retrievability) ?? 1
        lastOutcome = try container.decodeIfPresent(ReviewOutcome.self, forKey: .lastOutcome)
        lastReviewLatency = try container.decodeIfPresent(TimeInterval.self, forKey: .lastReviewLatency)
        isPaused = try container.decodeIfPresent(Bool.self, forKey: .isPaused) ?? false
    }
}

struct StudyDay: Identifiable, Codable, Hashable {
    let date: Date
    var reviewedCount: Int
    var newWordsIntroduced: Int
    var goal: Int
    var completed: Bool

    var id: Date { date }

    init(date: Date, goal: Int, reviewedCount: Int = 0, newWordsIntroduced: Int = 0) {
        self.date = date
        self.reviewedCount = reviewedCount
        self.newWordsIntroduced = newWordsIntroduced
        self.goal = goal
        self.completed = reviewedCount >= goal
    }
}

struct ReviewLog: Identifiable, Codable, Hashable {
    let id: UUID
    let cardID: UUID
    let vocabularyID: UUID
    let direction: CardDirection
    let answeredCorrectly: Bool
    let reviewedAt: Date
    let scheduledFor: Date
    let response: String?
    let responseTime: TimeInterval?
    let usedHint: Bool
    let outcome: ReviewOutcome
    let retrievabilityBeforeReview: Double
    let nextIntervalDays: Int

    init(
        card: StudyCard,
        correct: Bool,
        scheduledFor: Date,
        reviewedAt: Date = .now,
        response: String? = nil,
        responseTime: TimeInterval? = nil,
        usedHint: Bool = false,
        outcome: ReviewOutcome? = nil,
        retrievabilityBeforeReview: Double = 1,
        nextIntervalDays: Int = 0
    ) {
        self.id = UUID()
        self.cardID = card.id
        self.vocabularyID = card.vocabularyID
        self.direction = card.direction
        self.answeredCorrectly = correct
        self.reviewedAt = reviewedAt
        self.scheduledFor = scheduledFor
        self.response = response
        self.responseTime = responseTime
        self.usedHint = usedHint
        self.outcome = outcome ?? (correct ? .correct : .again)
        self.retrievabilityBeforeReview = retrievabilityBeforeReview
        self.nextIntervalDays = nextIntervalDays
    }


    private enum CodingKeys: String, CodingKey {
        case id, cardID, vocabularyID, direction, answeredCorrectly, reviewedAt, scheduledFor
        case response, responseTime, usedHint, outcome, retrievabilityBeforeReview, nextIntervalDays
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        cardID = try container.decode(UUID.self, forKey: .cardID)
        vocabularyID = try container.decode(UUID.self, forKey: .vocabularyID)
        direction = try container.decode(CardDirection.self, forKey: .direction)
        answeredCorrectly = try container.decode(Bool.self, forKey: .answeredCorrectly)
        reviewedAt = try container.decode(Date.self, forKey: .reviewedAt)
        scheduledFor = try container.decode(Date.self, forKey: .scheduledFor)
        response = try container.decodeIfPresent(String.self, forKey: .response)
        responseTime = try container.decodeIfPresent(TimeInterval.self, forKey: .responseTime)
        usedHint = try container.decodeIfPresent(Bool.self, forKey: .usedHint) ?? false
        outcome = try container.decodeIfPresent(ReviewOutcome.self, forKey: .outcome) ?? (answeredCorrectly ? .correct : .again)
        retrievabilityBeforeReview = try container.decodeIfPresent(Double.self, forKey: .retrievabilityBeforeReview) ?? 1
        nextIntervalDays = try container.decodeIfPresent(Int.self, forKey: .nextIntervalDays) ?? 0
    }
}

struct ContentReport: Identifiable, Codable, Hashable {
    let id: UUID
    let vocabularyID: UUID
    let senseID: UUID?
    let reason: String
    let createdAt: Date

    init(vocabularyID: UUID, senseID: UUID?, reason: String, createdAt: Date = .now) {
        id = UUID()
        self.vocabularyID = vocabularyID
        self.senseID = senseID
        self.reason = reason
        self.createdAt = createdAt
    }
}

struct MemoryForecastDay: Identifiable, Hashable {
    let date: Date
    let count: Int
    var id: Date { date }
}

struct ContentQualitySummary: Hashable {
    let missingIPA: Int
    let missingExamples: Int
    let duplicatedSenses: Int
    let confusingDefinitions: Int
    let exampleLeakage: Int
    let learnerReports: Int
}

struct PersonalImportRow: Identifiable, Hashable {
    let id = UUID()
    var word: String
    var meaning: String
    var example: String
    var tags: [String]
}

struct DelimitedTable: Hashable {
    let headers: [String]
    let rows: [[String]]
}

struct ImportColumnMapping: Hashable {
    var word: Int?
    var meaning: Int?
    var example: Int?
    var tags: Int?
}

enum DelimitedVocabularyImporter {
    enum ImportError: LocalizedError {
        case unreadable, missingRequiredColumns
        var errorDescription: String? {
            switch self {
            case .unreadable: "The file is not valid UTF-8 CSV or TSV."
            case .missingRequiredColumns: "Map both Word and Meaning before continuing."
            }
        }
    }

    static func parse(data: Data) throws -> DelimitedTable {
        guard let text = String(data: data, encoding: .utf8) else { throw ImportError.unreadable }
        let firstLine = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        let delimiter: Character = firstLine.filter { $0 == "\t" }.count > firstLine.filter { $0 == "," }.count ? "\t" : ","
        let records = parseRecords(text, delimiter: delimiter).filter { $0.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) }
        guard let headers = records.first, !headers.isEmpty else { throw ImportError.unreadable }
        return DelimitedTable(headers: headers, rows: Array(records.dropFirst()))
    }

    static func suggestedMapping(headers: [String]) -> ImportColumnMapping {
        func index(_ names: [String]) -> Int? {
            headers.firstIndex { header in names.contains(AnswerEvaluator.normalize(header)) }
        }
        return ImportColumnMapping(
            word: index(["word", "term", "front"]),
            meaning: index(["meaning", "definition", "back"]),
            example: index(["example", "sentence", "context"]),
            tags: index(["tags", "tag"])
        )
    }

    static func rows(from table: DelimitedTable, mapping: ImportColumnMapping) throws -> [PersonalImportRow] {
        guard let wordIndex = mapping.word, let meaningIndex = mapping.meaning else { throw ImportError.missingRequiredColumns }
        func value(_ row: [String], at index: Int?) -> String {
            guard let index, row.indices.contains(index) else { return "" }
            return row[index].trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return table.rows.compactMap { row in
            let word = value(row, at: wordIndex)
            let meaning = value(row, at: meaningIndex)
            guard !word.isEmpty, !meaning.isEmpty else { return nil }
            let tagText = value(row, at: mapping.tags)
            let tags = tagText.split(whereSeparator: { $0 == "," || $0 == ";" }).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            return PersonalImportRow(word: word, meaning: meaning, example: value(row, at: mapping.example), tags: tags)
        }
    }

    private static func parseRecords(_ text: String, delimiter: Character) -> [[String]] {
        var records: [[String]] = []
        var row: [String] = []
        var field = ""
        var quoted = false
        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            if character == "\"" {
                let next = text.index(after: index)
                if quoted, next < text.endIndex, text[next] == "\"" {
                    field.append("\"")
                    index = next
                } else {
                    quoted.toggle()
                }
            } else if character == delimiter && !quoted {
                row.append(field)
                field = ""
            } else if character.isNewline && !quoted {
                if character == "\n" || (character == "\r" && (text.index(after: index) == text.endIndex || text[text.index(after: index)] != "\n")) {
                    row.append(field)
                    records.append(row)
                    row = []
                    field = ""
                }
            } else {
                field.append(character)
            }
            index = text.index(after: index)
        }
        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            records.append(row)
        }
        return records
    }
}

enum ImportDuplicateResolution: String, CaseIterable, Identifiable {
    case mergeSense = "Merge as new sense"
    case skip = "Skip duplicates"
    var id: String { rawValue }
}

enum AnswerEvaluator {
    static func normalize(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .unicodeScalars
            .map { CharacterSet.alphanumerics.contains($0) ? Character(String($0)) : " " }
            .reduce(into: "") { result, character in
                if character == " " && result.last == " " { return }
                result.append(character)
            }
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isCorrect(_ response: String, expected: String, accepted: [String] = []) -> Bool {
        let normalized = normalize(response)
        guard !normalized.isEmpty else { return false }
        return ([expected] + accepted).contains { normalize($0) == normalized }
    }
}
