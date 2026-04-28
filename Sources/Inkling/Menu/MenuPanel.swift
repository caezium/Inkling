import AppKit

/// Borderless dropdown panel anchored under the status item button.
/// Uses NSVisualEffectView via SwiftUI's CardBackground for the liquid-glass material.
final class MenuPanel: NSPanel {
    init(contentView: NSView, size: NSSize) {
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        self.level = .statusBar
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.isMovableByWindowBackground = false
        self.hidesOnDeactivate = false
        self.animationBehavior = .utilityWindow
        // Non-activating panels default to becomesKeyOnlyIfNeeded=true, which
        // means a panel of toggles + buttons may never accept key focus and
        // can be invisible-feeling. Force it.
        self.becomesKeyOnlyIfNeeded = false
        self.contentView = contentView
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
