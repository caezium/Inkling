import AppKit
import SwiftUI
import Combine
import Carbon.HIToolbox

@MainActor
final class MenuPanelController: ObservableObject {
    private var panel: MenuPanel?
    private var hostingView: NSHostingView<MenuRootView>?
    private var resignKeyObserver: NSObjectProtocol?
    private var keyMonitor: Any?

    private let store: FileStore
    private let prefs: Preferences

    var onCapture: () -> Void = {}
    var onCaptureFile: (UUID) -> Void = { _ in }
    var onQuit: () -> Void = {}
    /// Called after `hide()` finishes — used by AppDelegate to restore key focus
    /// to the capture panel when the user dismisses settings.
    var onHide: () -> Void = {}
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

        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) })
            ?? NSScreen.main
            ?? NSScreen.screens.first!
        let visible = screen.visibleFrame

        let cardWidth: CGFloat = 280
        let shadowPadding: CGFloat = 24
        let cardInset: CGFloat = 12
        // Card is allowed to grow up to the entire visible height minus the
        // shadow halo and small inset on top + bottom.
        let maxCardHeight = visible.height - shadowPadding * 2 - cardInset * 2

        let view = MenuRootView(
            store: store,
            prefs: prefs,
            maxCardHeight: maxCardHeight,
            onCapture: { [weak self] in self?.onCapture(); self?.hide() },
            onCaptureFile: { [weak self] id in self?.onCaptureFile(id); self?.hide() },
            onQuit: { [weak self] in self?.onQuit() },
            onClose: { [weak self] in self?.hide() }
        )
        let hosting = NSHostingView(rootView: view)
        // First lay out at the maximum allowed size, then ask SwiftUI for
        // the actual fitting height so the panel hugs its content rather
        // than always taking the maximum.
        let maxPanelSize = NSSize(
            width: cardWidth + shadowPadding * 2,
            height: maxCardHeight + shadowPadding * 2
        )
        hosting.frame = NSRect(origin: .zero, size: maxPanelSize)
        hosting.layoutSubtreeIfNeeded()
        let fitting = hosting.fittingSize
        let actualHeight = max(120, min(fitting.height, maxPanelSize.height))
        let panelSize = NSSize(width: maxPanelSize.width, height: actualHeight)
        hosting.frame = NSRect(origin: .zero, size: panelSize)

        let panel = MenuPanel(contentView: hosting, size: panelSize)
        anchorTopRight(panel: panel, size: panelSize, on: screen)
        NSLog("Inkling.menu: show() — created panel at \(panel.frame), level=\(panel.level.rawValue), fitting=\(fitting), maxAllowed=\(maxCardHeight)")

        self.panel = panel
        self.hostingView = hosting

        panel.makeKeyAndOrderFront(nil)
        registerKeyMonitor()
        DispatchQueue.main.async { [weak self] in
            guard let self, let panel = self.panel else { return }
            self.registerResignObserver(for: panel)
            NSLog("Inkling.menu: show() — panel.isVisible=\(panel.isVisible) isKeyWindow=\(panel.isKeyWindow)")
        }
    }

    /// Listens for ⌘+, and Esc while our panel is the key window so the user
    /// can toggle / dismiss without going back to the capture panel first.
    private func registerKeyMonitor() {
        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let panel = self.panel, panel.isKeyWindow else { return event }
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            // Hold-to-repeat would rapidly toggle — ignore repeats.
            if event.isARepeat { return event }
            switch event.keyCode {
            case UInt16(kVK_Escape):
                self.hide(); return nil
            case UInt16(kVK_ANSI_Comma) where mods == [.command]:
                self.hide(); return nil
            default:
                return event
            }
        }
    }

    func hide() {
        if let observer = resignKeyObserver {
            NotificationCenter.default.removeObserver(observer)
            resignKeyObserver = nil
        }
        if let m = keyMonitor {
            NSEvent.removeMonitor(m)
            keyMonitor = nil
        }
        panel?.orderOut(nil)
        panel = nil
        hostingView = nil
        onHide()
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

    /// Pins the panel to the top-right corner of the given screen, matching
    /// the Apple Control Center / Liquid Glass dropdown placement.
    /// Independent of where the user's status icon happens to be in the bar.
    private func anchorTopRight(panel: MenuPanel, size: NSSize, on screen: NSScreen) {
        let visible = screen.visibleFrame
        // Pin the panel's right edge exactly at visible.maxX so the shadow
        // halo on the right doesn't get clipped off-screen.
        let x = visible.maxX - size.width
        // Pin the panel's top edge exactly at visible.maxY for the same reason.
        // (NSWindow origin is bottom-left, so this is maxY - height.)
        let y = visible.maxY - size.height
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
