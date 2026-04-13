import Foundation
import CoreGraphics
import AppKit

// MARK: - Input Simulator

class InputSimulator {
    static let shared = InputSimulator()

    private let source: CGEventSource?
    private let actionDelay: TimeInterval = 0.05  // 50ms between actions

    init() {
        source = CGEventSource(stateID: .hidSystemState)
    }

    // MARK: - Mouse Actions

    /// Move mouse cursor to a point
    func moveMouse(to point: CGPoint) {
        let event = CGEvent(mouseEventSource: source, mouseType: .mouseMoved,
                           mouseCursorPosition: point, mouseButton: .left)
        event?.post(tap: .cghidEventTap)
        usleep(useconds_t(actionDelay * 1_000_000))
    }

    /// Left click at a point
    func leftClick(at point: CGPoint) {
        let down = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown,
                          mouseCursorPosition: point, mouseButton: .left)
        let up = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp,
                        mouseCursorPosition: point, mouseButton: .left)
        down?.post(tap: .cghidEventTap)
        usleep(50_000)
        up?.post(tap: .cghidEventTap)
        usleep(useconds_t(actionDelay * 1_000_000))
    }

    /// Right click at a point
    func rightClick(at point: CGPoint) {
        let down = CGEvent(mouseEventSource: source, mouseType: .rightMouseDown,
                          mouseCursorPosition: point, mouseButton: .right)
        let up = CGEvent(mouseEventSource: source, mouseType: .rightMouseUp,
                        mouseCursorPosition: point, mouseButton: .right)
        down?.post(tap: .cghidEventTap)
        usleep(50_000)
        up?.post(tap: .cghidEventTap)
        usleep(useconds_t(actionDelay * 1_000_000))
    }

    /// Double click at a point
    func doubleClick(at point: CGPoint) {
        let down1 = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown,
                           mouseCursorPosition: point, mouseButton: .left)
        down1?.setIntegerValueField(.mouseEventClickState, value: 1)
        let up1 = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp,
                         mouseCursorPosition: point, mouseButton: .left)
        up1?.setIntegerValueField(.mouseEventClickState, value: 1)

        let down2 = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown,
                           mouseCursorPosition: point, mouseButton: .left)
        down2?.setIntegerValueField(.mouseEventClickState, value: 2)
        let up2 = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp,
                         mouseCursorPosition: point, mouseButton: .left)
        up2?.setIntegerValueField(.mouseEventClickState, value: 2)

        down1?.post(tap: .cghidEventTap)
        up1?.post(tap: .cghidEventTap)
        down2?.post(tap: .cghidEventTap)
        up2?.post(tap: .cghidEventTap)
        usleep(useconds_t(actionDelay * 1_000_000))
    }

    /// Triple click at a point
    func tripleClick(at point: CGPoint) {
        for clickState in 1...3 {
            let down = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown,
                              mouseCursorPosition: point, mouseButton: .left)
            down?.setIntegerValueField(.mouseEventClickState, value: Int64(clickState))
            let up = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp,
                            mouseCursorPosition: point, mouseButton: .left)
            up?.setIntegerValueField(.mouseEventClickState, value: Int64(clickState))
            down?.post(tap: .cghidEventTap)
            up?.post(tap: .cghidEventTap)
        }
        usleep(useconds_t(actionDelay * 1_000_000))
    }

    /// Middle click at a point
    func middleClick(at point: CGPoint) {
        let down = CGEvent(mouseEventSource: source, mouseType: .otherMouseDown,
                          mouseCursorPosition: point, mouseButton: .center)
        let up = CGEvent(mouseEventSource: source, mouseType: .otherMouseUp,
                        mouseCursorPosition: point, mouseButton: .center)
        down?.post(tap: .cghidEventTap)
        usleep(50_000)
        up?.post(tap: .cghidEventTap)
        usleep(useconds_t(actionDelay * 1_000_000))
    }

    /// Click and drag from one point to another
    func leftClickDrag(from start: CGPoint, to end: CGPoint) {
        let down = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown,
                          mouseCursorPosition: start, mouseButton: .left)
        down?.post(tap: .cghidEventTap)
        usleep(100_000)

        // Smooth drag
        let steps = 10
        for i in 1...steps {
            let fraction = CGFloat(i) / CGFloat(steps)
            let x = start.x + (end.x - start.x) * fraction
            let y = start.y + (end.y - start.y) * fraction
            let drag = CGEvent(mouseEventSource: source, mouseType: .leftMouseDragged,
                              mouseCursorPosition: CGPoint(x: x, y: y), mouseButton: .left)
            drag?.post(tap: .cghidEventTap)
            usleep(20_000)
        }

        let up = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp,
                        mouseCursorPosition: end, mouseButton: .left)
        up?.post(tap: .cghidEventTap)
        usleep(useconds_t(actionDelay * 1_000_000))
    }

    // MARK: - Keyboard Actions

    /// Type a string of text (using CGEvent key events for each character)
    func typeText(_ text: String) {
        for char in text {
            let str = String(char)
            let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
            let chars = Array(str.utf16)
            event?.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: chars)
            event?.post(tap: .cghidEventTap)

            let upEvent = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
            upEvent?.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: chars)
            upEvent?.post(tap: .cghidEventTap)

            usleep(10_000)
        }
        usleep(useconds_t(actionDelay * 1_000_000))
    }

    /// Press a key with optional modifiers
    func pressKey(_ keyCode: CGKeyCode, modifiers: CGEventFlags = []) {
        // Press modifier keys down
        let modifierKeys = extractModifierKeys(modifiers)
        for mk in modifierKeys {
            let down = CGEvent(keyboardEventSource: source, virtualKey: mk, keyDown: true)
            down?.flags = modifiers
            down?.post(tap: .cghidEventTap)
        }

        usleep(20_000)

        // Press the actual key
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        keyDown?.flags = modifiers
        keyDown?.post(tap: .cghidEventTap)

        usleep(30_000)

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        keyUp?.flags = modifiers
        keyUp?.post(tap: .cghidEventTap)

        usleep(20_000)

        // Release modifier keys
        for mk in modifierKeys.reversed() {
            let up = CGEvent(keyboardEventSource: source, virtualKey: mk, keyDown: false)
            up?.post(tap: .cghidEventTap)
        }

        usleep(useconds_t(actionDelay * 1_000_000))
    }

    /// Press a key combo string like "cmd+s", "ctrl+shift+a"
    func pressKeyCombo(_ combo: String) {
        guard let parsed = KeyCodes.parseKeyCombo(combo) else {
            print("[InputSimulator] Failed to parse key combo: \(combo)")
            return
        }
        pressKey(parsed.keyCode, modifiers: parsed.modifiers)
    }

    // MARK: - Scroll

    /// Scroll at a position
    func scroll(at point: CGPoint, direction: ScrollDirection, amount: Int) {
        moveMouse(to: point)
        usleep(50_000)

        for _ in 0..<amount {
            let scrollEvent: CGEvent?
            switch direction {
            case .up:
                scrollEvent = CGEvent(scrollWheelEvent2Source: source, units: .line, wheelCount: 1, wheel1: 3, wheel2: 0, wheel3: 0)
            case .down:
                scrollEvent = CGEvent(scrollWheelEvent2Source: source, units: .line, wheelCount: 1, wheel1: -3, wheel2: 0, wheel3: 0)
            case .left:
                scrollEvent = CGEvent(scrollWheelEvent2Source: source, units: .line, wheelCount: 2, wheel1: 0, wheel2: 3, wheel3: 0)
            case .right:
                scrollEvent = CGEvent(scrollWheelEvent2Source: source, units: .line, wheelCount: 2, wheel1: 0, wheel2: -3, wheel3: 0)
            }
            scrollEvent?.post(tap: .cghidEventTap)
            usleep(50_000)
        }
    }

    // MARK: - Execute Action

    /// Execute a ComputerAction, returns screenshot data after execution if applicable
    func execute(_ action: ComputerAction, scaleFactor: CGFloat = 1.0) async -> Data? {
        switch action {
        case .screenshot:
            return await ScreenCapture.shared.captureScreenAsJPEG()

        case .leftClick(let pt):
            let scaled = ImageUtils.scaleCoordinates(pt, scaleFactor: scaleFactor)
            leftClick(at: scaled)

        case .rightClick(let pt):
            let scaled = ImageUtils.scaleCoordinates(pt, scaleFactor: scaleFactor)
            rightClick(at: scaled)

        case .doubleClick(let pt):
            let scaled = ImageUtils.scaleCoordinates(pt, scaleFactor: scaleFactor)
            doubleClick(at: scaled)

        case .tripleClick(let pt):
            let scaled = ImageUtils.scaleCoordinates(pt, scaleFactor: scaleFactor)
            tripleClick(at: scaled)

        case .middleClick(let pt):
            let scaled = ImageUtils.scaleCoordinates(pt, scaleFactor: scaleFactor)
            middleClick(at: scaled)

        case .mouseMove(let pt):
            let scaled = ImageUtils.scaleCoordinates(pt, scaleFactor: scaleFactor)
            moveMouse(to: scaled)

        case .leftClickDrag(let start, let end):
            let scaledStart = ImageUtils.scaleCoordinates(start, scaleFactor: scaleFactor)
            let scaledEnd = ImageUtils.scaleCoordinates(end, scaleFactor: scaleFactor)
            leftClickDrag(from: scaledStart, to: scaledEnd)

        case .type(let text):
            typeText(text)

        case .key(let keys):
            pressKeyCombo(keys)

        case .scroll(let pt, let dir, let amt):
            let scaled = ImageUtils.scaleCoordinates(pt, scaleFactor: scaleFactor)
            scroll(at: scaled, direction: dir, amount: amt)

        case .wait(let duration):
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))

        case .zoom:
            // Zoom is handled by the API, not by us
            break
        }

        return nil
    }

    // MARK: - Helpers

    private func extractModifierKeys(_ flags: CGEventFlags) -> [CGKeyCode] {
        var keys: [CGKeyCode] = []
        if flags.contains(.maskCommand) { keys.append(KeyCodes.kVK_Command) }
        if flags.contains(.maskShift) { keys.append(KeyCodes.kVK_Shift) }
        if flags.contains(.maskAlternate) { keys.append(KeyCodes.kVK_Option) }
        if flags.contains(.maskControl) { keys.append(KeyCodes.kVK_Control) }
        return keys
    }
}
