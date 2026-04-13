import Foundation
import Carbon.HIToolbox

// MARK: - Virtual Key Codes

/// macOS virtual key codes (from Events.h / Carbon HIToolbox)
struct KeyCodes {
    // Letters
    static let kVK_A: CGKeyCode = 0x00
    static let kVK_S: CGKeyCode = 0x01
    static let kVK_D: CGKeyCode = 0x02
    static let kVK_F: CGKeyCode = 0x03
    static let kVK_H: CGKeyCode = 0x04
    static let kVK_G: CGKeyCode = 0x05
    static let kVK_Z: CGKeyCode = 0x06
    static let kVK_X: CGKeyCode = 0x07
    static let kVK_C: CGKeyCode = 0x08
    static let kVK_V: CGKeyCode = 0x09
    static let kVK_B: CGKeyCode = 0x0B
    static let kVK_Q: CGKeyCode = 0x0C
    static let kVK_W: CGKeyCode = 0x0D
    static let kVK_E: CGKeyCode = 0x0E
    static let kVK_R: CGKeyCode = 0x0F
    static let kVK_Y: CGKeyCode = 0x10
    static let kVK_T: CGKeyCode = 0x11
    static let kVK_O: CGKeyCode = 0x1F
    static let kVK_U: CGKeyCode = 0x20
    static let kVK_I: CGKeyCode = 0x22
    static let kVK_P: CGKeyCode = 0x23
    static let kVK_L: CGKeyCode = 0x25
    static let kVK_J: CGKeyCode = 0x26
    static let kVK_K: CGKeyCode = 0x28
    static let kVK_N: CGKeyCode = 0x2D
    static let kVK_M: CGKeyCode = 0x2E

    // Numbers
    static let kVK_0: CGKeyCode = 0x1D
    static let kVK_1: CGKeyCode = 0x12
    static let kVK_2: CGKeyCode = 0x13
    static let kVK_3: CGKeyCode = 0x14
    static let kVK_4: CGKeyCode = 0x15
    static let kVK_5: CGKeyCode = 0x17
    static let kVK_6: CGKeyCode = 0x16
    static let kVK_7: CGKeyCode = 0x1A
    static let kVK_8: CGKeyCode = 0x1C
    static let kVK_9: CGKeyCode = 0x19

    // Special keys
    static let kVK_Return: CGKeyCode = 0x24
    static let kVK_Tab: CGKeyCode = 0x30
    static let kVK_Space: CGKeyCode = 0x31
    static let kVK_Delete: CGKeyCode = 0x33        // Backspace
    static let kVK_Escape: CGKeyCode = 0x35
    static let kVK_ForwardDelete: CGKeyCode = 0x75

    // Arrow keys
    static let kVK_LeftArrow: CGKeyCode = 0x7B
    static let kVK_RightArrow: CGKeyCode = 0x7C
    static let kVK_DownArrow: CGKeyCode = 0x7D
    static let kVK_UpArrow: CGKeyCode = 0x7E

    // Function keys
    static let kVK_F1: CGKeyCode = 0x7A
    static let kVK_F2: CGKeyCode = 0x78
    static let kVK_F3: CGKeyCode = 0x63
    static let kVK_F4: CGKeyCode = 0x76
    static let kVK_F5: CGKeyCode = 0x60
    static let kVK_F6: CGKeyCode = 0x61
    static let kVK_F7: CGKeyCode = 0x62
    static let kVK_F8: CGKeyCode = 0x64
    static let kVK_F9: CGKeyCode = 0x65
    static let kVK_F10: CGKeyCode = 0x6D
    static let kVK_F11: CGKeyCode = 0x67
    static let kVK_F12: CGKeyCode = 0x6F

    // Modifier keys
    static let kVK_Command: CGKeyCode = 0x37
    static let kVK_Shift: CGKeyCode = 0x38
    static let kVK_Option: CGKeyCode = 0x3A
    static let kVK_Control: CGKeyCode = 0x3B

    // Other
    static let kVK_Home: CGKeyCode = 0x73
    static let kVK_End: CGKeyCode = 0x77
    static let kVK_PageUp: CGKeyCode = 0x74
    static let kVK_PageDown: CGKeyCode = 0x79

