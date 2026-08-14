import Foundation
import SQLite3

@MainActor
final class LexiconStore {
    // SQLite owns the handle and all queries remain confined to this main-actor
    // store. Marking only the raw pointer unsafe avoids making the whole store
    // unchecked-Sendable while allowing deinit to close it under Swift 6.
    nonisolated(unsafe) private var database: OpaquePointer?
    let information: LexiconInformation

    init(databaseURL: URL? = Bundle.main.url(forResource: "lexilo-lexicon", withExtension: "sqlite")) {
        var opened: OpaquePointer?
        if let databaseURL,
           sqlite3_open_v2(databaseURL.path, &opened, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK {
            database = opened
            information = LexiconInformation(
                dataset: Self.metadata("dataset", in: opened) ?? "Open English WordNet",
                version: Self.metadata("dataset_version", in: opened) ?? "unknown",
                lexemeCount: Int(Self.metadata("lexeme_count", in: opened) ?? "") ?? 0,
                learningCandidateCount: Int(Self.metadata("learning_candidate_count", in: opened) ?? "") ?? 0
            )
        } else {
            if opened != nil { sqlite3_close(opened) }
            database = nil
            information = .unavailable
        }
    }

    deinit {
        if let database { sqlite3_close(database) }
    }

    var isAvailable: Bool { database != nil }

    func entry(id: String) -> LexiconEntry? {
        query(whereClause: "s.id = ?", bindings: [id], limit: 1, primaryOnly: false).first
    }

    func senses(relatedToSenseID id: String) -> [LexiconEntry] {
        query(
            whereClause: "s.lexeme_id = (SELECT lexeme_id FROM sense WHERE id = ?)",
            bindings: [id],
            limit: 24,
            primaryOnly: false
        )
    }

    func entry(matching word: String, partOfSpeech: String? = nil) -> LexiconEntry? {
        let normalized = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let partOfSpeech, !partOfSpeech.isEmpty {
            return query(whereClause: "l.normalized_lemma = ? AND l.part_of_speech = ?", bindings: [normalized, partOfSpeech.lowercased()], limit: 1).first
        }
        return query(whereClause: "l.normalized_lemma = ?", bindings: [normalized], limit: 1).first
    }

    /// Returns the preferred teachable sense for a lemma. Learning candidates
    /// are built with an example and ordered by corpus frequency.
    func learningEntry(matching word: String) -> LexiconEntry? {
        let normalized = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return nil }
        return query(
            whereClause: "l.normalized_lemma = ? AND l.is_learning_candidate = 1",
            bindings: [normalized],
            limit: 1
        ).first
    }

    func search(_ text: String, limit: Int = 100) -> [LexiconEntry] {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else {
            return query(whereClause: "l.is_learning_candidate = 1", bindings: [], limit: limit)
        }
        return query(
            whereClause: "l.normalized_lemma LIKE ? ESCAPE '\\'",
            bindings: ["%\(escapeLike(normalized))%"],
            limit: limit,
            exactWord: normalized
        )
    }

    func learningCandidates(
        inBand band: Int,
        includePhrases: Bool,
        offset: Int,
        limit: Int = 500
    ) -> [LexiconEntry] {
        let phraseClause = includePhrases ? "" : " AND l.is_phrase = 0"
        return query(
            whereClause: "l.is_learning_candidate = 1 AND l.learning_band = ?\(phraseClause)",
            bindings: [String(max(1, min(5, band)))],
            limit: limit,
            offset: max(0, offset)
        )
    }

