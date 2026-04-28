import AppKit
import SwiftUI

/// Layer-clipped NSVisualEffectView that gives the capture card a real macOS
/// translucent material, with no rectangular shadow / outline artifacts.
struct CardBackground: NSViewRepresentable {
    var cornerRadius: CGFloat = 22
    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blendingMode
        v.state = .active
        v.wantsLayer = true
        v.layer?.cornerRadius = cornerRadius
        v.layer?.cornerCurve = .continuous
        v.layer?.masksToBounds = true
        return v
    }

    func updateNSView(_ v: NSVisualEffectView, context: Context) {
        v.material = material
        v.blendingMode = blendingMode
        v.layer?.cornerRadius = cornerRadius
    }
}
