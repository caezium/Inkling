import SwiftUI
import Carbon.HIToolbox

struct FileSwitcherView: View {
    let files: [TrackedFile]
    @Binding var selectedID: UUID?
    var onPick: (TrackedFile) -> Void
    var onCancel: () -> Void

    @State private var query: String = ""
    @State private var highlightIndex: Int = 0

    private var filtered: [TrackedFile] {
        guard !query.isEmpty else { return files }
        let q = query.lowercased()
        return files.filter {
            $0.alias.lowercased().contains(q) || $0.path.lowercased().contains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Switch to file…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .onSubmit { pickHighlighted() }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)

            Divider().opacity(0.3)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(filtered.enumerated()), id: \.element.id) { idx, file in
                        FileSwitcherRow(file: file, highlighted: idx == highlightIndex)
                            .contentShape(Rectangle())
                            .onTapGesture { onPick(file) }
                    }
                }
            }
            .frame(maxHeight: 280)

            Divider().opacity(0.3)

            HStack(spacing: 14) {
                shortcutHint("↑↓", "navigate")
                shortcutHint("↩", "select")
                shortcutHint("⎋", "cancel")
                Spacer()
                Text("\(filtered.count) of \(files.count)")
                    .font(.system(size: 11)).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
        }
        .background(CardBackground(cornerRadius: 18, material: .popover))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(InklingTheme.cardBorder, lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.30), radius: 24, x: 0, y: 12)
        .onAppear {
            highlightIndex = max(0, files.firstIndex(where: { $0.id == selectedID }) ?? 0)
        }
        .onChange(of: query) { _, _ in highlightIndex = 0 }
        .background(KeyboardCatcher(
            onUp: { highlightIndex = max(0, highlightIndex - 1) },
            onDown: { highlightIndex = min(filtered.count - 1, highlightIndex + 1) },
            onReturn: pickHighlighted,
            onEscape: onCancel
        ))
    }

    private func pickHighlighted() {
        guard filtered.indices.contains(highlightIndex) else { return }
        onPick(filtered[highlightIndex])
    }

    private func shortcutHint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .padding(.horizontal, 5).padding(.vertical, 1)
                .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 3))
            Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
        }
    }
}

private struct FileSwitcherRow: View {
    let file: TrackedFile
    let highlighted: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .frame(width: 18)
                .foregroundStyle(highlighted ? Color.white : Color.accentColor)
            VStack(alignment: .leading, spacing: 1) {
                Text(file.displayName)
                    .font(.system(size: 14, weight: .medium))
                Text(file.path)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            if let hk = file.hotkey {
                Text(hk.displayString)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(highlighted ? Color.accentColor.opacity(0.2) : Color.clear)
    }

    private var iconName: String {
        switch file.mode {
        case .todo: return "checklist"
        case .heading: return "number"
        case .plain: return "doc.text"
        }
    }
}

private struct KeyboardCatcher: NSViewRepresentable {
    var onUp: () -> Void
    var onDown: () -> Void
    var onReturn: () -> Void
    var onEscape: () -> Void

    func makeNSView(context: Context) -> NSView {
        let v = CatcherView()
        v.onUp = onUp; v.onDown = onDown; v.onReturn = onReturn; v.onEscape = onEscape
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {}

    final class CatcherView: NSView {
        var onUp: (() -> Void)?
        var onDown: (() -> Void)?
        var onReturn: (() -> Void)?
        var onEscape: (() -> Void)?
        private var monitor: Any?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window != nil, monitor == nil {
                monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
                    guard let self else { return e }
                    switch e.keyCode {
                    case UInt16(kVK_UpArrow): self.onUp?(); return nil
                    case UInt16(kVK_DownArrow): self.onDown?(); return nil
                    case UInt16(kVK_Return): self.onReturn?(); return nil
                    case UInt16(kVK_Escape): self.onEscape?(); return nil
                    default: return e
                    }
                }
            } else if window == nil, let m = monitor {
                NSEvent.removeMonitor(m); monitor = nil
            }
        }
        deinit { if let m = monitor { NSEvent.removeMonitor(m) } }
    }
}
