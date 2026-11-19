import XCTest

/// Which part of RITMO makes iOS paint the clock area flat while a sheet's dim fades? (19 Nov)
/// Each variant is served by the runner from pages/<name>/ (tools/variants.py) and installed as its own Home Screen app:
///   s1  SB static v5 (black-translucent; on the owner's phone every dim was followed in the same frame)
///   r1  RITMO Dev's build as served (black-translucent; on the phone the clock area steps)
///   r2  r1 without theme-color · r3 r1 without the manifest · r4 r1 without theme-color, manifest and touch icon
///   s2  s1 plus RITMO's theme-color and manifest
/// The run is screen-recorded; "SEG" lines mark each variant's dims in the video.
final class BisectTests: SimTestCase {
    let base = "http://localhost:8000/"

    func ritmoCycles(_ v: String) {
        for i in 1...2 {
            log("SEG \(v) dock-open \(i)")
            tap("Log snack", in: web, timeout: 6)
            sleep(3)
            if i == 1 { keep("\(v)-dock") }
            log("SEG \(v) dock-close \(i)")
            tap("Close", in: web, timeout: 3, orAt: CGPoint(x: 359, y: 207))
            sleep(3)
        }
    }

    func staticCycles(_ v: String) {
        for n in ["4", "2", "5"] {
            log("SEG \(v) dim \(n)")
            tap("Dim \(n)", in: web, timeout: 4)
            sleep(3)
        }
    }

    func run(_ v: String) {
        let ritmo = v.hasPrefix("r")
        addToHomeScreen(URL(string: base + v + "/")!, pageText: ritmo ? "Today" : "five dims", tag: v)
        guard openIcon("B \(v)", tag: v) else { log("SEG \(v) no icon"); return }
        sleep(4)
        keep("\(v)-ready")
        log("SEG \(v) start")
        if ritmo { ritmoCycles(v) } else { staticCycles(v) }
        log("SEG \(v) end")
        web.terminate()
        sleep(2)
    }

    func testBisect() throws {
        log("screen \(XCUIScreen.main.screenshot().image.size)")
        for v in ["s1", "r1", "r4", "r2", "r3", "s2"] { run(v) }
        saveLog()
    }
}
