import Foundation

/// Slash commands typed inside the capture panel. Two flavors:
/// - `.template`: replaces the input with a rendered template body, leaves cursor at end.
/// - `.action`: performs a side-effect (open settings, undo, etc.) instead of writing a note.
struct SlashCommand: Hashable {
    let name: String
    let summary: String
    let kind: Kind

    enum Kind: Hashable {
        case template(String)
        case action(Action)
    }

    enum Action: String, Hashable {
        case openSettings
        case openActiveFile
        case quit
        case undo
        case sectionPicker
        case dictate
    }
}

enum SlashRegistry {
    static let all: [SlashCommand] = [
        // Templates
        SlashCommand(
            name: "daily",
            summary: "Daily note skeleton",
            kind: .template("""
            ## Daily — {{date}}

            -
            """)
        ),
        SlashCommand(
            name: "meeting",
            summary: "Meeting notes skeleton",
            kind: .template("""
            ## Meeting — {{datetime}}

            **Attendees:**

            **Notes:**
            -
            """)
        ),
        SlashCommand(
            name: "idea",
            summary: "Timestamped idea",
            kind: .template("💡 {{datetime}} — ")
        ),
        SlashCommand(
            name: "todo",
            summary: "Checklist item",
            kind: .template("- [ ] ")
        ),
        SlashCommand(
            name: "now",
            summary: "Insert current datetime",
            kind: .template("{{datetime}} — ")
        ),
        SlashCommand(
            name: "date",
            summary: "Insert today's date",
            kind: .template("{{date}}")
        ),
        // Actions
        SlashCommand(name: "open", summary: "Open the active file", kind: .action(.openActiveFile)),
        SlashCommand(name: "settings", summary: "Open Inkling settings", kind: .action(.openSettings)),
        SlashCommand(name: "section", summary: "Pick a section to write to", kind: .action(.sectionPicker)),
        SlashCommand(name: "dictate", summary: "Start macOS dictation", kind: .action(.dictate)),
        SlashCommand(name: "undo", summary: "Undo the last write", kind: .action(.undo)),
        SlashCommand(name: "quit", summary: "Quit Inkling", kind: .action(.quit))
    ]

    /// Returns matches when the input is in command-mode (starts with `/`).
    /// `nil` means we are NOT in command-mode (don't show hints, don't intercept submit).
    static func suggestions(for input: String) -> [SlashCommand]? {
        guard input.hasPrefix("/") else { return nil }
        let query = String(input.dropFirst()).lowercased()
        let firstWord = query.split(separator: " ").first.map(String.init) ?? query
        if firstWord.isEmpty { return all }
        return all.filter { $0.name.lowercased().hasPrefix(firstWord) }
    }

    /// Returns the matching command if `input` is exactly `/<name>` (ignoring trailing whitespace).
    static func exactMatch(for input: String) -> SlashCommand? {
        guard input.hasPrefix("/") else { return nil }
        let body = String(input.dropFirst()).trimmingCharacters(in: .whitespaces).lowercased()
        return all.first { $0.name == body }
    }
}
