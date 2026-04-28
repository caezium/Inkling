import SwiftUI
import AppKit
import Carbon.HIToolbox

struct HotkeyRecorder: View {
    @Binding var hotkey: Hotkey?
    var label: String = "Hotkey"
    var allowsEmpty: Bool = true

    @State private var recording: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            Text(label).foregroundStyle(.secondary)
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(recording ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(recording ? Color.accentColor : Color.clear, lineWidth: 1)
                    )
                Text(displayText)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(recording ? Color.accentColor : .primary)
                    .padding(.horizontal, 10)
            }
            .frame(minWidth: 130, minHeight: 26)
            .contentShape(Rectangle())
            .onTapGesture { recording.toggle() }

            if allowsEmpty, hotkey != nil {
                Button(action: { hotkey = nil; recording = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .background(KeyEventCatcher(active: $recording, onCapture: { hk in
            self.hotkey = hk
            self.recording = false
        }))
    }

    private var displayText: String {
        if recording { return "Press a shortcut…" }
        if let hk = hotkey { return hk.displayString }
        return "Click to record"
    }
}

private struct KeyEventCatcher: NSViewRepresentable {
    @Binding var active: Bool
    var onCapture: (Hotkey) -> Void

    func makeNSView(context: Context) -> NSView { CatcherView(active: $active, onCapture: onCapture) }
    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? CatcherView)?.activeBinding = $active
        (nsView as? CatcherView)?.refreshMonitor()
    }

    final class CatcherView: NSView {
        var activeBinding: Binding<Bool>
        let onCapture: (Hotkey) -> Void
        private var monitor: Any?

        init(active: Binding<Bool>, onCapture: @escaping (Hotkey) -> Void) {
            self.activeBinding = active
            self.onCapture = onCapture
            super.init(frame: .zero)
        }
        required init?(coder: NSCoder) { fatalError() }

        func refreshMonitor() {
            if activeBinding.wrappedValue, monitor == nil {
                monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
                    guard let self, self.activeBinding.wrappedValue else { return e }
                    if let hk = Hotkey(event: e) {
                        self.onCapture(hk)
                        return nil
                    }
                    if e.keyCode == UInt16(kVK_Escape) {
                        self.activeBinding.wrappedValue = false
                        return nil
                    }
                    return nil
                }
            } else if !activeBinding.wrappedValue, let m = monitor {
                NSEvent.removeMonitor(m); monitor = nil
            }
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            refreshMonitor()
        }
        deinit { if let m = monitor { NSEvent.removeMonitor(m) } }
    }
}
