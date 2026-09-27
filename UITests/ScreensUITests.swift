import XCTest

/// Walks every screen against the mock server (ci/mock-server.mjs), in the
/// theme the workflow set, photographs it and holds it to LayoutChecks.
final class ScreensUITests: XCTestCase {
    var app: XCUIApplication!
    let server = ProcessInfo.processInfo.environment["TEST_SERVER"] ?? "http://127.0.0.1:8787"

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchEnvironment["DOCKAI_TEST_SERVER"] = server
        app.launch()
    }

    /// A screenshot kept with the results, then the layout rules.
    func shot(_ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
        LayoutChecks.check(app, screen: name, in: self)
    }

    /// Requests the mock server has answered so far.
    func calls() -> Int? {
        guard let url = URL(string: server + "/__requests"), let d = try? Data(contentsOf: url) else { return nil }
        return Int(String(decoding: d, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// A pull must reach the server; tried more than once, since a page that
    /// polls folds a pull into a poll in flight.
    func assertPullRefreshes(_ screen: String) {
        for _ in 0..<3 {
            guard let before = calls() else { return }
            let list = app.collectionViews.firstMatch
            list.coordinate(withNormalizedOffset: CGVector(dx: 0.06, dy: 0.1))
                .press(forDuration: 0.1, thenDragTo: list.coordinate(withNormalizedOffset: CGVector(dx: 0.06, dy: 0.85)),
                       withVelocity: .slow, thenHoldForDuration: 1.0)
            sleep(3)
            if let after = calls(), after > before { return }
        }
        XCTFail("[\(screen)] pull-to-refresh: pulling down asked the server for nothing, three times")
    }

    func testMain() {
        XCTAssertTrue(app.staticTexts["First item"].waitForExistence(timeout: 10), "[main] the list did not load")
        shot("main")
        assertPullRefreshes("main")
    }
}
