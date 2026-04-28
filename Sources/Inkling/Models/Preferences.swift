import Foundation
import Combine

@MainActor
final class Preferences: ObservableObject {
    static let shared = Preferences()

    private let defaults = UserDefaults.standard

    @Published var globalHotkey: Hotkey? {
        didSet { persist(globalHotkey, key: "Inkling.globalHotkey") }
    }

    @Published var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: "Inkling.launchAtLogin") }
    }

    @Published var playSoundOnSave: Bool {
        didSet { defaults.set(playSoundOnSave, forKey: "Inkling.playSoundOnSave") }
    }

    @Published var preferObsidianForOpen: Bool {
        didSet { defaults.set(preferObsidianForOpen, forKey: "Inkling.preferObsidianForOpen") }
    }

    @Published var preferObsidianForWrite: Bool {
        didSet { defaults.set(preferObsidianForWrite, forKey: "Inkling.preferObsidianForWrite") }
    }

    @Published var defaultTimestampFormat: String {
        didSet { defaults.set(defaultTimestampFormat, forKey: "Inkling.timestampFormat") }
    }

    @Published var hotCorner: HotCornerService.Corner {
        didSet { defaults.set(hotCorner.rawValue, forKey: "Inkling.hotCorner") }
    }

    @Published var hotCornerDwell: Double {
        didSet { defaults.set(hotCornerDwell, forKey: "Inkling.hotCornerDwell") }
    }

    private init() {
        self.launchAtLogin = defaults.object(forKey: "Inkling.launchAtLogin") as? Bool ?? false
        self.playSoundOnSave = defaults.object(forKey: "Inkling.playSoundOnSave") as? Bool ?? true
        self.preferObsidianForOpen = defaults.object(forKey: "Inkling.preferObsidianForOpen") as? Bool ?? true
        self.preferObsidianForWrite = defaults.object(forKey: "Inkling.preferObsidianForWrite") as? Bool ?? true
        self.defaultTimestampFormat = defaults.string(forKey: "Inkling.timestampFormat") ?? "yyyy-MM-dd HH:mm"

        if let raw = defaults.string(forKey: "Inkling.hotCorner"),
           let corner = HotCornerService.Corner(rawValue: raw) {
            self.hotCorner = corner
        } else {
            self.hotCorner = .none
        }
        let dwell = defaults.double(forKey: "Inkling.hotCornerDwell")
        self.hotCornerDwell = dwell > 0 ? dwell : 0.25

        if let data = defaults.data(forKey: "Inkling.globalHotkey"),
           let hk = try? JSONDecoder().decode(Hotkey.self, from: data) {
            self.globalHotkey = hk
        } else {
            self.globalHotkey = nil
        }
    }

    private func persist<T: Encodable>(_ value: T?, key: String) {
        if let value, let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}
