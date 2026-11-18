import SwiftUI

// Empty host app: XCUITest needs one, but the tests drive Safari, the Home Screen and RITMO Dev.
@main
struct HostApp: App {
    var body: some Scene { WindowGroup { Text("ritmo-sim host") } }
}
