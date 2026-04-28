import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct CaptureView: View {
    @ObservedObject var store: FileStore
    @ObservedObject var prefs: Preferences
    @ObservedObject var controller: CaptureWindowController
    @ObservedObject var history: WriteHistory
    @State private var text: String = ""
    @State private var showSwitcher: Bool = false
    @State private var showSectionPicker: Bool = false
    @State private var statusMessage: String?
    @State private var statusIsError: Bool = false
    @State private var dropTargeted: Bool = false

    var onClose: () -> Void
    var onSlashAction: (SlashCommand.Action) -> Void

    var activeFile: TrackedFile? {
        guard let id = controller.activeFileID else { return store.files.first }
        return store.files.first(where: { $0.id == id }) ?? store.files.first
    }

    private var activeFileID: Binding<UUID?> {
        Binding(get: { controller.activeFileID }, set: { controller.activeFileID = $0 })
    }

    private var slashSuggestions: [SlashCommand]? { SlashRegistry.suggestions(for: text) }
    private var inSlashMode: Bool { slashSuggestions != nil }

    var body: some View {
        ZStack(alignment: .top) {
            mainCard
            if showSwitcher {
                Color.black.opacity(0.18)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .onTapGesture { showSwitcher = false }
                    .transition(.opacity)

                FileSwitcherView(
                    files: store.files,
                    selectedID: activeFileID,
                    onPick: { f in
                        controller.activeFileID = f.id
                        showSwitcher = false
                    },
                    onCancel: { showSwitcher = false }
                )
                .frame(width: 460)
                .frame(maxHeight: 300)
                .padding(.top, 56)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            if showSectionPicker, let f = activeFile {
                Color.black.opacity(0.18)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .onTapGesture { showSectionPicker = false }
                    .transition(.opacity)
                SectionPickerView(
                    file: f,
                    onPick: { selected in
                        applySection(selected)
                        showSectionPicker = false
                    },
                    onCancel: { showSectionPicker = false }
                )
                .frame(width: 460)
                .frame(maxHeight: 300)
                .padding(.top, 56)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(width: 640, height: 360)
        .padding(40)
        .frame(width: 720, height: 440)
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: showSwitcher)
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: showSectionPicker)
    }

    // MARK: - Main card

    private var mainCard: some View {
        VStack(spacing: 0) {
            chromeRow
            CaptureTextEditor(
                text: $text,
                onIntent: handle(intent:),
                onPasteImage: handlePastedImage(_:),
                onPasteFileURL: handlePastedFileURL(_:),
                placeholder: placeholderText
            )
            .padding(.horizontal, 28)
            .padding(.top, 6)
            .frame(maxHeight: .infinity, alignment: .top)
            assistRow
            actionsRow
            statusFooter
        }
        .background(CardBackground(cornerRadius: 22, material: .hudWindow))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(dropTargeted ? Color.accentColor : InklingTheme.cardBorder,
                        lineWidth: dropTargeted ? 2 : 0.5)
        )
        .shadow(color: Color.black.opacity(0.30), radius: 30, x: 0, y: 18)
        .onDrop(of: [.fileURL], isTargeted: $dropTargeted) { providers in
            handleDrop(providers: providers)
        }
    }

    private var chromeRow: some View {
        HStack(spacing: 10) {
            TrafficLights(onCancel: onClose)
            Spacer()
            if let section = activeFile?.targetSection {
                SectionPill(section: section, onPick: { showSectionPicker = true })
            }
            MenuChip(action: { showSwitcher = true })
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var assistRow: some View {
        if let suggestions = slashSuggestions {
            slashHints(suggestions)
        } else if !text.isEmpty {
            EmptyView()
        } else if let recents = recentLinesForActiveFile, !recents.isEmpty {
            recentEntriesPeek(recents)
        }
    }

    private func slashHints(_ suggestions: [SlashCommand]) -> some View {
        HStack(spacing: 6) {
            ForEach(suggestions.prefix(5), id: \.self) { cmd in
                Button { applySlash(cmd) } label: {
                    HStack(spacing: 4) {
                        Text("/").foregroundStyle(InklingTheme.tertiaryText)
                        Text(cmd.name)
                            .fontWeight(.semibold)
                            .foregroundStyle(InklingTheme.primaryText)
                        Text(cmd.summary)
                            .foregroundStyle(InklingTheme.secondaryText)
                    }
                    .font(.system(size: 11))
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(InklingTheme.pillFill)
                    )
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Text("⇥ to complete")
                .font(.system(size: 10))
                .foregroundStyle(InklingTheme.tertiaryText)
        }
        .padding(.horizontal, 22).padding(.vertical, 6)
    }

    private func recentEntriesPeek(_ lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.system(size: 11))
                    .foregroundStyle(InklingTheme.tertiaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .padding(.horizontal, 28).padding(.vertical, 4)
    }

    private var actionsRow: some View {
        HStack(alignment: .center) {
            secondaryAction
            Spacer()
            primaryAction
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 18)
        .padding(.top, 10)
    }

    private var secondaryAction: some View {
        Button {
            commit(position: .append, andOpen: true)
        } label: {
            HStack(spacing: 8) {
                KeyGlyphs(symbols: ["⌘", "⇧", "↩"])
                Text("Add and open")
                    .font(.system(size: 13, weight: .regular))
            }
            .foregroundStyle(InklingTheme.secondaryText)
        }
        .buttonStyle(.plain)
        .opacity(canSubmit ? 1.0 : 0.55)
        .disabled(!canSubmit)
    }

    private var primaryAction: some View {
        Button {
            commit(position: .append, andOpen: false)
        } label: {
            HStack(spacing: 12) {
                Text(primaryActionTitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(InklingTheme.primaryText)
                KeyGlyphs(symbols: ["⌘", "↩"])
                    .foregroundStyle(InklingTheme.secondaryText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(canSubmit ? InklingTheme.pillFill : InklingTheme.pillFill.opacity(0.5))
            )
        }
        .buttonStyle(.plain)
        .disabled(!canSubmit)
    }

    private var statusFooter: some View {
        ZStack {
            if let s = statusMessage {
                Text(s)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(statusIsError ? Color.red : Color.green)
                    .transition(.opacity)
                    .padding(.bottom, 8)
            }
        }
        .frame(height: statusMessage == nil ? 0 : 18)
        .animation(.easeOut(duration: 0.18), value: statusMessage)
    }

    // MARK: - Helpers

    private var canSubmit: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && activeFile != nil
            && !inSlashMode
    }

    private var placeholderText: String {
        guard let f = activeFile else { return "Add a file in Settings to start capturing…" }
        switch f.mode {
        case .plain: return "Type a line for \(f.displayName)… (try /daily, /meeting)"
        case .todo: return "What's the task?"
        case .heading: return "New section title…"
        }
    }

    private var primaryActionTitle: String {
        guard let f = activeFile else { return "No file" }
        if let section = f.targetSection { return "Add to \(f.displayName) → \(section)" }
        return "Add to \(f.displayName)"
    }

    private var recentLinesForActiveFile: [String]? {
        guard let f = activeFile else { return nil }
        return MarkdownReader.recentLines(at: f.resolvedURL, count: 3)
    }

    // MARK: - Intents

    private func handle(intent: CaptureIntent) {
        switch intent {
        case .submitAppend:
            // If user pressed Enter after typing an exact slash command, run it.
            if let cmd = SlashRegistry.exactMatch(for: text) {
                applySlash(cmd)
            } else {
                commit(position: .append, andOpen: false)
            }
        case .submitPrepend:
            commit(position: .prepend, andOpen: false)
        case .submitAppendAndOpen:
            commit(position: .append, andOpen: true)
        case .openFile:
            if let f = activeFile { ObsidianService.open(file: f, prefs: prefs) }
            onClose()
        case .openSettings:
            NSLog("Inkling.capture: openSettings intent → onSlashAction(.openSettings)")
            onSlashAction(.openSettings)
        case .dismiss:
            onClose()
        case .switchFile:
            showSwitcher = true
        case .insertNewline:
            break
        case .dictate:
            NSApp.sendAction(
                Selector(("startDictation:")),
                to: nil,
                from: nil
            )
        case .completeSlash:
            if let first = slashSuggestions?.first {
                text = "/\(first.name)"
            }
        }
    }

    // MARK: - Slash commands

    private func applySlash(_ cmd: SlashCommand) {
        switch cmd.kind {
        case .template(let body):
            text = renderTemplate(body)
        case .action(let action):
            text = "" // clear the slash
            switch action {
            case .openSettings, .openActiveFile, .quit:
                onSlashAction(action)
                onClose()
            case .dictate:
                NSApp.sendAction(
                    Selector(("startDictation:")),
                    to: nil,
                    from: nil
                )
            case .sectionPicker:
                showSectionPicker = true
            case .undo:
                undoLastWrite()
            }
        }
    }

    private func renderTemplate(_ body: String) -> String {
        guard let f = activeFile else { return body }
        return TemplateEngine.render(
            template: body,
            text: "",
            file: f,
            timestampFormat: prefs.defaultTimestampFormat
        )
    }

    private func applySection(_ section: String?) {
        guard var f = activeFile else { return }
        f.targetSection = section
        store.update(f)
        flashStatus(section.map { "Targeting → \($0)" } ?? "Section cleared", isError: false)
    }

    private func undoLastWrite() {
        guard let receipt = history.popLast() else {
            flashStatus("Nothing to undo", isError: true)
            return
        }
        do {
            try FileWriter.restore(receipt)
            flashStatus("Undid write to \(receipt.fileAlias)", isError: false)
        } catch {
            flashStatus(error.localizedDescription, isError: true)
        }
    }

    // MARK: - Commit

    private func commit(position: TrackedFile.Position, andOpen: Bool) {
        guard let file = activeFile else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            flashStatus("Nothing to write", isError: true)
            return
        }
        do {
            let receipt = try FileWriter.write(
                text: trimmed,
                to: file,
                position: position,
                timestampFormat: prefs.defaultTimestampFormat,
                preferObsidianWrite: prefs.preferObsidianForWrite
            )
            history.record(receipt)
            if prefs.playSoundOnSave {
                NSSound(named: NSSound.Name("Pop"))?.play()
            }
            text = ""
            if andOpen {
                ObsidianService.open(file: file, prefs: prefs)
            }
            flashStatus("Saved to \(file.displayName)", isError: false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { onClose() }
        } catch {
            flashStatus(error.localizedDescription, isError: true)
        }
    }

    // MARK: - Drop handling

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let file = activeFile else { return false }
        var inserted: [String] = []
        let group = DispatchGroup()

        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                defer { group.leave() }
                guard let url else { return }
                if let link = AttachmentService.saveDroppedFile(at: url, for: file) {
                    inserted.append(link)
                }
            }
        }
        group.notify(queue: .main) {
            guard !inserted.isEmpty else { return }
            let toInsert = inserted.joined(separator: " ")
            self.text = self.text.isEmpty ? toInsert : "\(self.text) \(toInsert)"
            self.flashStatus("Attached \(inserted.count) file\(inserted.count == 1 ? "" : "s")", isError: false)
        }
        return true
    }

    // MARK: - Image paste

    private func handlePastedImage(_ image: NSImage) -> String? {
        guard let file = activeFile,
              let link = AttachmentService.savePastedImage(image, for: file) else {
            flashStatus("Couldn't save attachment", isError: true)
            return nil
        }
        flashStatus("Attached image", isError: false)
        return link
    }

    private func handlePastedFileURL(_ url: URL) -> String? {
        guard let file = activeFile, url.isFileURL,
              let link = AttachmentService.saveDroppedFile(at: url, for: file) else {
            flashStatus("Couldn't attach file", isError: true)
            return nil
        }
        flashStatus("Attached \(url.lastPathComponent)", isError: false)
        return link
    }

    private func flashStatus(_ message: String, isError: Bool) {
        statusMessage = message
        statusIsError = isError
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            if statusMessage == message { statusMessage = nil }
        }
    }
}

