import XCTest

/// Can a Home Screen web app on iOS 27.2 draw under the clock, and with what clock colour?
/// Uses the local test page (pages/index.html, served by the runner on localhost:8000):
///   SB default — apple-mobile-web-app-status-bar-style "default" (what RITMO uses)
///   SB bt      — "black-translucent" (the page draws under the clock)
/// Then: an app installed as default is switched to black-translucent from inside it
/// (stored setting + reload, then a full relaunch), to see whether an installed app picks it up.
final class StatusBarTests: SimTestCase {
    let base = "http://localhost:8000/"

    func dimCycle(_ tag: String) {
        tap("Dim", in: web, timeout: 4, orAt: CGPoint(x: 201, y: 547))
        usleep(150_000); keep("\(tag)-dim-mid")
        sleep(2); keep("\(tag)-dim-on")
        tap("Dim", in: web, timeout: 4, orAt: CGPoint(x: 201, y: 547))
        sleep(2); keep("\(tag)-dim-off")
    }

    func testStatusBar() throws {
        log("screen \(XCUIScreen.main.screenshot().image.size)")
        addToHomeScreen(URL(string: base)!, pageTitle: "localhost", tag: "def")
        if openIcon("SB default", tag: "def") {
            sleep(2); keep("def-readings"); dimCycle("def")
            // switch the installed default app to black-translucent: reload, then a full relaunch
            tap("Use translucent", in: web, timeout: 4, orAt: CGPoint(x: 110, y: 627))
            sleep(4); keep("def-switched-reload")
            web.terminate(); sleep(2)
            if openIcon("SB default", tag: "def-relaunch") {
                sleep(2); keep("def-switched-relaunch"); dimCycle("def-switched")
                // dark content under the clock: does the clock turn light?
                tap("Dark top", in: web, timeout: 4); sleep(2); keep("def-switched-dark-top")
                dimCycle("def-switched-dark")
                tap("Dark top", in: web, timeout: 4); sleep(2); keep("def-switched-light-again")
                // and back to default after a relaunch
                tap("Use default", in: web, timeout: 4); sleep(3)
                web.terminate(); sleep(2)
                if openIcon("SB default", tag: "def-back") { sleep(2); keep("def-back-to-default") }
            }
        }
        saveLog()
    }
}