    // Punctuation
    static let kVK_Period: CGKeyCode = 0x2F
    static let kVK_Comma: CGKeyCode = 0x2B
    static let kVK_Slash: CGKeyCode = 0x2C
    static let kVK_Semicolon: CGKeyCode = 0x29
    static let kVK_Quote: CGKeyCode = 0x27
    static let kVK_LeftBracket: CGKeyCode = 0x21
    static let kVK_RightBracket: CGKeyCode = 0x1E
    static let kVK_Backslash: CGKeyCode = 0x2A
    static let kVK_Minus: CGKeyCode = 0x1B
    static let kVK_Equal: CGKeyCode = 0x18
    static let kVK_Grave: CGKeyCode = 0x32

    // Map from key name to keyCode
    static let nameToCode: [String: CGKeyCode] = {
        var map: [String: CGKeyCode] = [:]
        // Letters
        for (c, code) in [
            ("a", kVK_A), ("s", kVK_S), ("d", kVK_D), ("f", kVK_F),
            ("h", kVK_H), ("g", kVK_G), ("z", kVK_Z), ("x", kVK_X),
            ("c", kVK_C), ("v", kVK_V), ("b", kVK_B), ("q", kVK_Q),
            ("w", kVK_W), ("e", kVK_E), ("r", kVK_R), ("y", kVK_Y),
            ("t", kVK_T), ("o", kVK_O), ("u", kVK_U), ("i", kVK_I),
            ("p", kVK_P), ("l", kVK_L), ("j", kVK_J), ("k", kVK_K),
            ("n", kVK_N), ("m", kVK_M)
        ] {
            map[c] = code
        }
        // Numbers
        for (c, code) in [
            ("0", kVK_0), ("1", kVK_1), ("2", kVK_2), ("3", kVK_3),
            ("4", kVK_4), ("5", kVK_5), ("6", kVK_6), ("7", kVK_7),
            ("8", kVK_8), ("9", kVK_9)
        ] {
            map[c] = code
        }
        // Named keys
        map["return"] = kVK_Return
        map["enter"] = kVK_Return
        map["tab"] = kVK_Tab
        map["space"] = kVK_Space
        map["delete"] = kVK_Delete
        map["backspace"] = kVK_Delete
        map["forwarddelete"] = kVK_ForwardDelete
        map["escape"] = kVK_Escape
        map["esc"] = kVK_Escape
        map["left"] = kVK_LeftArrow
        map["right"] = kVK_RightArrow
        map["up"] = kVK_UpArrow
        map["down"] = kVK_DownArrow
        map["home"] = kVK_Home
        map["end"] = kVK_End
        map["pageup"] = kVK_PageUp
        map["pagedown"] = kVK_PageDown
        map["period"] = kVK_Period
        map["."] = kVK_Period
        map["comma"] = kVK_Comma
        map[","] = kVK_Comma
        map["slash"] = kVK_Slash
        map["/"] = kVK_Slash
        map["semicolon"] = kVK_Semicolon
        map[";"] = kVK_Semicolon
        map["minus"] = kVK_Minus
        map["-"] = kVK_Minus
        map["equal"] = kVK_Equal
        map["="] = kVK_Equal
        map["["] = kVK_LeftBracket
        map["]"] = kVK_RightBracket
        map["\\"] = kVK_Backslash
        map["`"] = kVK_Grave
        map["'"] = kVK_Quote

        // Function keys
        for i in 1...12 {
            map["f\(i)"] = [kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6,
                            kVK_F7, kVK_F8, kVK_F9, kVK_F10, kVK_F11, kVK_F12][i - 1]
        }
        return map
    }()

    /// Parse a key combo string like "cmd+shift+s" into (keyCode, modifiers)
    static func parseKeyCombo(_ combo: String) -> (keyCode: CGKeyCode, modifiers: CGEventFlags)? {
        let parts = combo.lowercased()
            .replacingOccurrences(of: "command", with: "cmd")
            .replacingOccurrences(of: "ctrl", with: "control")
            .replacingOccurrences(of: "alt", with: "option")
            .replacingOccurrences(of: "opt", with: "option")
            .replacingOccurrences(of: "super", with: "cmd")
            .split(separator: "+")
            .map { String($0).trimmingCharacters(in: .whitespaces) }

        var modifiers: CGEventFlags = []
        var keyCode: CGKeyCode?

        for part in parts {
            switch part {
            case "cmd", "meta":
                modifiers.insert(.maskCommand)
            case "shift":
                modifiers.insert(.maskShift)
            case "option":
                modifiers.insert(.maskAlternate)
            case "control", "ctrl":
                modifiers.insert(.maskControl)
            default:
                if let code = nameToCode[part] {
                    keyCode = code
                }
            }
        }

        guard let kc = keyCode else { return nil }
        return (kc, modifiers)
    }
}
