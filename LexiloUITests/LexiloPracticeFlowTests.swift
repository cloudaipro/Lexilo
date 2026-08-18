import XCTest

@MainActor
final class LexiloPracticeFlowTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["--ui-testing-reset", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        if app.state != .notRunning {
            app.terminate()
        }
        app.launch()
    }

    func testFullPracticeFlow() throws {
        completeDailyLearning()

        let start = app.buttons["daily-study-start-quiz"]
        XCTAssertTrue(start.waitForExistence(timeout: 8), "Today should offer the quiz action in the navigation bar")
        capture("01 Today")
        start.tap()

        let reveal = app.buttons["Reveal answer"]
        XCTAssertTrue(reveal.waitForExistence(timeout: 5), "The first card should be ready to reveal")
        capture("02 Recognition front")
        reveal.tap()

        let dontKnow = app.buttons["Don’t know"]
        XCTAssertTrue(dontKnow.waitForExistence(timeout: 3), "Both recall decisions should appear after reveal")
        XCTAssertTrue(app.buttons["Know"].exists)
        capture("03 Recognition revealed")
        dontKnow.tap()

        XCTAssertTrue(reveal.waitForExistence(timeout: 3), "The failed card should recycle after the remaining queue")
        capture("04 Next card after failure")

        var safetyCount = 0
        while reveal.waitForExistence(timeout: 2), safetyCount < 20 {
            reveal.tap()
            let know = app.buttons["Know"]
            XCTAssertTrue(know.waitForExistence(timeout: 2))
            know.tap()
            safetyCount += 1
        }

        XCTAssertTrue(app.staticTexts["6 of 10"].waitForExistence(timeout: 5), "Completing the daily quiz should return to Today")
        XCTAssertFalse(app.buttons["Next Round"].exists)
        XCTAssertTrue(app.buttons["daily-study-start-quiz"].exists, "The top action should remain Quiz")
        for _ in 0..<4 {
            let next = app.buttons["daily-study-next"]
            XCTAssertTrue(next.waitForExistence(timeout: 4), "The learner should be able to reach the end of the expanded set")
            next.tap()
        }
        XCTAssertTrue(app.buttons["daily-study-learn-more"].exists)
        capture("05 Practice complete")

        app.buttons["daily-study-learn-more"].tap()
        XCTAssertTrue(app.staticTexts["11 of 15"].waitForExistence(timeout: 5), "Learn More should append five words and start on the first new word")
        XCTAssertTrue(app.staticTexts["Today’s words"].exists)
    }

    func testTypedProductionShowsPreciseCorrection() throws {
        app.terminate()
        app.launchArguments.append("--ui-testing-recall")
        app.launch()

        completeDailyLearning()
        let start = app.buttons["daily-study-start-quiz"]
        XCTAssertTrue(start.waitForExistence(timeout: 8))
        start.tap()

        let field = app.textFields["Type the word"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "A production card should require a typed answer")
        field.tap()
        field.typeText("definitely wrong")
        app.buttons["Check"].tap()

        XCTAssertTrue(app.staticTexts["Not quite"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'You wrote:'")).firstMatch.exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Expected:'")).firstMatch.exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'return tomorrow'")).firstMatch.exists)
        XCTAssertTrue(app.buttons["Continue"].exists)
        capture("06 Typed production correction")
    }

    func testRecallCanRevealAnswer() throws {
        app.terminate()
        app.launchArguments.append("--ui-testing-recall")
        app.launch()

        completeDailyLearning()
        let start = app.buttons["daily-study-start-quiz"]
        XCTAssertTrue(start.waitForExistence(timeout: 8))
        start.tap()

        let keyboardDone = app.keyboards.buttons["done"]
        if keyboardDone.waitForExistence(timeout: 2) {
            keyboardDone.tap()
        }

        let reveal = app.buttons["Reveal answer"]
        XCTAssertTrue(reveal.waitForExistence(timeout: 5), "A recall card should offer a reveal path below Check")
        capture("07 Recall reveal action")
        reveal.tap()

        XCTAssertTrue(app.staticTexts["Answer revealed"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'return tomorrow'")).firstMatch.exists)
        XCTAssertTrue(app.buttons["Continue"].exists)
    }

    func testWordDetailKeepsLearningContentFirst() throws {
        let wordsTab = app.tabBars.buttons["Words"]
        XCTAssertTrue(wordsTab.waitForExistence(timeout: 8))
        wordsTab.tap()

#if DEBUG
        let dictionary = app.segmentedControls.buttons["Dictionary"]
        XCTAssertTrue(dictionary.waitForExistence(timeout: 5), "Debug Words UI should expose Dictionary")
        dictionary.tap()
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 5), "Debug Dictionary should show bundled offline entries")
#endif

        let upcoming = app.segmentedControls.buttons["Upcoming"]
        XCTAssertTrue(upcoming.waitForExistence(timeout: 5))
        upcoming.tap()

        let firstWord = app.cells.firstMatch
        XCTAssertTrue(firstWord.waitForExistence(timeout: 5))
        firstWord.tap()

        XCTAssertTrue(app.staticTexts["MEANINGS"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["MEMORY"].exists)
        XCTAssertFalse(app.staticTexts["DIFFICULTY"].exists)
        XCTAssertFalse(app.staticTexts["CARD DIFFICULTY"].exists)
        XCTAssertFalse(app.buttons["Study this word"].exists)
        capture("08 Simplified word detail")
    }

    func testHistoryAndMyWordsExposeTheCompletedDailySet() throws {
        completeDailyLearning()

        let words = app.tabBars.buttons["Words"]
        words.tap()
        XCTAssertTrue(app.buttons["word-filter-all"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["word-filter-all"].label.contains("10"))

        let history = app.tabBars.buttons["History"]
        XCTAssertTrue(history.waitForExistence(timeout: 5))
        history.tap()
        XCTAssertTrue(app.navigationBars["Study history"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Words studied"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Study this word"].exists)
        XCTAssertFalse(app.staticTexts["FIRST LEARNED"].exists)
        XCTAssertFalse(app.staticTexts["REVIEWED"].exists)
        XCTAssertTrue(app.buttons["history-relearn"].exists)
        XCTAssertFalse(app.buttons["history-practice"].exists)

        app.buttons["history-relearn"].tap()
        XCTAssertTrue(app.staticTexts["1 of 5"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["No words to review"].exists)
        for _ in 0..<4 {
            XCTAssertTrue(app.buttons["daily-study-next"].waitForExistence(timeout: 3))
            app.buttons["daily-study-next"].tap()
        }
        XCTAssertTrue(app.buttons["daily-study-finish"].waitForExistence(timeout: 3))
        app.buttons["daily-study-finish"].tap()
        XCTAssertFalse(app.buttons["history-practice"].exists)
    }

    private func completeDailyLearning() {
        let count = app.staticTexts["daily-study-count"]
        XCTAssertTrue(count.waitForExistence(timeout: 15), "Today should open in the daily learning mode")

        XCTAssertTrue(app.buttons["daily-study-start-quiz"].waitForExistence(timeout: 5), "The quiz button should be available from the start of Today")

        let pronunciation = app.buttons["daily-study-pronunciation"]
        XCTAssertTrue(pronunciation.waitForExistence(timeout: 5), "Each learning card should expose pronunciation")
        XCTAssertTrue(pronunciation.isHittable)
        pronunciation.tap()

        for _ in 0..<4 {
            let next = app.buttons["daily-study-next"]
            XCTAssertTrue(next.waitForExistence(timeout: 4), "The learner should be able to move to the next card")
            next.tap()
        }

        let learnMore = app.buttons["daily-study-learn-more"]
        XCTAssertTrue(learnMore.waitForExistence(timeout: 4), "The final card should show Learn More")
        learnMore.tap()
        XCTAssertTrue(app.staticTexts["6 of 10"].waitForExistence(timeout: 5), "The first Learn More should append five words")
        XCTAssertTrue(app.buttons["daily-study-start-quiz"].waitForExistence(timeout: 5))
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
