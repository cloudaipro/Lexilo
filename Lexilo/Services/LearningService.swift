import Foundation
import Combine

enum ReviewScheduler {
    static let intervals = [1, 2, 4, 7, 14, 30, 60, 120, 180]

    static func nextDate(successCount: Int, from date: Date, calendar: Calendar = .current) -> Date {
        let index = max(0, min(successCount - 1, intervals.count - 1))
        return calendar.date(byAdding: .day, value: intervals[index], to: calendar.startOfDay(for: date)) ?? date
    }

    static func isSameDay(_ lhs: Date?, _ rhs: Date, calendar: Calendar = .current) -> Bool {
        guard let lhs else { return false }
        return calendar.isDate(lhs, inSameDayAs: rhs)
    }
}

protocol LexicalContentProvider: Sendable {
    var sourceID: String { get }
    func entries() async throws -> [SeedWord]
}

struct BundledLexiconProvider: LexicalContentProvider {
    let sourceID = "lexilo-starter"
    func entries() async throws -> [SeedWord] { StarterVocabulary.words }
}

@MainActor
final class LearningStore: ObservableObject {
    @Published private(set) var words: [VocabularyItem] = []
    @Published private(set) var cards: [StudyCard] = []
    @Published private(set) var logs: [ReviewLog] = []

    private struct Snapshot: Codable {
        let words: [VocabularyItem]
        let cards: [StudyCard]
        let logs: [ReviewLog]
    }

    private let persistenceURL: URL?

    init(persistenceURL: URL? = nil, reset: Bool = false) {
        if let persistenceURL {
            self.persistenceURL = persistenceURL
        } else {
            self.persistenceURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appending(path: "lexilo-learning.json")
        }
        if reset, let persistenceURL = self.persistenceURL {
            try? FileManager.default.removeItem(at: persistenceURL)
        }
        if !load() { seed() }
    }

    func word(for id: UUID) -> VocabularyItem? { words.first { $0.id == id } }

    func sessionCards(limit: Int = 10, now: Date = .now) -> [StudyCard] {
        let ordered = cards.sorted {
            $0.nextReviewDate == $1.nextReviewDate ? $0.successCount < $1.successCount : $0.nextReviewDate < $1.nextReviewDate
        }
        var servedVocabulary = Set<UUID>()
        var result: [StudyCard] = []
        for card in ordered where card.nextReviewDate <= now {
            guard !servedVocabulary.contains(card.vocabularyID) else { continue }
            let pairedReviewedToday = cards.contains {
                $0.vocabularyID == card.vocabularyID && $0.id != card.id && ReviewScheduler.isSameDay($0.lastReviewedDate, now)
            }
            guard !pairedReviewedToday else { continue }
            servedVocabulary.insert(card.vocabularyID)
            result.append(card)
            if result.count == limit { break }
        }
        return result
    }

    func answer(cardID: UUID, correct: Bool, now: Date = .now) {
        guard let index = cards.firstIndex(where: { $0.id == cardID }) else { return }
        if correct {
            cards[index].successCount += 1
            cards[index].learningState = cards[index].successCount >= 7 ? .mastered : .learning
            cards[index].nextReviewDate = ReviewScheduler.nextDate(successCount: cards[index].successCount, from: now)
        } else {
            cards[index].successCount = 0
            cards[index].learningState = .learning
            cards[index].nextReviewDate = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now)) ?? now
        }
        cards[index].lastReviewedDate = now
        logs.append(ReviewLog(card: cards[index], correct: correct, scheduledFor: cards[index].nextReviewDate, reviewedAt: now))
        save()
    }

    private func seed() {
        let start = Calendar.current.startOfDay(for: .now)
        words = StarterVocabulary.words.map {
            VocabularyItem(word: $0.word, partOfSpeech: $0.partOfSpeech, ipa: $0.ipa, conciseDefinition: $0.definition, example: $0.example, frequencyRank: $0.rank)
        }
        cards = words.enumerated().flatMap { index, item -> [StudyCard] in
            let recognitionDay = index < 10 ? start : Calendar.current.date(byAdding: .day, value: index - 9, to: start)!
            let recallDay = Calendar.current.date(byAdding: .day, value: max(1, index - 5), to: start)!
            return [
                StudyCard(vocabularyID: item.id, direction: .recognition, nextReviewDate: recognitionDay),
                StudyCard(vocabularyID: item.id, direction: .recall, nextReviewDate: recallDay)
            ]
        }
        save()
    }

    @discardableResult private func load() -> Bool {
        guard let persistenceURL, let data = try? Data(contentsOf: persistenceURL), let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return false }
        words = snapshot.words
        cards = snapshot.cards
        logs = snapshot.logs
        return true
    }

    private func save() {
        guard let persistenceURL, let data = try? JSONEncoder().encode(Snapshot(words: words, cards: cards, logs: logs)) else { return }
        try? FileManager.default.createDirectory(at: persistenceURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: persistenceURL, options: .atomic)
    }
}
