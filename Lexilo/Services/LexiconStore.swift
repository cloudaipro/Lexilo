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
                dataset: Self.metadata("dataset", in: opened) ?? "Simple English Wiktionary",
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
        query(whereClause: "s.source_sense_id = ?", bindings: [id], limit: 1, primaryOnly: false).first
    }

    func senses(relatedToSenseID id: String) -> [LexiconEntry] {
        query(
            whereClause: "se.lexeme_id = (SELECT se2.lexeme_id FROM sense s2 JOIN source_entry se2 ON se2.id = s2.source_entry_id WHERE s2.source_sense_id = ?)",
            bindings: [id],
            limit: 24,
            primaryOnly: false
        )
    }

    func entry(matching word: String, partOfSpeech: String? = nil) -> LexiconEntry? {
        let normalized = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let partOfSpeech, !partOfSpeech.isEmpty {
            return exactEntry(normalized: normalized, partOfSpeech: partOfSpeech.lowercased())
        }
        return exactEntry(normalized: normalized)
    }

    /// Returns the preferred teachable sense for a lemma. Learning candidates
    /// are built with an example and ordered by the precomputed learner rank.
    func learningEntry(matching word: String) -> LexiconEntry? {
        let normalized = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return nil }
        return query(
            whereClause: "t.normalized_word = ? AND t.is_learning_candidate = 1",
            bindings: [normalized],
            limit: 1
        ).first
    }

    func search(_ text: String, limit: Int = 100) -> [LexiconEntry] {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else {
            return query(whereClause: "t.is_learning_candidate = 1", bindings: [], limit: limit)
        }
        let upperBound = normalized + "\u{10FFFF}"
        return query(whereClause: "t.normalized_word >= ? AND t.normalized_word < ?", bindings: [normalized, upperBound], limit: limit, exactWord: normalized)
    }

    func learningCandidates(
        inBand band: Int,
        includePhrases: Bool,
        offset: Int,
        limit: Int = 500
    ) -> [LexiconEntry] {
        let phraseClause = includePhrases ? "" : " AND t.is_phrase = 0"
        return query(
            whereClause: "t.is_learning_candidate = 1 AND t.learning_band = ?\(phraseClause)",
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
        let phraseClause = includePhrases ? "" : " AND t.is_phrase = 0"
        let sql = """
        SELECT s.source_sense_id, t.normalized_word
        FROM term t
        JOIN lexeme l ON l.term_id = t.id
        JOIN source_entry se ON se.lexeme_id = l.id
        JOIN sense s ON s.source_entry_id = se.id
        WHERE t.is_learning_candidate = 1 AND t.learning_band = ?\(phraseClause)
          AND s.id = (
              SELECT s2.id FROM sense s2
              JOIN source_entry se2 ON se2.id = s2.source_entry_id
              WHERE se2.lexeme_id = l.id
              ORDER BY CASE WHEN EXISTS (SELECT 1 FROM example e2 WHERE e2.sense_id = s2.id) THEN 0 ELSE 1 END,
                       s2.learner_rank ASC, s2.id
              LIMIT 1
          )
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
        return query(whereClause: "s.source_sense_id IN (\(placeholders))", bindings: ids, limit: ids.count)
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
        let exactOrdering = exactWord == nil ? "" : "CASE WHEN t.normalized_word = ? THEN 0 ELSE 1 END,"
        let preferredSense = """
        s.id = (
            SELECT s2.id FROM sense s2
            JOIN source_entry se2 ON se2.id = s2.source_entry_id
            WHERE se2.lexeme_id = l.id
            ORDER BY CASE WHEN EXISTS (SELECT 1 FROM example e2 WHERE e2.sense_id = s2.id) THEN 0 ELSE 1 END,
                     s2.learner_rank ASC, s2.id
            LIMIT 1
        )
        """
        let sql = """
        SELECT s.source_sense_id, t.word, l.part_of_speech,
               COALESCE((SELECT p.ipa FROM pronunciation p WHERE p.source_entry_id = se.id ORDER BY p.priority, p.id LIMIT 1), ''),
               s.definition, t.frequency_rank, t.learning_band, t.is_phrase,
               COALESCE((SELECT group_concat(text, char(31)) FROM (SELECT text FROM example WHERE sense_id = s.id ORDER BY quality_score DESC, id LIMIT 5)), ''),
               COALESCE(s.usage_label, ''), s.learner_rank, s.sense_order
        FROM term t
        JOIN lexeme l ON l.term_id = t.id
        JOIN source_entry se ON se.lexeme_id = l.id
        JOIN sense s ON s.source_entry_id = se.id
        WHERE \(whereClause)\(primaryOnly ? " AND \(preferredSense)" : "")
        ORDER BY \(exactOrdering) t.frequency_rank, t.normalized_word, l.part_of_speech, s.learner_rank ASC, s.id
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
                    senseOrder: Int(sqlite3_column_int(statement, 11)),
                    learnerRank: Int(sqlite3_column_int(statement, 10)),
                    frequencyRank: Int(sqlite3_column_int(statement, 5)),
                    learningBand: Int(sqlite3_column_int(statement, 6)),
                    isPhrase: sqlite3_column_int(statement, 7) != 0
                )
            )
        }
        return result
    }

    private func exactEntry(normalized: String, partOfSpeech: String? = nil) -> LexiconEntry? {
        var clause = "t.normalized_word = ?"
        var bindings = [normalized]
        if let partOfSpeech {
            clause += " AND l.part_of_speech = ?"
            bindings.append(partOfSpeech)
        }
        if let direct = query(whereClause: clause, bindings: bindings, limit: 1).first {
            return direct
        }
        var formClause = "wf.normalized_form = ?"
        var formBindings = [normalized]
        if let partOfSpeech {
            formClause += " AND l.part_of_speech = ?"
            formBindings.append(partOfSpeech)
        }
        return query(
            whereClause: "EXISTS (SELECT 1 FROM word_form wf WHERE wf.lexeme_id = l.id AND \(formClause))",
            bindings: formBindings,
            limit: 1
        ).first
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
