import SwiftUI

@main
struct InklingApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        // Inkling has no traditional windows — settings live in the menu-bar dropdown.
        // The Settings scene must exist (App protocol requires at least one scene)
        // but is intentionally empty; ⌘+, will land on the EmptyView and we never
        // open it from anywhere in our code.
        Settings {
            EmptyView()
        }
    }
}
