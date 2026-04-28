import AppKit
import SwiftUI
import Combine

@MainActor
final class MenuPanelController: ObservableObject {
    private var panel: MenuPanel?
    private var hostingView: NSHostingView<MenuRootView>?
    private var resignKeyObserver: NSObjectProtocol?

    private let store: FileStore
    private let prefs: Preferences

    var onCapture: () -> Void = {}
    var onCaptureFile: (UUID) -> Void = { _ in }
    var onQuit: () -> Void = {}
    weak var statusItem: NSStatusItem?

    var isVisible: Bool { panel?.isVisible == true }

    init(store: FileStore, prefs: Preferences) {
        self.store = store
        self.prefs = prefs
    }

    func toggle() {
        if isVisible { hide() } else { show() }
    }

    func show() {
        if let panel, panel.isVisible {
            NSLog("Inkling.menu: show() — already visible, bringing forward")
            panel.makeKeyAndOrderFront(nil)
            return
        }

        let view = MenuRootView(
            store: store,
            prefs: prefs,
            onCapture: { [weak self] in self?.onCapture(); self?.hide() },
            onCaptureFile: { [weak self] id in self?.onCaptureFile(id); self?.hide() },
            onQuit: { [weak self] in self?.onQuit() },
            onClose: { [weak self] in self?.hide() }
        )
        let size = NSSize(width: 320, height: 480)
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(origin: .zero, size: size)

        let panel = MenuPanel(contentView: hosting, size: size)
        anchorBelowStatusItem(panel: panel, size: size)
        NSLog("Inkling.menu: show() — created panel at \(panel.frame), level=\(panel.level.rawValue)")

        self.panel = panel
        self.hostingView = hosting

        // Order front first, register the resign observer AFTER, so the initial
        // becomeKey doesn't accidentally trigger the dismiss path.
        panel.makeKeyAndOrderFront(nil)
        DispatchQueue.main.async { [weak self] in
            guard let self, let panel = self.panel else { return }
            self.registerResignObserver(for: panel)
            NSLog("Inkling.menu: show() — panel.isVisible=\(panel.isVisible) isKeyWindow=\(panel.isKeyWindow)")
        }
    }

    func hide() {
        if let observer = resignKeyObserver {
            NotificationCenter.default.removeObserver(observer)
            resignKeyObserver = nil
        }
        panel?.orderOut(nil)
        panel = nil
        hostingView = nil
    }

    private func registerResignObserver(for panel: MenuPanel) {
        resignKeyObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            // Defer slightly so we don't fight a chained click on the status item.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                Task { @MainActor [weak self] in self?.hide() }
            }
        }
    }

    private func anchorBelowStatusItem(panel: MenuPanel, size: NSSize) {
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }
        let visible = screen.visibleFrame

        let anchorFrame: NSRect = {
            if let button = statusItem?.button, let win = button.window {
                return win.convertToScreen(button.convert(button.bounds, to: nil))
            }
            // Fallback: top-right of screen
            return NSRect(x: visible.maxX - 60, y: visible.maxY - 28, width: 60, height: 24)
        }()

        let margin: CGFloat = 6
        let x = min(max(anchorFrame.midX - size.width / 2, visible.minX + margin), visible.maxX - size.width - margin)
        let y = anchorFrame.minY - size.height - margin
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
