import SwiftUI

@main
struct InklingApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Settings {
            SettingsView(store: FileStore.shared, prefs: Preferences.shared)
                .frame(minWidth: 780, minHeight: 520)
        }
    }
}
