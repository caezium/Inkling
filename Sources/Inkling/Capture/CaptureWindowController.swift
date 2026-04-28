import AppKit
import SwiftUI

@MainActor
final class CaptureWindowController: ObservableObject {
    @Published var activeFileID: UUID?

    private var panel: CapturePanel?
    private var hostingView: NSHostingView<CaptureView>?

    private let store: FileStore
    private let prefs: Preferences
    private let history: WriteHistory
    var onSlashAction: (SlashCommand.Action) -> Void = { _ in }

    var isVisible: Bool { panel?.isVisible == true }

    init(store: FileStore, prefs: Preferences, history: WriteHistory = .shared) {
        self.store = store
        self.prefs = prefs
        self.history = history
    }

    func show(initialFileID: UUID? = nil) {
        if let id = initialFileID {
            activeFileID = id
        } else if activeFileID == nil {
            activeFileID = store.files.first?.id
        }

        if let panel, panel.isVisible {
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = CaptureView(
            store: store,
            prefs: prefs,
            controller: self,
            history: history,
            onClose: { [weak self] in self?.hide() },
            onSlashAction: { [weak self] action in self?.onSlashAction(action) }
        )
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(x: 0, y: 0, width: 720, height: 440)

        let panel = CapturePanel(contentView: hosting, size: NSSize(width: 720, height: 440))
        panel.centerOnActiveScreen()

        self.panel = panel
        self.hostingView = hosting

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
        hostingView = nil
    }

    func toggleOrSwitch(fileID: UUID?) {
        guard isVisible else {
            show(initialFileID: fileID)
            return
        }
        if fileID == nil || fileID == activeFileID {
            hide()
        } else {
            activeFileID = fileID
            panel?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
