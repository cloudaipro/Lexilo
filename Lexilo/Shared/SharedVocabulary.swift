import Foundation

enum MediumWidgetContent: String, Codable, CaseIterable, Identifiable, Sendable {
    case definition
    case example

    static let preferenceKey = "mediumWidgetContent"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .definition: return "Definition"
        case .example: return "Example"
        }
    }
}

struct WidgetStudyWord: Codable, Hashable, Sendable {
    let vocabularyID: UUID
    let word: String
    let definition: String
    let example: String
    let additionalExamples: [String]

    init(
        vocabularyID: UUID,
        word: String,
        example: String,
        definition: String = "",
        additionalExamples: [String] = []
    ) {
        self.vocabularyID = vocabularyID
        self.word = word
        self.definition = definition
        self.example = example
        self.additionalExamples = additionalExamples
    }

    var exampleCandidates: [String] {
        var result: [String] = []
        for candidate in [example] + additionalExamples {
            let cleaned = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty, !result.contains(cleaned) else { continue }
            result.append(cleaned)
        }
        return result
    }
}

struct WidgetStudySnapshot: Codable, Sendable {
    let vocabularyID: UUID
    let word: String
    let definition: String
    let example: String
    let additionalExamples: [String]
    let mediumContent: MediumWidgetContent
    let streak: Int
    let dailyWords: [WidgetStudyWord]
    let dailyDate: Date?
    let dailyRotationIndex: Int?

    init(
        vocabularyID: UUID,
        word: String,
        example: String,
        definition: String = "",
        additionalExamples: [String] = [],
        mediumContent: MediumWidgetContent = .definition,
        streak: Int,
        dailyWords: [WidgetStudyWord] = [],
        dailyDate: Date? = nil,
        dailyRotationIndex: Int? = nil
    ) {
        self.vocabularyID = vocabularyID
        self.word = word
        self.definition = definition
        self.example = example
        self.additionalExamples = additionalExamples
        self.mediumContent = mediumContent
        self.streak = streak
        self.dailyWords = dailyWords
        self.dailyDate = dailyDate
        self.dailyRotationIndex = dailyRotationIndex
    }

    var exampleCandidates: [String] {
        var result: [String] = []
        for candidate in [example] + additionalExamples {
            let cleaned = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty, !result.contains(cleaned) else { continue }
            result.append(cleaned)
        }
        return result
    }

    var shortestExample: String {
        exampleCandidates.min { lhs, rhs in
            let lhsWordCount = lhs.split(whereSeparator: { $0.isWhitespace }).count
            let rhsWordCount = rhs.split(whereSeparator: { $0.isWhitespace }).count
            if lhsWordCount != rhsWordCount { return lhsWordCount < rhsWordCount }
            return lhs.count < rhs.count
        } ?? example
    }

    var dailyWordIDs: [UUID] { dailyWords.map(\.vocabularyID) }

    func showingDailyWord(at index: Int) -> WidgetStudySnapshot {
        guard !dailyWords.isEmpty else { return self }
        let safeIndex = ((index % dailyWords.count) + dailyWords.count) % dailyWords.count
        let selected = dailyWords[safeIndex]
        return WidgetStudySnapshot(
            vocabularyID: selected.vocabularyID,
            word: selected.word,
            example: selected.example,
            definition: selected.definition,
            additionalExamples: selected.additionalExamples,
            mediumContent: mediumContent,
            streak: streak,
            dailyWords: dailyWords,
            dailyDate: dailyDate,
            dailyRotationIndex: safeIndex
        )
    }

    private enum CodingKeys: String, CodingKey {
        case vocabularyID
        case word
        case definition
        case example
        case additionalExamples
        case mediumContent
        case streak
        case dailyWords
        case dailyDate
        case dailyRotationIndex
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        vocabularyID = try container.decode(UUID.self, forKey: .vocabularyID)
        word = try container.decode(String.self, forKey: .word)
        definition = try container.decodeIfPresent(String.self, forKey: .definition) ?? ""
        example = try container.decode(String.self, forKey: .example)
        additionalExamples = try container.decodeIfPresent([String].self, forKey: .additionalExamples) ?? []
        mediumContent = try container.decodeIfPresent(MediumWidgetContent.self, forKey: .mediumContent) ?? .definition
        streak = try container.decode(Int.self, forKey: .streak)
        dailyWords = try container.decodeIfPresent([WidgetStudyWord].self, forKey: .dailyWords) ?? []
        dailyDate = try container.decodeIfPresent(Date.self, forKey: .dailyDate)
        dailyRotationIndex = try container.decodeIfPresent(Int.self, forKey: .dailyRotationIndex)
    }
}

enum SharedStudySnapshotStore {
    static let appGroupIdentifier = "group.com.lexilo.shared"
    private static let fileName = "widget-study-snapshot.json"

    private static var snapshotURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appending(path: fileName)
    }

    static func save(_ snapshot: WidgetStudySnapshot) {
        let snapshot = preservingRotationState(for: snapshot)
        write(snapshot)
    }

    static func advanceToNextDailyWord() -> WidgetStudySnapshot? {
        guard let snapshot = load(), !snapshot.dailyWords.isEmpty else { return load() }
        let nextIndex = snapshot.dailyRotationIndex.map { $0 + 1 } ?? 0
        let next = snapshot.showingDailyWord(at: nextIndex)
        write(next)
        return next
    }

    private static func write(_ snapshot: WidgetStudySnapshot) {
        guard let snapshotURL, let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: snapshotURL, options: .atomic)
    }

    private static func preservingRotationState(for snapshot: WidgetStudySnapshot) -> WidgetStudySnapshot {
        guard let existing = load(),
              !existing.dailyWords.isEmpty,
              !snapshot.dailyWords.isEmpty,
              existing.dailyWordIDs == snapshot.dailyWordIDs,
              let existingDate = existing.dailyDate,
              let snapshotDate = snapshot.dailyDate,
              Calendar.current.isDate(existingDate, inSameDayAs: snapshotDate),
              let existingIndex = existing.dailyRotationIndex
        else {
            return snapshot
        }
        return snapshot.showingDailyWord(at: existingIndex)
    }

    static func load() -> WidgetStudySnapshot? {
        guard let snapshotURL,
              let data = try? Data(contentsOf: snapshotURL),
              let snapshot = try? JSONDecoder().decode(WidgetStudySnapshot.self, from: data)
        else { return nil }
        return snapshot
    }
}
