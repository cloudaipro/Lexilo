import XCTest

final class LexiloPracticeFlowTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["--ui-testing-reset", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
    }

    func testFullPracticeFlow() throws {
        let pronunciation = app.buttons["featured-word-pronunciation"]
        XCTAssertTrue(pronunciation.waitForExistence(timeout: 8), "The featured word should expose a pronunciation control")
        XCTAssertTrue(pronunciation.isHittable, "The pronunciation control should be tappable")
        pronunciation.tap()

        let start = app.buttons["Start practice"]
        XCTAssertTrue(start.waitForExistence(timeout: 8), "Today should offer the primary practice action")
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

        XCTAssertTrue(app.staticTexts["Round complete"].waitForExistence(timeout: 5), "The session should reach completion")
        XCTAssertTrue(app.staticTexts["5 words practised today. Add another round or repeat today’s set."].exists)
        XCTAssertTrue(app.buttons["Next Round"].exists)
        XCTAssertTrue(app.buttons["Practice Again"].exists)
        XCTAssertTrue(app.buttons["Back to Today"].exists)
        capture("05 Practice complete")
        let practiceAgain = app.buttons["Practice Again"]
        practiceAgain.tap()
        XCTAssertTrue(reveal.waitForExistence(timeout: 5), "Practice Again should replay the cumulative set of words practised today")
        XCTAssertTrue(app.staticTexts["1 of 5"].exists, "Practice Again should contain the five distinct words in today's set")
    }

    func testTypedProductionShowsPreciseCorrection() throws {
        app.terminate()
        app.launchArguments.append("--ui-testing-recall")
        app.launch()

        let start = app.buttons["Start practice"]
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

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
