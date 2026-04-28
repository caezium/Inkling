import SwiftUI
import AppKit
import Carbon.HIToolbox

struct SectionPickerView: View {
    let file: TrackedFile
    var onPick: (String?) -> Void
    var onCancel: () -> Void

    @State private var query: String = ""
    @State private var highlightIndex: Int = 0
    @State private var headings: [MarkdownReader.Heading] = []

    private var filtered: [MarkdownReader.Heading] {
        guard !query.isEmpty else { return headings }
        let q = query.lowercased()
        return headings.filter { $0.title.lowercased().contains(q) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "number").foregroundStyle(.secondary)
                TextField("Pick a section in \(file.displayName)…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .onSubmit { pickHighlighted() }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)

            Divider().opacity(0.3)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    rowFor(title: "(none — append to end of file)", level: 0, isClear: true, idx: -1)
                    ForEach(Array(filtered.enumerated()), id: \.element.id) { idx, h in
                        rowFor(title: h.indentedLabel, level: h.level, isClear: false, idx: idx)
                    }
                }
            }
            .frame(maxHeight: 280)

            Divider().opacity(0.3)
            HStack {
                Text("\(filtered.count) heading\(filtered.count == 1 ? "" : "s")")
                    .font(.system(size: 11)).foregroundStyle(.tertiary)
                Spacer()
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
            headings = MarkdownReader.headings(at: file.resolvedURL)
            highlightIndex = 0
        }
        .onChange(of: query) { _, _ in highlightIndex = 0 }
        .background(KeyboardCatcher(
            onUp: { highlightIndex = max(-1, highlightIndex - 1) },
            onDown: { highlightIndex = min(filtered.count - 1, highlightIndex + 1) },
            onReturn: pickHighlighted,
            onEscape: onCancel
        ))
    }

    @ViewBuilder
    private func rowFor(title: String, level: Int, isClear: Bool, idx: Int) -> some View {
        let highlighted = highlightIndex == idx
        Button {
            if isClear { onPick(nil) } else if let h = filtered[safe: idx] { onPick(h.title) }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isClear ? "xmark.circle" : "number")
                    .frame(width: 18)
                    .foregroundStyle(highlighted ? Color.white : Color.accentColor)
                Text(title)
                    .font(.system(size: 13, weight: isClear ? .regular : .medium))
                    .lineLimit(1).truncationMode(.tail)
                Spacer()
                if !isClear {
                    Text("H\(level)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(highlighted ? Color.accentColor.opacity(0.2) : Color.clear)
        }
        .buttonStyle(.plain)
    }

    private func pickHighlighted() {
        if highlightIndex == -1 {
            onPick(nil)
        } else if let h = filtered[safe: highlightIndex] {
            onPick(h.title)
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

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
