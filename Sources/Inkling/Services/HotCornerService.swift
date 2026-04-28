import AppKit

@MainActor
final class HotCornerService {
    enum Corner: String, Codable, CaseIterable, Identifiable {
        case none, topLeft, topRight, bottomLeft, bottomRight
        var id: String { rawValue }
        var label: String {
            switch self {
            case .none: return "Disabled"
            case .topLeft: return "Top-left"
            case .topRight: return "Top-right"
            case .bottomLeft: return "Bottom-left"
            case .bottomRight: return "Bottom-right"
            }
        }
    }

    var onTriggered: () -> Void = {}

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var dwellTimer: Timer?
    private var inCorner = false
    private var lastTriggerAt: Date = .distantPast
    private var corner: Corner = .none
    private var dwellSeconds: TimeInterval = 0.25

    /// Cooldown so a single dwell doesn't double-fire when the user immediately re-enters the corner.
    private let cooldown: TimeInterval = 1.2

    /// Pixel radius of the corner zone — small enough that you have to actively shove the cursor there.
    private let zone: CGFloat = 4

    func configure(corner: Corner, dwell: TimeInterval) {
        self.corner = corner
        self.dwellSeconds = max(0.05, dwell)
        rebuildMonitors()
    }

    private func rebuildMonitors() {
        if let m = globalMonitor { NSEvent.removeMonitor(m); globalMonitor = nil }
        if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
        cancelDwell()
        guard corner != .none else { return }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            self?.handleMouseMove()
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.handleMouseMove()
            return event
        }
    }

    private func handleMouseMove() {
        let location = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(location) }) else {
            inCorner = false
            cancelDwell()
            return
        }
        let frame = screen.frame
        let isInZone: Bool = {
            switch corner {
            case .none: return false
            case .topLeft:
                return location.x <= frame.minX + zone && location.y >= frame.maxY - zone
            case .topRight:
                return location.x >= frame.maxX - zone && location.y >= frame.maxY - zone
            case .bottomLeft:
                return location.x <= frame.minX + zone && location.y <= frame.minY + zone
            case .bottomRight:
                return location.x >= frame.maxX - zone && location.y <= frame.minY + zone
            }
        }()

        if isInZone {
            if !inCorner {
                inCorner = true
                startDwell()
            }
        } else if inCorner {
            inCorner = false
            cancelDwell()
        }
    }

    private func startDwell() {
        cancelDwell()
        let timer = Timer.scheduledTimer(withTimeInterval: dwellSeconds, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in self?.fire() }
        }
        RunLoop.main.add(timer, forMode: .common)
        dwellTimer = timer
    }

    private func cancelDwell() {
        dwellTimer?.invalidate()
        dwellTimer = nil
    }

    private func fire() {
        let now = Date()
        guard now.timeIntervalSince(lastTriggerAt) > cooldown else { return }
        lastTriggerAt = now
        onTriggered()
    }
}
