import AppKit
import SwiftUI
import Combine
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = FileStore.shared
    private let prefs = Preferences.shared

    private var statusItem: NSStatusItem!
    private var captureController: CaptureWindowController!
    private var menuPanelController: MenuPanelController!
    private let hotCorner = HotCornerService()
    private var lastUsedFileID: UUID?
    private var cancellables = Set<AnyCancellable>()

    private let globalHotkeyToken = UUID()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        captureController = CaptureWindowController(store: store, prefs: prefs)
        menuPanelController = MenuPanelController(store: store, prefs: prefs)

        installStatusItem()
        registerAllHotkeys()
        observeChanges()
        applyLaunchAtLogin()
        applyHotCorner()
        hotCorner.onTriggered = { [weak self] in
            guard let self else { return }
            self.captureController.show(initialFileID: self.lastUsedFileID ?? self.store.files.first?.id)
        }
        captureController.onSlashAction = { [weak self] action in
            guard let self else { return }
            switch action {
            case .openSettings:
                self.openSettings()
            case .openActiveFile:
                if let id = self.captureController.activeFileID,
                   let file = self.store.file(id: id) {
                    ObsidianService.open(file: file, prefs: self.prefs)
                }
            case .quit:
                NSApp.terminate(nil)
            case .undo, .dictate, .sectionPicker:
                break
            }
        }
        menuPanelController.onCapture = { [weak self] in
            guard let self else { return }
            self.captureController.show(initialFileID: self.lastUsedFileID ?? self.store.files.first?.id)
        }
        menuPanelController.onCaptureFile = { [weak self] id in
            guard let self else { return }
            self.lastUsedFileID = id
            self.captureController.show(initialFileID: id)
        }
        menuPanelController.onQuit = { NSApp.terminate(nil) }
        menuPanelController.statusItem = statusItem

        if store.files.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.openSettings()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotkeyManager.shared.unregisterAll()
    }

    // MARK: - Status item

    private func installStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "drop.fill",
                accessibilityDescription: "Inkling"
            )
            button.image?.isTemplate = true
            button.toolTip = "Inkling"
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        NSLog("Inkling.menu: statusItemClicked, panelVisible=\(menuPanelController.isVisible)")
        captureController.hide()
        menuPanelController.toggle()
    }

    @objc private func openSettingsCommand(_ sender: Any?) {
        openSettings()
    }

    func openSettings() {
        // Settings live in the dropdown panel; surface it.
        captureController.hide()
        menuPanelController.show()
    }

    // MARK: - Hotkeys

    private func registerAllHotkeys() {
        HotkeyManager.shared.unregisterAll()

        if let global = prefs.globalHotkey {
            HotkeyManager.shared.register(id: globalHotkeyToken, hotkey: global) { [weak self] in
                guard let self else { return }
                self.captureController.toggleOrSwitch(
                    fileID: self.lastUsedFileID ?? self.store.files.first?.id
                )
            }
        }

        for file in store.files {
            guard let hk = file.hotkey else { continue }
            let id = file.id
            HotkeyManager.shared.register(id: id, hotkey: hk) { [weak self] in
                guard let self else { return }
                self.lastUsedFileID = id
                self.captureController.toggleOrSwitch(fileID: id)
            }
        }
    }

    private func observeChanges() {
        store.$files
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.registerAllHotkeys() }
            .store(in: &cancellables)

        prefs.$globalHotkey
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.registerAllHotkeys() }
            .store(in: &cancellables)

        prefs.$launchAtLogin
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.applyLaunchAtLogin() }
            .store(in: &cancellables)

        prefs.$hotCorner
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.applyHotCorner() }
            .store(in: &cancellables)

        prefs.$hotCornerDwell
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.applyHotCorner() }
            .store(in: &cancellables)
    }

    private func applyHotCorner() {
        hotCorner.configure(corner: prefs.hotCorner, dwell: prefs.hotCornerDwell)
    }

    private func applyLaunchAtLogin() {
        guard #available(macOS 13.0, *) else { return }
        do {
            if prefs.launchAtLogin {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            NSLog("Inkling: launch-at-login update failed: \(error)")
        }
    }
}
