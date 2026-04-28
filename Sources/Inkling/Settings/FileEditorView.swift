import SwiftUI

struct FileEditorView: View {
    @Binding var file: TrackedFile
    var onDelete: () -> Void
    var onPickFile: () -> Void
    @ObservedObject var prefs: Preferences

    private var isInVault: Bool {
        ObsidianService.detectVault(for: file.resolvedURL) != nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                groupHeader("File")
                fileSection
                groupHeader("Capture")
                captureSection
                groupHeader("Section target")
                sectionTargetSection
                groupHeader("Format")
                formatSection
                groupHeader("Obsidian")
                obsidianSection
                deleteRow
            }
            .padding(20)
        }
    }

    private var sectionTargetSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            let headings = MarkdownReader.headings(at: file.resolvedURL)
            HStack {
                Text("Append under").foregroundStyle(.secondary)
                Picker("", selection: Binding(
                    get: { file.targetSection ?? "" },
                    set: { file.targetSection = $0.isEmpty ? nil : $0 }
                )) {
                    Text("End of file").tag("")
                    if !headings.isEmpty {
                        Divider()
                        ForEach(headings) { h in
                            Text(h.indentedLabel).tag(h.title)
                        }
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 360)
                Spacer()
            }
            if headings.isEmpty {
                Text("No headings found in this file yet.")
                    .font(.caption).foregroundStyle(InklingTheme.tertiaryText)
            } else {
                Text("New entries will land at the end of this section, before the next heading of equal or higher level.")
                    .font(.caption).foregroundStyle(InklingTheme.tertiaryText)
            }
        }
    }

    private var fileSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                TextField("Path", text: $file.path)
                    .textFieldStyle(.roundedBorder)
                Button("Choose…") { onPickFile() }
            }
            HStack {
                Text("Alias").foregroundStyle(.secondary)
                TextField("Daily log", text: $file.alias)
                    .textFieldStyle(.roundedBorder)
            }
            if isInVault {
                Label("Inside Obsidian vault", systemImage: "book.closed")
                    .foregroundStyle(.purple)
                    .font(.caption)
            }
        }
    }

    private var captureSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HotkeyRecorder(hotkey: $file.hotkey, label: "Open with")
                Spacer()
            }
            Text("⌘↩ appends, ⌘⇧↩ prepends, ⌘⌥↩ appends and opens, ⌘O opens.")
                .font(.caption).foregroundStyle(InklingTheme.tertiaryText)
        }
    }

    private var formatSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Mode").foregroundStyle(.secondary)
                Picker("", selection: $file.mode) {
                    ForEach(TrackedFile.Mode.allCases) { Text($0.label).tag($0) }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 280)
                .onChange(of: file.mode) { _, new in
                    if file.template.isEmpty || isDefaultTemplate(file.template) {
                        file.template = new.defaultTemplate
                    }
                }
                Spacer()
            }
            HStack(alignment: .top) {
                Text("Template").foregroundStyle(.secondary).padding(.top, 4)
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Template", text: $file.template)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                    Text("Variables: {{text}} {{date}} {{time}} {{datetime}} {{week}} {{alias}}")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }
            Toggle("Prefix entries with timestamp", isOn: $file.includeTimestamp)
        }
    }

    private var obsidianSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !ObsidianService.isInstalled {
                Text("Obsidian.app not installed — Inkling will use direct file writes.")
                    .font(.caption).foregroundStyle(InklingTheme.secondaryText)
            } else if !isInVault {
                Text("This file isn't inside an Obsidian vault — Inkling will use direct file writes.")
                    .font(.caption).foregroundStyle(InklingTheme.secondaryText)
            } else {
                Text("This file lives inside an Obsidian vault. Inkling will route writes through obsidian-cli when Obsidian is running, otherwise it falls back to a direct file write.")
                    .font(.caption).foregroundStyle(InklingTheme.secondaryText)
            }
        }
    }

    private var deleteRow: some View {
        HStack {
            Spacer()
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Remove file", systemImage: "trash")
            }
        }
        .padding(.top, 12)
    }

    private func groupHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.tertiary)
            .padding(.bottom, -6)
    }

    private func isDefaultTemplate(_ t: String) -> Bool {
        TrackedFile.Mode.allCases.contains { $0.defaultTemplate == t }
    }
}
