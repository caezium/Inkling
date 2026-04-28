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
    private let hotCorner = HotCornerService()
    private var lastUsedFileID: UUID?
    private var cancellables = Set<AnyCancellable>()

    private let globalHotkeyToken = UUID()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        captureController = CaptureWindowController(store: store, prefs: prefs)

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
                break // handled inside CaptureView
            }
        }

        if store.files.isEmpty {
            // First launch — gently prompt the user via the settings window.
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
        }
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let captureItem = NSMenuItem(
            title: "Capture…",
            action: #selector(captureCommand(_:)),
            keyEquivalent: ""
        )
        captureItem.target = self
        menu.addItem(captureItem)

        if !store.files.isEmpty {
            menu.addItem(.separator())
            let header = NSMenuItem()
            header.title = "Open file"
            header.isEnabled = false
            menu.addItem(header)
            for file in store.files {
                let item = NSMenuItem(
                    title: file.displayName,
                    action: #selector(captureForSpecificFile(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = file.id
                if let hk = file.hotkey {
                    item.title = "\(file.displayName)  \(hk.displayString)"
                }
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())

        let settings = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettingsCommand(_:)),
            keyEquivalent: ","
        )
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())
        let quit = NSMenuItem(
            title: "Quit Inkling",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quit)

        statusItem.menu = menu
    }

    // MARK: - Menu actions

    @objc private func captureCommand(_ sender: Any?) {
        captureController.toggleOrSwitch(fileID: lastUsedFileID ?? store.files.first?.id)
    }

    @objc private func captureForSpecificFile(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        lastUsedFileID = id
        captureController.toggleOrSwitch(fileID: id)
    }

    @objc private func openSettingsCommand(_ sender: Any?) {
        openSettings()
    }

    func openSettings() {
        // Make sure the floating capture panel doesn't sit on top of the settings window.
        captureController.hide()
        NSApp.activate(ignoringOtherApps: true)
        let selector: Selector
        if #available(macOS 14.0, *) {
            selector = Selector(("showSettingsWindow:"))
        } else {
            selector = Selector(("showPreferencesWindow:"))
        }
        NSApp.sendAction(selector, to: nil, from: nil)
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
            .sink { [weak self] _ in
                self?.registerAllHotkeys()
                self?.rebuildMenu()
            }
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
