import AppKit
import Carbon

@MainActor
final class HotkeyManager {
    static let shared = HotkeyManager()

    private struct Registration {
        let id: UInt32
        let ref: EventHotKeyRef
        let handler: () -> Void
    }

    private let signature: OSType = 0x4D524B45 // 'MRKE'
    private var registrations: [UUID: Registration] = [:]
    private var nextID: UInt32 = 1
    private var eventHandlerInstalled = false

    private init() {}

    func register(id: UUID, hotkey: Hotkey, handler: @escaping () -> Void) {
        unregister(id: id)
        installEventHandler()

        let assignedID = nextID; nextID += 1
        let hkID = EventHotKeyID(signature: signature, id: assignedID)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            hotkey.keyCode,
            hotkey.modifiers,
            hkID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        guard status == noErr, let ref else {
            NSLog("Inkling: failed to register hotkey \(hotkey.displayString) (status \(status))")
            return
        }
        registrations[id] = Registration(id: assignedID, ref: ref, handler: handler)
    }

    func unregister(id: UUID) {
        if let reg = registrations.removeValue(forKey: id) {
            UnregisterEventHotKey(reg.ref)
        }
    }

    func unregisterAll() {
        for reg in registrations.values { UnregisterEventHotKey(reg.ref) }
        registrations.removeAll()
    }

    fileprivate func dispatch(id: UInt32) {
        if let reg = registrations.values.first(where: { $0.id == id }) {
            reg.handler()
        }
    }

    private func installEventHandler() {
        guard !eventHandlerInstalled else { return }
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let ptr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, eventRef, userData -> OSStatus in
                guard let eventRef = eventRef, let userData = userData else { return noErr }
                var hkID = EventHotKeyID()
                let s = GetEventParameter(
                    eventRef,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hkID
                )
                guard s == noErr else { return s }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async { manager.dispatch(id: hkID.id) }
                return noErr
            },
            1,
            &spec,
            ptr,
            nil
        )
        eventHandlerInstalled = true
    }
}
