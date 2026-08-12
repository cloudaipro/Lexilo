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

        XCTAssertTrue(app.staticTexts["Practice complete"].waitForExistence(timeout: 5), "The session should reach completion")
        XCTAssertTrue(app.buttons["Back to Today"].exists)
        capture("05 Practice complete")
        app.buttons["Back to Today"].tap()
        XCTAssertTrue(app.staticTexts["today-greeting"].waitForExistence(timeout: 3))
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