    /// Loads only the identifiers needed for deterministic rotation. Avoiding
    /// definitions/examples here keeps launch and replenishment inexpensive
    /// even when a band contains several thousand entries.
    func learningCandidateReferences(inBand band: Int, includePhrases: Bool) -> [LexiconCandidateReference] {
        guard let database else { return [] }
        let phraseClause = includePhrases ? "" : " AND l.is_phrase = 0"
        let sql = """
        SELECT s.id, l.normalized_lemma
        FROM lexeme l
        JOIN sense s ON s.lexeme_id = l.id AND s.sense_order = 0
        WHERE l.is_learning_candidate = 1 AND l.learning_band = ?\(phraseClause)
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else { return [] }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int(statement, 1, Int32(max(1, min(5, band))))

        var result: [LexiconCandidateReference] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            result.append(.init(id: Self.string(statement, 0), normalizedWord: Self.string(statement, 1)))
        }
        return result
    }

    func entries(ids: [String]) -> [LexiconEntry] {
        guard !ids.isEmpty else { return [] }
        let placeholders = Array(repeating: "?", count: ids.count).joined(separator: ",")
        return query(whereClause: "s.id IN (\(placeholders))", bindings: ids, limit: ids.count)
    }

    private func query(
        whereClause: String,
        bindings: [String],
        limit: Int,
        offset: Int = 0,
        exactWord: String? = nil,
        primaryOnly: Bool = true
    ) -> [LexiconEntry] {
        guard let database else { return [] }
        let exactOrdering = exactWord == nil ? "" : "CASE WHEN l.normalized_lemma = ? THEN 0 WHEN l.normalized_lemma LIKE ? THEN 1 ELSE 2 END,"
        let sql = """
        SELECT s.id, l.lemma, l.part_of_speech, COALESCE(l.pronunciation, ''),
               s.definition, l.frequency_rank, l.learning_band, l.is_phrase,
               COALESCE((SELECT group_concat(text, char(31)) FROM example WHERE sense_id = s.id), ''),
               COALESCE(s.usage_label, ''), s.sense_order
        FROM lexeme l
        JOIN sense s ON s.lexeme_id = l.id
        WHERE \(whereClause)\(primaryOnly ? " AND s.sense_order = 0" : "")
        ORDER BY \(exactOrdering) l.frequency_rank, l.normalized_lemma, l.part_of_speech, s.sense_order
        LIMIT ? OFFSET ?
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else { return [] }
        defer { sqlite3_finalize(statement) }

        var index: Int32 = 1
        for binding in bindings {
            sqlite3_bind_text(statement, index, binding, -1, Self.transientDestructor)
            index += 1
        }
        if let exactWord {
            sqlite3_bind_text(statement, index, exactWord, -1, Self.transientDestructor)
            index += 1
            sqlite3_bind_text(statement, index, "\(escapeLike(exactWord))%", -1, Self.transientDestructor)
            index += 1
        }
        sqlite3_bind_int(statement, index, Int32(limit))
        sqlite3_bind_int(statement, index + 1, Int32(offset))

        var result: [LexiconEntry] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let examples = Self.string(statement, 8).split(separator: Character(UnicodeScalar(31)!)).map(String.init)
            result.append(
                LexiconEntry(
                    id: Self.string(statement, 0),
                    word: Self.string(statement, 1),
                    partOfSpeech: Self.string(statement, 2),
                    ipa: Self.string(statement, 3),
                    definition: Self.string(statement, 4),
                    examples: Array(examples.prefix(5)),
                    usageLabel: Self.string(statement, 9),
                    senseOrder: Int(sqlite3_column_int(statement, 10)),
                    frequencyRank: Int(sqlite3_column_int(statement, 5)),
                    learningBand: Int(sqlite3_column_int(statement, 6)),
                    isPhrase: sqlite3_column_int(statement, 7) != 0
                )
            )
        }
        return result
    }

    private func escapeLike(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
    }

    private static func metadata(_ key: String, in database: OpaquePointer?) -> String? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "SELECT value FROM metadata WHERE key = ?", -1, &statement, nil) == SQLITE_OK,
              let statement
        else { return nil }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, key, -1, transientDestructor)
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        return string(statement, 0)
    }

    private static func string(_ statement: OpaquePointer?, _ column: Int32) -> String {
        guard let value = sqlite3_column_text(statement, column) else { return "" }
        return String(cString: value)
    }

    private static let transientDestructor = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
}
