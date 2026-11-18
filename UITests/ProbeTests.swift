import XCTest

/// RITMO Dev as a Home Screen app on a simulated iPhone 16 Pro: dock → New food → back, twice.
final class ProbeTests: SimTestCase {
    let url = URL(string: ProcessInfo.processInfo.environment["PROBE_URL"] ?? "https://preview.ritmoapp.pages.dev/")!

    func testProbe() throws {
        log("screen \(XCUIScreen.main.screenshot().image.size) url \(url)")

        addToHomeScreen(url, pageTitle: "RITMO", tag: "ritmo")
        guard openIcon("RITMO Dev", tag: "ritmo") else { saveLog(); XCTFail("RITMO Dev icon not found"); return }
        sleep(3)
        let app = web
        log("webapp state \(app.state.rawValue)")

        // 4. The owner's flow: dock → New food → back (twice), close the dock, open it again.
        for round in 1...2 {
            log("round \(round)")
            tap("Log ", in: app, timeout: 6)          // "Log snack" (meal name changes with the time of day)
            sleep(3); keep("dock-\(round)")
            tap("New food", in: app, timeout: 6)
            sleep(3); keep("newfood-\(round)")
            tap("Close", in: app, timeout: 3, orAt: CGPoint(x: 359, y: 112))   // the New food ✕
            sleep(3); keep("back-\(round)")
            tap("New food", in: app, timeout: 6)
            sleep(3); keep("newfood-again-\(round)")
            tap("Close", in: app, timeout: 3, orAt: CGPoint(x: 359, y: 112))
            sleep(3); keep("back-again-\(round)")
            tap("Close", in: app, timeout: 3, orAt: CGPoint(x: 359, y: 207))   // the dock ✕
            sleep(3); keep("dock-closed-\(round)")
        }
        saveLog()
    }
}
