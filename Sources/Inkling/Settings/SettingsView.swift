import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var store: FileStore
    @ObservedObject var prefs: Preferences

    enum Section: String, CaseIterable, Identifiable {
        case files, general, about
        var id: String { rawValue }
        var label: String {
            switch self {
            case .files: return "Files"
            case .general: return "General"
            case .about: return "About"
            }
        }
        var icon: String {
            switch self {
            case .files: return "doc.text"
            case .general: return "gearshape"
            case .about: return "info.circle"
            }
        }
    }

    @State private var section: Section = .files
    @State private var selectedFileID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            sectionPicker
                .padding(.horizontal, 22)
                .padding(.top, 16)
                .padding(.bottom, 14)
            Divider().opacity(0.0001) // keep layout stable, no visible line
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(InklingTheme.cardBackground.ignoresSafeArea())
    }

    private var sectionPicker: some View {
        HStack(spacing: 6) {
            ForEach(Section.allCases) { s in
                Button {
                    section = s
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: s.icon).font(.system(size: 12, weight: .medium))
                        Text(s.label).font(.system(size: 13, weight: .medium))
                    }
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .foregroundStyle(section == s ? InklingTheme.primaryText : InklingTheme.secondaryText)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(section == s ? InklingTheme.pillFill : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch section {
        case .files: filesContent
        case .general: GeneralSettingsView(prefs: prefs)
        case .about: AboutView(store: store)
        }
    }

    // MARK: - Files

    private var filesContent: some View {
        HStack(spacing: 0) {
            fileSidebar
                .frame(width: 240)
            verticalDivider
            fileDetail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var fileSidebar: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(store.files) { file in
                        SidebarFileRow(
                            file: file,
                            selected: selectedFileID == file.id,
                            onTap: { selectedFileID = file.id }
                        )
                    }
                }
                .padding(.horizontal, 10).padding(.vertical, 10)
            }
            sidebarFooter
        }
        .background(InklingTheme.sidebarBackground)
    }

    private var sidebarFooter: some View {
        HStack(spacing: 6) {
            Button(action: pickFileToAdd) {
                Image(systemName: "plus").frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .help("Add file")
            Button(action: removeSelected) {
                Image(systemName: "minus").frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .disabled(selectedFileID == nil)
            .help("Remove file")
            Spacer()
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
    }

    private var verticalDivider: some View {
        Rectangle()
            .fill(InklingTheme.cardBorder)
            .frame(width: 0.5)
    }

    @ViewBuilder
    private var fileDetail: some View {
        if let id = selectedFileID, let binding = bindingFor(id: id) {
            FileEditorView(
                file: binding,
                onDelete: { remove(id: id) },
                onPickFile: { repickFile(for: id) },
                prefs: prefs
            )
        } else {
            VStack(spacing: 14) {
                Image(systemName: store.files.isEmpty ? "tray" : "doc.text")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(InklingTheme.tertiaryText)
                Text(store.files.isEmpty ? "No files yet" : "Select a file to edit")
                    .font(.system(size: 14))
                    .foregroundStyle(InklingTheme.secondaryText)
                if store.files.isEmpty {
                    Button("Add file…", action: pickFileToAdd)
                        .controlSize(.large)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - File ops

    private func bindingFor(id: UUID) -> Binding<TrackedFile>? {
        guard let i = store.files.firstIndex(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { store.files[i] },
            set: { store.update($0) }
        )
    }

    private func pickFileToAdd() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.plainText, .text, UTType(filenameExtension: "md") ?? .text]
        if panel.runModal() == .OK, let url = panel.url {
            let alias = url.deletingPathExtension().lastPathComponent
            let file = TrackedFile(alias: alias, path: url.path)
            store.add(file)
            selectedFileID = file.id
        }
    }

    private func repickFile(for id: UUID) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.plainText, .text, UTType(filenameExtension: "md") ?? .text]
        if panel.runModal() == .OK, let url = panel.url,
           var existing = store.files.first(where: { $0.id == id }) {
            existing.path = url.path
            store.update(existing)
        }
    }

    private func removeSelected() {
        if let id = selectedFileID { remove(id: id) }
    }

    private func remove(id: UUID) {
        store.remove(id: id)
        if selectedFileID == id { selectedFileID = store.files.first?.id }
    }
}

// MARK: - Sidebar row

private struct SidebarFileRow: View {
    let file: TrackedFile
    let selected: Bool
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: iconName)
                    .font(.system(size: 13))
                    .frame(width: 18)
                    .foregroundStyle(selected ? InklingTheme.primaryText : InklingTheme.secondaryText)
                VStack(alignment: .leading, spacing: 1) {
                    Text(file.displayName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(InklingTheme.primaryText)
                    Text(file.path)
                        .font(.system(size: 11))
                        .foregroundStyle(InklingTheme.tertiaryText)
                        .lineLimit(1).truncationMode(.middle)
                }
                Spacer()
                if let hk = file.hotkey {
                    Text(hk.displayString)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(InklingTheme.tertiaryText)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(selected ? InklingTheme.pillFill : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private var iconName: String {
        switch file.mode {
        case .todo: return "checklist"
        case .heading: return "number"
        case .plain: return "doc.text"
        }
    }
}

// MARK: - General

private struct GeneralSettingsView: View {
    @ObservedObject var prefs: Preferences

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                groupCard(title: "Global capture") {
                    HotkeyRecorder(hotkey: $prefs.globalHotkey, label: "Open last-used file")
                    helpText("Press this anywhere to bring up the capture panel pointed at the most recently used file.")
                }
                groupCard(title: "Behavior") {
                    Toggle("Play sound on save", isOn: $prefs.playSoundOnSave)
                    Toggle("Launch at login", isOn: $prefs.launchAtLogin)
                }
                groupCard(title: "Obsidian") {
                    Toggle("Write through Obsidian when in a vault", isOn: $prefs.preferObsidianForWrite)
                    Toggle("Open in Obsidian when in a vault", isOn: $prefs.preferObsidianForOpen)
                    helpText("Inkling tries Obsidian first when applicable, and falls back to a direct file write or the system default app if Obsidian isn't running.")
                }
                groupCard(title: "Hot corner") {
                    HStack {
                        Text("Trigger from").foregroundStyle(InklingTheme.secondaryText)
                        Picker("", selection: $prefs.hotCorner) {
                            ForEach(HotCornerService.Corner.allCases) { c in
                                Text(c.label).tag(c)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 180)
                        Spacer()
                    }
                    HStack {
                        Text("Dwell").foregroundStyle(InklingTheme.secondaryText)
                            .frame(width: 80, alignment: .leading)
                        Slider(value: $prefs.hotCornerDwell, in: 0.05...1.0, step: 0.05)
                        Text(String(format: "%.2fs", prefs.hotCornerDwell))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(InklingTheme.tertiaryText)
                            .frame(width: 50, alignment: .trailing)
                    }
                    .disabled(prefs.hotCorner == .none)
                    helpText("Shove the mouse into the chosen corner of any screen to open the capture panel — works without modifier keys, even when Inkling isn't focused.")
                }
                groupCard(title: "Timestamps") {
                    HStack {
                        Text("Format").foregroundStyle(InklingTheme.secondaryText)
                        TextField("yyyy-MM-dd HH:mm", text: $prefs.defaultTimestampFormat)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    }
                    helpText("Used for {{datetime}} and the “prefix with timestamp” option.")
                }
            }
            .padding(22)
        }
    }

    private func groupCard<Content: View>(title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(InklingTheme.tertiaryText)
            VStack(alignment: .leading, spacing: 12) {
                content()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(InklingTheme.groupCardFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(InklingTheme.cardBorder, lineWidth: 0.5)
            )
        }
    }

    private func helpText(_ s: String) -> some View {
        Text(s).font(.caption).foregroundStyle(InklingTheme.tertiaryText)
    }
}

// MARK: - About

private struct AboutView: View {
    @ObservedObject var store: FileStore

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)
            Text("Inkling").font(.system(size: 22, weight: .semibold))
            Text("Quick-add panel for macOS.")
                .foregroundStyle(InklingTheme.secondaryText)
            HStack(spacing: 16) {
                infoChip("Obsidian.app", ObsidianService.isInstalled ? "installed" : "missing")
                infoChip("obsidian-cli", ObsidianService.hasCLI ? "ready" : "missing")
                infoChip("Files", "\(store.files.count)")
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    private func infoChip(_ key: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 12, weight: .semibold))
                .foregroundStyle(InklingTheme.primaryText)
            Text(key).font(.caption2).foregroundStyle(InklingTheme.secondaryText)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(InklingTheme.pillFill)
        )
    }
}
