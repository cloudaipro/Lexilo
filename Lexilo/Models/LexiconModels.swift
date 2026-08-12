import Foundation

struct LexiconEntry: Identifiable, Hashable, Sendable {
    let id: String
    let word: String
    let partOfSpeech: String
    let ipa: String
    let definition: String
    let examples: [String]
    let frequencyRank: Int
    let learningBand: Int
    let isPhrase: Bool

    var primaryExample: String { examples.first ?? "" }
}

struct LexiconCandidateReference: Sendable {
    let id: String
    let normalizedWord: String
}

enum VocabularyBand: Int, CaseIterable, Identifiable {
    case essential = 1
    case everyday
    case intermediate
    case advanced
    case challenge

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .essential: "Essential"
        case .everyday: "Everyday"
        case .intermediate: "Intermediate"
        case .advanced: "Advanced"
        case .challenge: "Challenge"
        }
    }
}

struct LexiconInformation: Sendable {
    let dataset: String
    let version: String
    let lexemeCount: Int
    let learningCandidateCount: Int

    static let unavailable = LexiconInformation(dataset: "Open English WordNet", version: "unavailable", lexemeCount: 0, learningCandidateCount: 0)
}
