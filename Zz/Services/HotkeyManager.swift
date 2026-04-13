import Foundation
import AppKit
import Carbon

// MARK: - Hotkey Manager

class HotkeyManager {
    static let shared = HotkeyManager()

    var onToggle: (() -> Void)?
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    func start() {
        stop()

        let settings = AppSettings.shared
        // Default to Cmd+Shift if setting is wrong
        // For Carbon cmd is 256, shift is 512, opt is 2048, ctrl is 4096
        // Let's just hardcode Cmd+Shift+Space for now as a reliable default.
        // If we wanted properly mapped modifiers from AppSettings, we could map them.

        let keyCode = UInt32(49) // Space
        let modifiers = UInt32(cmdKey | shiftKey) // ⌘⇧

        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = UTGetOSTypeFromString("DskM" as CFString)
        hotKeyID.id = UInt32(1)

        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        InstallEventHandler(GetApplicationEventTarget(), { (nextHandler, theEvent, userData) -> OSStatus in
            // Must be dispatched to main thread
            DispatchQueue.main.async {
                HotkeyManager.shared.onToggle?()
            }
            return noErr
        }, 1, &eventType, nil, &eventHandler)
    }

    func stop() {
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
        if let hotKey = hotKeyRef {
            UnregisterEventHotKey(hotKey)
            hotKeyRef = nil
        }
    }

    deinit {
        stop()
    }
}
