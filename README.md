# Inkling

A macOS menu-bar app for jotting one line into the right file — from anywhere on your Mac, without leaving the app you're in.

You point Inkling at the few files you actually use (a daily log, a notes file, a running todo list, an Obsidian vault note), give each one a hotkey, and you're done. Hit the hotkey, type, press return — the line lands in the file.

## Features

- **Menu-bar capture panel** — translucent floating card with a single text input. ⎋ or ⌘W to dismiss, ⌘↩ to submit.
- **Per-file global hotkeys** — press a hotkey from anywhere; the panel opens pre-pointed at that file. Press the same hotkey again to dismiss; press a different file's hotkey to switch in place.
- **Hot-corner trigger** — shove the cursor into the corner of any screen to open the panel (configurable corner + dwell time). Mimics Apple Quick Note.
- **Obsidian integration** — auto-detects when a file lives inside a vault. Routes writes through the bundled `obsidian-cli` when Obsidian is running so the index updates instantly; falls back to a direct file write otherwise. `⌘O` / `⌘⇧↩` open the file in the right vault.
- **Slash commands and templates** — type `/` for a command palette inside the panel:
  - `/daily` `/meeting` `/idea` `/todo` `/now` `/date` — built-in templates with `{{date}}`, `{{datetime}}`, `{{week}}`, `{{alias}}` substitution.
  - `/open` `/settings` `/quit` `/dictate` `/section` `/undo` — actions.
- **Section targeting** — pick a heading per file in Settings; new entries land at the end of that section instead of end-of-file. Toggle on the fly via the section pill in the panel.
- **Image and file attachments** — paste an image or file URL, or drag-drop any file onto the panel. Inkling copies it into `<vault>/attachments/` (or `<note-dir>/attachments/`) and inserts a markdown link.
- **Recent entries peek** — the last 3 lines of the active file appear faintly under the input when you open the panel empty.
- **Per-mode templates** — Plain / Todo (`- [ ]`) / Heading (`##`) modes per file, each with its own template format.
- **System dictation** — `⌘\` triggers macOS dictation right in the capture text view.
- **Undo last write** — `/undo` reverses the last entry across any tracked file (last 25 in memory).
- **Light / dark adaptive** — uses `NSVisualEffectView` for a real translucent macOS panel that follows your system appearance.

## Keyboard shortcuts (in the capture panel)

| Shortcut | What it does |
| --- | --- |
| `↩` | Append the line to the file |
| `⌘↩` | Append (explicit) |
| `⌘⇧↩` | Append, then open the file |
| `⌘⌥↩` | Prepend (write at the top) |
| `⇧↩` / `⌥↩` | Insert a newline (multi-line capture) |
| `⌘O` | Open the file without writing |
| `⌘W` / `⎋` | Dismiss the panel |
| `⇥` | Open file switcher (or complete a slash command) |
| `⌘V` | Paste image / file as attachment |
| `⌘\` | Start macOS dictation |

## Requirements

- macOS 14 or later
- [Obsidian](https://obsidian.md) is optional but recommended for vault-aware writes; Inkling auto-detects `.obsidian/` and uses Obsidian's bundled CLI when running.

## Build from source

```bash
brew install xcodegen
git clone https://github.com/caezium/Inkling.git
cd Inkling
xcodegen generate
xcodebuild -project Inkling.xcodeproj -scheme Inkling -configuration Release \
  -derivedDataPath build build
open build/Build/Products/Release/Inkling.app
```

The app is unsigned. macOS Gatekeeper may show a warning on first launch — right-click the app, choose **Open**, then **Open** again.

## Project layout

```
Sources/Inkling/
├── App/            entry point, AppDelegate, status item, hotkey wiring
├── Capture/        floating panel, text view, switcher, section picker
├── Models/         TrackedFile, FileStore, Preferences
├── Services/       Obsidian CLI, file writer, slash commands, attachments,
│                   hot corner, write history, markdown reader, templates
├── Settings/       file editor, hotkey recorder, settings tabs
└── Shared/         theme, card background, hotkey type
```

## Status

Personal project; APIs and storage formats may change. Bug reports and PRs welcome.
