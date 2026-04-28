import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct MenuRootView: View {
    @ObservedObject var store: FileStore
    @ObservedObject var prefs: Preferences

    var onCapture: () -> Void
    var onCaptureFile: (UUID) -> Void
    var onQuit: () -> Void
    var onClose: () -> Void

    @State private var path: [Route] = []

    enum Route: Hashable { case file(UUID) }

    var body: some View {
        NavigationStack(path: $path) {
            rootList
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .file(let id):
                        if let f = store.files.first(where: { $0.id == id }) {
                            MenuFileDetailView(
                                file: bindingFor(id: id),
                                onDelete: {
                                    store.remove(id: id)
                                    path.removeLast()
                                },
                                onPickFile: { repickFile(for: id) }
                            )
                        } else {
                            Text("File missing").foregroundStyle(.secondary)
                        }
                    }
                }
        }
        .frame(width: 320, height: 480)
        .background(CardBackground(cornerRadius: 22, material: .hudWindow))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 28, x: 0, y: 14)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .preferredColorScheme(.dark)
    }

    // MARK: - Root list

    private var rootList: some View {
        ScrollView {
            VStack(spacing: 8) {
                headerRow

                PillButton(icon: "drop.fill", label: "Capture",
                           trailing: prefs.globalHotkey?.displayString,
                           action: onCapture)

                if !store.files.isEmpty {
                    PillSectionHeader(text: "Files")
                    ForEach(store.files) { file in
                        PillNav(
                            icon: iconName(for: file),
                            label: file.displayName,
                            detail: file.path,
                            trailing: file.hotkey?.displayString,
                            action: { path.append(.file(file.id)) }
                        )
                        .contextMenu {
                            Button("Capture to \(file.displayName)") { onCaptureFile(file.id) }
                            Button("Edit") { path.append(.file(file.id)) }
                            Divider()
                            Button("Remove", role: .destructive) { store.remove(id: file.id) }
                        }
                    }
                }

                PillButton(icon: "plus", label: "Add file…", action: pickFileToAdd)

                PillSectionHeader(text: "Behavior")
                PillToggle(icon: "speaker.wave.2.fill", label: "Sound on save", isOn: $prefs.playSoundOnSave)
                PillToggle(icon: "power", label: "Launch at login", isOn: $prefs.launchAtLogin)
                PillHotkey(icon: "command", label: "Global hotkey", hotkey: $prefs.globalHotkey)

                PillSectionHeader(text: "Hot corner")
                PillPicker(
                    icon: "rectangle.inset.topleft.filled",
                    label: "Trigger from",
                    selection: $prefs.hotCorner,
                    options: HotCornerService.Corner.allCases,
                    optionLabel: { $0.label }
                )
                PillSlider(
                    icon: "timer",
                    label: "Dwell",
                    value: $prefs.hotCornerDwell,
                    range: 0.05...1.0,
                    step: 0.05,
                    format: { String(format: "%.2fs", $0) },
                    disabled: prefs.hotCorner == .none
                )

                PillSectionHeader(text: "Obsidian")
                PillToggle(icon: "square.and.pencil", label: "Write through Obsidian",
                           sublabel: ObsidianService.hasCLI ? nil : "obsidian-cli not detected",
                           isOn: $prefs.preferObsidianForWrite)
                PillToggle(icon: "arrow.up.forward.app", label: "Open in Obsidian",
                           isOn: $prefs.preferObsidianForOpen)

                Spacer(minLength: 4)

                PillButton(icon: "power.dotted", label: "Quit Inkling", trailing: "⌘Q",
                           role: .destructive, action: onQuit)
            }
            .padding(10)
        }
    }

    private var headerRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "drop.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.accentColor)
            Text("Inkling").font(.system(size: 13, weight: .semibold))
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(InklingTheme.tertiaryText)
                    .padding(6)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .help("Close (Esc)")
        }
        .padding(.horizontal, 6)
        .padding(.top, 4)
        .padding(.bottom, 4)
    }

    // MARK: - File ops

    private func bindingFor(id: UUID) -> Binding<TrackedFile> {
        Binding(
            get: { store.files.first(where: { $0.id == id }) ?? TrackedFile(alias: "", path: "") },
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
            path.append(.file(file.id))
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

    private func iconName(for file: TrackedFile) -> String {
        switch file.mode {
        case .todo: return "checklist"
        case .heading: return "number"
        case .plain: return "doc.text"
        }
    }
}
