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
    let word: String
    let partOfSpeech: String
    let ipa: String
    let conciseDefinition: String
    let example: String
    let frequencyRank: Int
    let sourceID: String

    init(id: UUID = UUID(), word: String, partOfSpeech: String, ipa: String, conciseDefinition: String, example: String, frequencyRank: Int, sourceID: String = "lexilo-starter") {
        self.id = id
        self.word = word
        self.partOfSpeech = partOfSpeech
        self.ipa = ipa
        self.conciseDefinition = conciseDefinition
        self.example = example
        self.frequencyRank = frequencyRank
        self.sourceID = sourceID
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

    init(id: UUID = UUID(), vocabularyID: UUID, direction: CardDirection, nextReviewDate: Date) {
        self.id = id
        self.vocabularyID = vocabularyID
        self.direction = direction
        self.learningState = .new
        self.successCount = 0
        self.nextReviewDate = nextReviewDate
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

