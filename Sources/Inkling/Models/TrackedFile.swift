import Foundation

struct TrackedFile: Identifiable, Codable, Hashable {
    enum Mode: String, Codable, CaseIterable, Identifiable {
        case plain, todo, heading
        var id: String { rawValue }
        var label: String {
            switch self {
            case .plain: return "Plain"
            case .todo: return "Todo"
            case .heading: return "Heading"
            }
        }
        var defaultTemplate: String {
            switch self {
            case .plain: return "{{text}}"
            case .todo: return "- [ ] {{text}}"
            case .heading: return "## {{text}}"
            }
        }
    }

    enum Position: String, Codable, CaseIterable, Identifiable {
        case append, prepend
        var id: String { rawValue }
        var label: String { self == .append ? "Append" : "Prepend" }
    }

    var id: UUID
    var alias: String
    var path: String
    var bookmarkData: Data?
    var hotkey: Hotkey?
    var mode: Mode
    var template: String
    var defaultPosition: Position
    var routeWritesThroughObsidian: Bool
    var includeTimestamp: Bool
    /// Heading text (without leading `#`s) where new entries should land.
    /// `nil` means write at end-of-file (or beginning, if defaultPosition == .prepend).
    var targetSection: String?
    var addedAt: Date

    init(
        id: UUID = UUID(),
        alias: String,
        path: String,
        bookmarkData: Data? = nil,
        hotkey: Hotkey? = nil,
        mode: Mode = .plain,
        template: String? = nil,
        defaultPosition: Position = .append,
        routeWritesThroughObsidian: Bool = false,
        includeTimestamp: Bool = false,
        targetSection: String? = nil,
        addedAt: Date = Date()
    ) {
        self.id = id
        self.alias = alias
        self.path = path
        self.bookmarkData = bookmarkData
        self.hotkey = hotkey
        self.mode = mode
        self.template = template ?? mode.defaultTemplate
        self.defaultPosition = defaultPosition
        self.routeWritesThroughObsidian = routeWritesThroughObsidian
        self.includeTimestamp = includeTimestamp
        self.targetSection = targetSection
        self.addedAt = addedAt
    }

    var resolvedURL: URL {
        URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
    }

    var displayName: String {
        alias.isEmpty ? resolvedURL.lastPathComponent : alias
    }
}
