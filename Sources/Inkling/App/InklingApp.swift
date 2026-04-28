import SwiftUI
import AppKit

@main
struct InklingApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        // We need at least one Scene, but we don't want a SwiftUI Settings
        // window OR an auto-bound ⌘+, menu item — that would intercept the
        // shortcut before our InterceptingTextView keyDown ever sees it.
        // Replacing the .appSettings group with an empty body removes the
        // menu entry entirely, freeing ⌘+, to reach the capture panel.
        Settings { EmptyView() }
            .commands {
                CommandGroup(replacing: .appSettings) { }
            }
    }
}
