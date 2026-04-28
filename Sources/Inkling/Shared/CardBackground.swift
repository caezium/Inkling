import AppKit
import SwiftUI

/// Layer-clipped NSVisualEffectView that gives surfaces a real macOS
/// translucent material, with no rectangular shadow / outline artifacts.
///
/// References Oskar Groth's "Reverse engineering NSVisualEffectView" for
/// the `isEmphasized` flag (the saturated Control-Center look) and the
/// pattern of clipping via the layer rather than SwiftUI's `clipShape`.
struct CardBackground: NSViewRepresentable {
    var cornerRadius: CGFloat = 22
    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    /// When true, attempts to use the newer "glass" material (rawValue 21)
    /// for a stronger Liquid-Glass-style blur. Falls back if not recognized.
    var preferLiquidGlass: Bool = false

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        configure(v)
        return v
    }

    func updateNSView(_ v: NSVisualEffectView, context: Context) {
        configure(v)
    }

    private func configure(_ v: NSVisualEffectView) {
        if preferLiquidGlass, let glass = NSVisualEffectView.Material(rawValue: 21) {
            v.material = glass
        } else {
            v.material = material
        }
        v.blendingMode = blendingMode
        v.state = .active
        // The saturated / brighter look used by Control Center, Notification
        // Center, and other modern Apple surfaces.
        v.isEmphasized = true
        v.wantsLayer = true
        v.layer?.cornerRadius = cornerRadius
        v.layer?.cornerCurve = .continuous
        v.layer?.masksToBounds = true
        // Subtle hairline that gives the card a defined edge, like a
        // 1-pixel-wide rim of light at the top of Liquid-Glass surfaces.
        v.layer?.borderColor = NSColor.white.withAlphaComponent(0.10).cgColor
        v.layer?.borderWidth = 0.5
    }
}

/// Layer-clipped translucent surface with a subtle accent-color tint, used
/// for the menu-bar dropdown so it doesn't read as a heavy dark slab.
struct TintedGlassBackground: NSViewRepresentable {
    var cornerRadius: CGFloat = 18
    /// Alpha of the tint overlay applied above the material.
    var tintAlpha: CGFloat = 0.18
    var tintColor: NSColor = NSColor.systemBlue

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.cornerRadius = cornerRadius
        container.layer?.cornerCurve = .continuous
        container.layer?.masksToBounds = true

        let blur = NSVisualEffectView()
        blur.material = .popover
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.isEmphasized = true
        blur.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(blur)

        let tint = NSView()
        tint.wantsLayer = true
        tint.layer?.backgroundColor = tintColor.withAlphaComponent(tintAlpha).cgColor
        tint.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(tint)

        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: container.topAnchor),
            blur.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            blur.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            tint.topAnchor.constraint(equalTo: container.topAnchor),
            tint.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            tint.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            tint.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])

        // Hairline rim at the layer level — Oskar Groth's article cautions
        // that SwiftUI's overlay stroke can interact poorly with NSVisualEffectView.
        container.layer?.borderColor = NSColor.white.withAlphaComponent(0.14).cgColor
        container.layer?.borderWidth = 0.5

        return container
    }

    func updateNSView(_ v: NSView, context: Context) {
        v.layer?.cornerRadius = cornerRadius
        if let tintView = v.subviews.last { tintView.layer?.backgroundColor = tintColor.withAlphaComponent(tintAlpha).cgColor }
    }
}
