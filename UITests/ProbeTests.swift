import XCTest

/// Probe 1: can a simulated iPhone add RITMO Dev to its Home Screen, open it, and run the
/// dock → New food → back flow with real (simulated) touches, while the workflow records video?
/// Every step leaves a screenshot, the accessibility tree and a timestamped log line, so a failed
/// step still tells us what the screen looked like.
final class ProbeTests: XCTestCase {
    let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    let url = URL(string: ProcessInfo.processInfo.environment["PROBE_URL"] ?? "https://preview.ritmoapp.pages.dev/")!
    var lines: [String] = []
    var step = 0

    override func setUp() { continueAfterFailure = true }

    // MARK: logging

    func log(_ s: String) {
        let t = String(format: "%.3f", Date().timeIntervalSince1970)
        lines.append("\(t) \(s)")
        print("PROBE \(t) \(s)")
    }

    func keep(_ name: String, tree: XCUIApplication? = nil) {
        step += 1
        let label = String(format: "%02d-%@", step, name)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = label + ".png"; shot.lifetime = .keepAlways; add(shot)
        if let tree {
            let text = XCTAttachment(string: tree.debugDescription)
            text.name = label + ".txt"; text.lifetime = .keepAlways; add(text)
        }
        log("kept \(label)")
    }

    func saveLog() {
        let a = XCTAttachment(string: lines.joined(separator: "\n"))
        a.name = "zz-log.txt"; a.lifetime = .keepAlways; add(a)
    }

    // MARK: finding things

    /// Any element whose label starts with `text`, in the given app, that can be tapped.
    func element(_ text: String, in app: XCUIApplication, timeout: TimeInterval = 6) -> XCUIElement? {
        let p = NSPredicate(format: "label BEGINSWITH[c] %@", text)
        let q = app.descendants(matching: .any).matching(p)
        let end = Date().addingTimeInterval(timeout)
        repeat {
            let all = q.allElementsBoundByIndex.filter { $0.exists && $0.isHittable }
            if let last = all.last { return last }
            usleep(250_000)
        } while Date() < end
        return nil
    }

    @discardableResult
    func tap(_ text: String, in app: XCUIApplication, timeout: TimeInterval = 6) -> Bool {
        if let e = element(text, in: app, timeout: timeout) {
            log("tap '\(text)' at \(e.frame)")
            e.tap()
            return true
        }
        log("NOT FOUND '\(text)'")
        return false
    }

    /// Tap a screen point (points, portrait), whatever app is in front.
    func tapPoint(_ x: CGFloat, _ y: CGFloat, _ why: String) {
        log("tap point (\(x),\(y)) \(why)")
        springboard.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: y)).tap()
    }

    // MARK: the probe

    func testProbe() throws {
        log("screen \(XCUIScreen.main.screenshot().image.size) url \(url)")

        // 1. Safari, the preview page.
        safari.launch()
        XCUIDevice.shared.system.open(url)
        // Wait for the page itself (its title in the address bar), not a fixed time.
        let loaded = Date().addingTimeInterval(45)
        while Date() < loaded && safari.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] 'RITMO' OR value CONTAINS[c] 'RITMO'")).count == 0 { usleep(500_000) }
        sleep(3)
        keep("safari", tree: safari)
        for t in ["Continue", "Not Now", "Close"] { if let e = element(t, in: safari, timeout: 1) { log("dismiss '\(t)'"); e.tap() } }

        // 2. Share → Add to Home Screen → Add.
        var shared = tap("Share", in: safari, timeout: 4)
        if !shared {
            for t in ["Page Menu", "More", "Tab overview"] where !shared {
                if tap(t, in: safari, timeout: 2) { sleep(1); keep("menu-\(t)", tree: safari); shared = tap("Share", in: safari, timeout: 3) }
            }
        }
        sleep(2)
        keep("share-sheet", tree: safari)
        var added = tap("Add to Home Screen", in: safari, timeout: 3)
        if !added {
            safari.swipeUp(); sleep(1)
            keep("share-sheet-up", tree: safari)
            added = tap("Add to Home Screen", in: safari, timeout: 3)
        }
        // The Add screen loads the name and icon first; Add stays disabled until then.
        let addButton = safari.navigationBars.buttons["Add"].exists ? safari.navigationBars.buttons["Add"] : safari.buttons["Add"]
        let ready = Date().addingTimeInterval(40)
        while Date() < ready && !(addButton.exists && addButton.isEnabled) { usleep(500_000) }
        keep("add-screen", tree: safari)
        log("Add exists \(addButton.exists) enabled \(addButton.isEnabled)")
        if addButton.exists && addButton.isEnabled { addButton.tap(); log("tapped Add") } else { log("Add never enabled") }
        sleep(4)

        // 3. Home Screen → RITMO Dev.
        XCUIDevice.shared.press(.home)
        sleep(2)
        keep("home-screen", tree: springboard)
        // New icons land on a later Home Screen page: swipe until it is on screen.
        let icon = springboard.icons["RITMO Dev"]
        for _ in 0..<4 where icon.exists && !icon.isHittable { springboard.swipeLeft(); sleep(1) }
        log("icon exists \(icon.exists) hittable \(icon.isHittable)")
        guard tap("RITMO Dev", in: springboard, timeout: 8) else {
            keep("no-icon", tree: springboard); saveLog()
            XCTFail("RITMO Dev icon not found"); return
        }
        sleep(10)
        keep("ritmo-open", tree: springboard)

        // Which process holds the web app's elements? Log the candidates once.
        let candidates = ["com.apple.webapp", "com.apple.WebKit.WebContent", "com.apple.mobilesafari"]
        var app = springboard
        for id in candidates {
            let a = XCUIApplication(bundleIdentifier: id)
            log("candidate \(id) state \(a.state.rawValue)")
            if a.state == .runningForeground {
                let t = XCTAttachment(string: a.debugDescription); t.name = "tree-\(id).txt"; t.lifetime = .keepAlways; add(t)
                if a.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH[c] 'Log '")).count > 0 { app = a; log("using \(id)") }
            }
        }

        // 4. The owner's flow: dock → New food → back (twice), close the dock, open it again.
        for round in 1...2 {
            log("round \(round)")
            tap("Log ", in: app, timeout: 6)          // "Log snack" (meal name changes with the time of day)
            sleep(3); keep("dock-\(round)", tree: app)
            tap("New food", in: app, timeout: 6)
            sleep(3); keep("newfood-\(round)", tree: app)
            tap("Close", in: app, timeout: 6)         // the New food ✕
            sleep(3); keep("back-\(round)", tree: app)
            tap("New food", in: app, timeout: 6)
            sleep(3); keep("newfood-again-\(round)", tree: app)
            tap("Close", in: app, timeout: 6)
            sleep(3); keep("back-again-\(round)", tree: app)
            tap("Close", in: app, timeout: 6)         // the dock ✕
            sleep(3); keep("dock-closed-\(round)", tree: app)
        }
        saveLog()
    }
}
