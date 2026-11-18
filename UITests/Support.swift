import XCTest

/// Shared helpers for the cloud iPhone tests: logging with timestamps, screenshots, finding and
/// tapping things, adding a page to the Home Screen and opening it.
class SimTestCase: XCTestCase {
    let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    let web = XCUIApplication(bundleIdentifier: "com.apple.webapp")
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

    /// True when the area below the status bar is one flat colour (nothing drawn yet).
    func screenLooksBlank() -> Bool {
        guard let cg = XCUIScreen.main.screenshot().image.cgImage,
              let data = cg.dataProvider?.data, let p = CFDataGetBytePtr(data) else { return false }
        let bpr = cg.bytesPerRow, bpp = cg.bitsPerPixel / 8
        func px(_ x: Int, _ y: Int) -> [UInt8] { let o = y * bpr + x * bpp; return [p[o], p[o+1], p[o+2]] }
        let ref = px(cg.width / 2, cg.height / 2)
        for fy in stride(from: 0.15, through: 0.9, by: 0.05) {
            for fx in stride(from: 0.05, through: 0.95, by: 0.1) {
                let c = px(Int(Double(cg.width) * fx), Int(Double(cg.height) * fy))
                if zip(c, ref).contains(where: { abs(Int($0) - Int($1)) > 12 }) { return false }
            }
        }
        return true
    }

    // MARK: finding things

    /// Any element whose label starts with `text`, in the given app, that can be tapped.
    func element(_ text: String, in app: XCUIApplication, timeout: TimeInterval = 6) -> XCUIElement? {
        let p = NSPredicate(format: "label BEGINSWITH[c] %@", text)
        let q = (app === web ? app.buttons : app.descendants(matching: .any)).matching(p)
        let end = Date().addingTimeInterval(timeout)
        repeat {
            let screen = CGRect(x: 0, y: 0, width: 402, height: 874)
            // On screen and of real size; isHittable can abort the test on some labels ("activation point invalid").
            let all = q.allElementsBoundByIndex.filter { $0.exists && $0.frame.width > 4 && $0.frame.height > 4 && screen.contains(CGPoint(x: $0.frame.midX, y: $0.frame.midY)) }
            if let best = all.max(by: { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }) { return best }  // a row beats a small icon with the same label
            usleep(250_000)
        } while Date() < end
        return nil
    }

    @discardableResult
    func tap(_ text: String, in app: XCUIApplication, timeout: TimeInterval = 6, orAt point: CGPoint? = nil) -> Bool {
        if let e = element(text, in: app, timeout: timeout) {
            log("tap '\(text)' at \(e.frame)")
            e.tap()
            return true
        }
        if let point { tapPoint(point.x, point.y, "'\(text)' by position"); return true }
        log("NOT FOUND '\(text)'")
        return false
    }

    /// Tap a screen point (points, portrait), whatever app is in front.
    func tapPoint(_ x: CGFloat, _ y: CGFloat, _ why: String) {
        log("tap point (\(x),\(y)) \(why)")
        springboard.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: y)).tap()
    }

    // MARK: the probe


    // MARK: Home Screen apps

    /// Safari → Page Menu → Share → Add to Home Screen → Add. `pageTitle` is text in the address bar once loaded.
    func addToHomeScreen(_ page: URL, pageTitle: String, tag: String) {
        safari.launch()
        XCUIDevice.shared.system.open(page)
        let loaded = Date().addingTimeInterval(45)
        while Date() < loaded && safari.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] %@ OR value CONTAINS[c] %@", pageTitle, pageTitle)).count == 0 { usleep(500_000) }
        sleep(3)
        keep("\(tag)-safari", tree: safari)
        for t in ["Continue", "Not Now", "Close"] { if let e = element(t, in: safari, timeout: 1) { log("dismiss '\(t)'"); e.tap() } }
        var shared = tap("Share", in: safari, timeout: 4)
        if !shared {
            for t in ["Page Menu", "More", "Tab overview"] where !shared {
                if tap(t, in: safari, timeout: 2) { sleep(1); shared = tap("Share", in: safari, timeout: 3) }
            }
        }
        sleep(2)
        // The share sheet can open collapsed; expand it first.
        if let more = element("View More", in: safari, timeout: 2) { log("expand share sheet"); more.tap(); sleep(1) }
        if !tap("Add to Home Screen", in: safari, timeout: 3) {
            safari.swipeUp(); sleep(1)
            tap("Add to Home Screen", in: safari, timeout: 3)
        }
        let addButton = safari.navigationBars.buttons["Add"].exists ? safari.navigationBars.buttons["Add"] : safari.buttons["Add"]
        let ready = Date().addingTimeInterval(40)
        while Date() < ready && !(addButton.exists && addButton.isEnabled) { usleep(500_000) }
        keep("\(tag)-add-screen", tree: safari)
        if addButton.exists && addButton.isEnabled { addButton.tap(); log("tapped Add (\(tag))") } else { log("Add never enabled (\(tag))") }
        sleep(4)
    }

    /// Home Screen → swipe to the page holding `name` → tap it → wait (pixels only) for the first paint.
    @discardableResult
    func openIcon(_ name: String, tag: String) -> Bool {
        XCUIDevice.shared.press(.home)
        sleep(2)
        let icon = springboard.icons[name]
        for _ in 0..<5 where icon.exists && !icon.isHittable { springboard.swipeLeft(); sleep(1) }
        log("icon \(name) exists \(icon.exists) hittable \(icon.isHittable)")
        guard icon.exists && icon.isHittable else { keep("\(tag)-no-icon", tree: springboard); return false }
        icon.tap()
        let opened = Date()
        sleep(3)
        var painted = false
        while Date().timeIntervalSince(opened) < 420 { if !screenLooksBlank() { painted = true; break }; sleep(2) }
        log("\(name) first paint \(painted) after \(String(format: "%.1f", Date().timeIntervalSince(opened)))s")
        sleep(2)
        keep("\(tag)-open")
        return painted
    }
}
