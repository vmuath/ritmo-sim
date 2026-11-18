import XCTest

/// Can a Home Screen web app on iOS 27.2 draw under the clock, and with what clock colour?
/// Uses the local test page (pages/index.html, served by the runner on localhost:8000):
///   SB default — apple-mobile-web-app-status-bar-style "default" (what RITMO uses)
///   SB bt      — "black-translucent" (the page draws under the clock)
/// Then: an app installed as default is switched to black-translucent from inside it
/// (stored setting + reload, then a full relaunch), to see whether an installed app picks it up.
final class StatusBarTests: SimTestCase {
    let base = "http://localhost:8000/"

    /// Tap a button on the test page by label; if the web app can't be queried (after a relaunch
    /// XCTest sometimes reports it as not running), tap its position. `y` is in page coordinates;
    /// `top` is where the page starts on screen (62 below the clock, 0 when drawing under it).
    func pageTap(_ label: String, x: CGFloat, y: CGFloat, top: CGFloat) {
        if web.state == .runningForeground, tap(label, in: web, timeout: 3) { return }
        tapPoint(x, y + top, "'\(label)' by position")
    }

    func dimCycle(_ tag: String, top: CGFloat) {
        pageTap("Dim", x: 201, y: 546, top: top)
        usleep(150_000); keep("\(tag)-dim-mid")
        sleep(2); keep("\(tag)-dim-on")
        pageTap("Dim", x: 201, y: 546, top: top)
        sleep(2); keep("\(tag)-dim-off")
    }

    func testStatusBar() throws {
        log("screen \(XCUIScreen.main.screenshot().image.size)")
        addToHomeScreen(URL(string: base)!, pageTitle: "localhost", tag: "def")
        if openIcon("SB default", tag: "def") {
            sleep(2); keep("def-readings"); dimCycle("def", top: 62)
            // switch the installed default app to black-translucent: reload, then a full relaunch
            pageTap("Use translucent", x: 110, y: 626, top: 62)
            sleep(4); keep("def-switched-reload")
            web.terminate(); sleep(2)
            if openIcon("SB default", tag: "def-relaunch") {
                sleep(2); keep("def-switched-relaunch"); dimCycle("def-switched", top: 0)
                // dark content under the clock: does the clock turn light?
                pageTap("Dark top", x: 201, y: 706, top: 0); sleep(2); keep("def-switched-dark-top")
                dimCycle("def-switched-dark", top: 0)
                pageTap("Dark top", x: 201, y: 706, top: 0); sleep(2); keep("def-switched-light-again")
                // and back to default after a relaunch
                pageTap("Use default", x: 290, y: 626, top: 0); sleep(3)
                web.terminate(); sleep(2)
                if openIcon("SB default", tag: "def-back") { sleep(2); keep("def-back-to-default") }
            }
        }
        saveLog()
    }
}
