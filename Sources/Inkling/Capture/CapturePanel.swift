import AppKit

final class CapturePanel: NSPanel {
    init(contentView: NSView, size: NSSize = NSSize(width: 720, height: 440)) {
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        self.isOpaque = false
        self.backgroundColor = .clear
        // SwiftUI draws the shadow inside the panel's padding so the panel itself
        // doesn't paint a rectangular shadow around the rounded content.
        self.hasShadow = false
        self.isMovableByWindowBackground = true
        self.hidesOnDeactivate = false
        self.animationBehavior = .utilityWindow
        self.contentView = contentView
        self.invalidateShadow()
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func centerOnActiveScreen() {
        let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let screen else { return }
        let f = self.frame
        let visible = screen.visibleFrame
        let x = visible.midX - f.width / 2
        let y = visible.midY + visible.height * 0.12 - f.height / 2
        self.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
