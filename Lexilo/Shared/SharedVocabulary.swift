import Foundation

struct WidgetStudySnapshot: Codable, Sendable {
    let vocabularyID: UUID
    let word: String
    let example: String
    let streak: Int
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
