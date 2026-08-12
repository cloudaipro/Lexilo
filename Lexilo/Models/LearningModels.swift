import Foundation

enum CardDirection: String, Codable, CaseIterable {
    case recognition
    case recall
    var label: String { self == .recognition ? "Word → Meaning" : "Meaning → Word" }
}

enum LearningState: String, Codable {
    case new, learning, mastered
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
        introducedAt: Date? = nil
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

    private enum CodingKeys: String, CodingKey {
        case id, lexiconID, word, partOfSpeech, ipa, conciseDefinition, example, additionalExamples
        case frequencyRank, introducedAt
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
    }
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

    init(id: UUID = UUID(), vocabularyID: UUID, direction: CardDirection, nextReviewDate: Date) {
        self.id = id
        self.vocabularyID = vocabularyID
        self.direction = direction
        self.learningState = .new
        self.successCount = 0
        self.nextReviewDate = nextReviewDate
        self.lastReviewedDate = nil
        self.lastPresentedDate = nil
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

    init(card: StudyCard, correct: Bool, scheduledFor: Date, reviewedAt: Date = .now) {
        self.id = UUID()
        self.cardID = card.id
        self.vocabularyID = card.vocabularyID
        self.direction = card.direction
        self.answeredCorrectly = correct
        self.reviewedAt = reviewedAt
        self.scheduledFor = scheduledFor
    }
}
