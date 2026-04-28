import SwiftUI

enum InklingTheme {
    /// Card background mirrors the original: pure white in light, near-black NSPanel grey in dark.
    static var cardBackground: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(white: 0.13, alpha: 1.0)
                : NSColor.white
        }))
    }

    /// Subtle tint that sits *over* a system Material so the card reads as
    /// translucent-but-clearly-light in light mode and clearly-dark in dark mode.
    static var cardTint: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor.black.withAlphaComponent(0.30)
                : NSColor.white.withAlphaComponent(0.55)
        }))
    }

    static var cardBorder: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor.white.withAlphaComponent(0.10)
                : NSColor.black.withAlphaComponent(0.05)
        }))
    }

    static var primaryText: Color { Color(nsColor: .labelColor) }
    static var secondaryText: Color { Color(nsColor: .secondaryLabelColor) }
    static var tertiaryText: Color { Color(nsColor: .tertiaryLabelColor) }

    static var pillFill: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(white: 0.22, alpha: 1.0)
                : NSColor(white: 0.94, alpha: 1.0)
        }))
    }

    static var menuChipFill: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(white: 0.22, alpha: 1.0)
                : NSColor(white: 0.92, alpha: 1.0)
        }))
    }

    static var menuChipIcon: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(white: 0.55, alpha: 1.0)
                : NSColor(white: 0.45, alpha: 1.0)
        }))
    }

    /// Backdrop tint behind the file switcher in capture-panel context.
    static var switcherBackground: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(white: 0.13, alpha: 1.0)
                : NSColor.white
        }))
    }

    static var sidebarBackground: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(white: 0.10, alpha: 1.0)
                : NSColor(white: 0.97, alpha: 1.0)
        }))
    }

    static var groupCardFill: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(white: 0.16, alpha: 1.0)
                : NSColor(white: 0.98, alpha: 1.0)
        }))
    }
}
