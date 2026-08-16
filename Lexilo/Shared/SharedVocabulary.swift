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

struct WidgetStudySnapshot: Codable, Sendable {
    let vocabularyID: UUID
    let word: String
    let definition: String
    let example: String
    let additionalExamples: [String]
    let mediumContent: MediumWidgetContent
    let streak: Int

    init(
        vocabularyID: UUID,
        word: String,
        example: String,
        definition: String = "",
        additionalExamples: [String] = [],
        mediumContent: MediumWidgetContent = .definition,
        streak: Int
    ) {
        self.vocabularyID = vocabularyID
        self.word = word
        self.definition = definition
        self.example = example
        self.additionalExamples = additionalExamples
        self.mediumContent = mediumContent
        self.streak = streak
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

    private enum CodingKeys: String, CodingKey {
        case vocabularyID
        case word
        case definition
        case example
        case additionalExamples
        case mediumContent
        case streak
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
        guard let snapshotURL, let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: snapshotURL, options: .atomic)
    }

    static func load() -> WidgetStudySnapshot? {
        guard let snapshotURL,
              let data = try? Data(contentsOf: snapshotURL),
              let snapshot = try? JSONDecoder().decode(WidgetStudySnapshot.self, from: data)
        else { return nil }
        return snapshot
    }
}
