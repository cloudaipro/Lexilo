import XCTest
@testable import Lexilo

final class ReviewSchedulerTests: XCTestCase {
    func testFixedIntervals() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = Date(timeIntervalSince1970: 1_700_006_400)
        for (index, interval) in ReviewScheduler.intervals.enumerated() {
            let next = ReviewScheduler.nextDate(successCount: index + 1, from: start, calendar: calendar)
            XCTAssertEqual(calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: next).day, interval)
        }
    }

    func testIntervalCapsAt180Days() {
        let start = Date()
        let next = ReviewScheduler.nextDate(successCount: 42, from: start)
        XCTAssertEqual(Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: start), to: next).day, 180)
    }

    @MainActor
    func testSessionNeverContainsPairedCards() {
        let temporaryURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).appending(path: "store.json")
        let store = LearningStore(persistenceURL: temporaryURL)
        let session = store.sessionCards(limit: 100)
        XCTAssertEqual(Set(session.map(\.vocabularyID)).count, session.count)
    }
}