// MARK: - Sub-components

private struct TrafficLights: View {
    var onCancel: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            dot(color: Color(red: 1.0, green: 0.37, blue: 0.36), action: onCancel)
            dot(color: Color(red: 1.0, green: 0.74, blue: 0.20), action: nil)
            dot(color: Color(red: 0.27, green: 0.83, blue: 0.39), action: nil)
        }
    }

    private func dot(color: Color, action: (() -> Void)?) -> some View {
        let circle = Circle()
            .fill(color)
            .frame(width: 12, height: 12)
            .overlay(Circle().stroke(Color.black.opacity(0.06), lineWidth: 0.5))
        return Group {
            if let action {
                Button(action: action) { circle }.buttonStyle(.plain)
            } else {
                circle
            }
        }
    }
}

private struct MenuChip: View {
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(InklingTheme.menuChipFill)
                    .frame(width: 32, height: 28)
                Image(systemName: "drop.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(InklingTheme.menuChipIcon)
            }
        }
        .buttonStyle(.plain)
        .help("Switch file (⇥)")
    }
}

private struct SectionPill: View {
    let section: String
    let onPick: () -> Void
    var body: some View {
        Button(action: onPick) {
            HStack(spacing: 4) {
                Image(systemName: "number")
                    .font(.system(size: 10, weight: .medium))
                Text(section)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1).truncationMode(.tail)
            }
            .foregroundStyle(InklingTheme.secondaryText)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(InklingTheme.pillFill)
            )
        }
        .buttonStyle(.plain)
        .help("Change target section")
    }
}

private struct KeyGlyphs: View {
    let symbols: [String]
    var body: some View {
        HStack(spacing: 2) {
            ForEach(symbols, id: \.self) { s in
                Text(s)
                    .font(.system(size: 12, weight: .medium))
            }
        }
    }
}
