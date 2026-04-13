import Foundation
import CoreGraphics

// MARK: - Computer Action

enum ComputerAction: Codable {
    case screenshot
    case leftClick(coordinate: CGPoint)
    case rightClick(coordinate: CGPoint)
    case doubleClick(coordinate: CGPoint)
    case tripleClick(coordinate: CGPoint)
    case middleClick(coordinate: CGPoint)
    case mouseMove(coordinate: CGPoint)
    case leftClickDrag(startCoordinate: CGPoint, coordinate: CGPoint)
    case type(text: String)
    case key(keys: String)
    case scroll(coordinate: CGPoint, direction: ScrollDirection, amount: Int)
    case wait(duration: Double)
    case zoom(region: CGRect)

    enum CodingKeys: String, CodingKey {
        case action, coordinate, startCoordinate, text, key
        case direction, amount, duration, region
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .screenshot:
            try container.encode("screenshot", forKey: .action)
        case .leftClick(let pt):
            try container.encode("left_click", forKey: .action)
            try container.encode([pt.x, pt.y], forKey: .coordinate)
        case .rightClick(let pt):
            try container.encode("right_click", forKey: .action)
            try container.encode([pt.x, pt.y], forKey: .coordinate)
        case .doubleClick(let pt):
            try container.encode("double_click", forKey: .action)
            try container.encode([pt.x, pt.y], forKey: .coordinate)
        case .tripleClick(let pt):
            try container.encode("triple_click", forKey: .action)
            try container.encode([pt.x, pt.y], forKey: .coordinate)
        case .middleClick(let pt):
            try container.encode("middle_click", forKey: .action)
            try container.encode([pt.x, pt.y], forKey: .coordinate)
        case .mouseMove(let pt):
            try container.encode("mouse_move", forKey: .action)
            try container.encode([pt.x, pt.y], forKey: .coordinate)
        case .leftClickDrag(let start, let end):
            try container.encode("left_click_drag", forKey: .action)
            try container.encode([start.x, start.y], forKey: .startCoordinate)
            try container.encode([end.x, end.y], forKey: .coordinate)
        case .type(let text):
            try container.encode("type", forKey: .action)
            try container.encode(text, forKey: .text)
        case .key(let keys):
            try container.encode("key", forKey: .action)
            try container.encode(keys, forKey: .key)
        case .scroll(let pt, let dir, let amt):
            try container.encode("scroll", forKey: .action)
            try container.encode([pt.x, pt.y], forKey: .coordinate)
            try container.encode(dir.rawValue, forKey: .direction)
            try container.encode(amt, forKey: .amount)
        case .wait(let dur):
            try container.encode("wait", forKey: .action)
            try container.encode(dur, forKey: .duration)
        case .zoom(let rect):
            try container.encode("zoom", forKey: .action)
            try container.encode([rect.origin.x, rect.origin.y, rect.maxX, rect.maxY], forKey: .region)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let action = try container.decode(String.self, forKey: .action)

        switch action {
        case "screenshot":
            self = .screenshot
        case "left_click":
            let coords = try container.decode([Double].self, forKey: .coordinate)
            self = .leftClick(coordinate: CGPoint(x: coords[0], y: coords[1]))
        case "right_click":
            let coords = try container.decode([Double].self, forKey: .coordinate)
            self = .rightClick(coordinate: CGPoint(x: coords[0], y: coords[1]))
        case "double_click":
            let coords = try container.decode([Double].self, forKey: .coordinate)
            self = .doubleClick(coordinate: CGPoint(x: coords[0], y: coords[1]))
        case "triple_click":
            let coords = try container.decode([Double].self, forKey: .coordinate)
            self = .tripleClick(coordinate: CGPoint(x: coords[0], y: coords[1]))
        case "middle_click":
            let coords = try container.decode([Double].self, forKey: .coordinate)
            self = .middleClick(coordinate: CGPoint(x: coords[0], y: coords[1]))
        case "mouse_move":
            let coords = try container.decode([Double].self, forKey: .coordinate)
            self = .mouseMove(coordinate: CGPoint(x: coords[0], y: coords[1]))
        case "left_click_drag":
            let start = try container.decode([Double].self, forKey: .startCoordinate)
            let end = try container.decode([Double].self, forKey: .coordinate)
            self = .leftClickDrag(
                startCoordinate: CGPoint(x: start[0], y: start[1]),
                coordinate: CGPoint(x: end[0], y: end[1])
            )
        case "type":
            let text = try container.decode(String.self, forKey: .text)
            self = .type(text: text)
        case "key":
            let keys = try container.decode(String.self, forKey: .key)
            self = .key(keys: keys)
        case "scroll":
            let coords = try container.decode([Double].self, forKey: .coordinate)
            let dir = try container.decode(ScrollDirection.self, forKey: .direction)
            let amt = try container.decode(Int.self, forKey: .amount)
            self = .scroll(coordinate: CGPoint(x: coords[0], y: coords[1]), direction: dir, amount: amt)
        case "wait":
            let dur = try container.decode(Double.self, forKey: .duration)
            self = .wait(duration: dur)
        case "zoom":
            let coords = try container.decode([Double].self, forKey: .region)
            self = .zoom(region: CGRect(x: coords[0], y: coords[1],
                                        width: coords[2] - coords[0],
                                        height: coords[3] - coords[1]))
        default:
            self = .screenshot
        }
    }

    // Determine if this is a sensitive action
    var isSensitive: Bool {
        switch self {
        case .key(let keys):
            let lower = keys.lowercased()
            // Deletion, closing, quitting
            return lower.contains("delete") || lower.contains("backspace") ||
                   (lower.contains("cmd") && lower.contains("q")) ||
                   (lower.contains("cmd") && lower.contains("w"))
        case .type(let text):
            // Typing passwords or sensitive patterns
            let lower = text.lowercased()
            return lower.contains("password") || lower.contains("confirm")
        default:
            return false
        }
    }

    var requiresInputControl: Bool {
        switch self {
        case .screenshot, .wait: return false
        default: return true
        }
    }

    var description: String {
        switch self {
        case .screenshot: return "📸 Taking screenshot"
        case .leftClick(let pt): return "🖱️ Click at (\(Int(pt.x)), \(Int(pt.y)))"
        case .rightClick(let pt): return "🖱️ Right-click at (\(Int(pt.x)), \(Int(pt.y)))"
        case .doubleClick(let pt): return "🖱️ Double-click at (\(Int(pt.x)), \(Int(pt.y)))"
        case .tripleClick(let pt): return "🖱️ Triple-click at (\(Int(pt.x)), \(Int(pt.y)))"
        case .middleClick(let pt): return "🖱️ Middle-click at (\(Int(pt.x)), \(Int(pt.y)))"
        case .mouseMove(let pt): return "🖱️ Move to (\(Int(pt.x)), \(Int(pt.y)))"
        case .leftClickDrag(let s, let e): return "🖱️ Drag (\(Int(s.x)),\(Int(s.y))) → (\(Int(e.x)),\(Int(e.y)))"
        case .type(let text): return "⌨️ Type: \"\(text.prefix(30))\(text.count > 30 ? "..." : "")\""
        case .key(let keys): return "⌨️ Press: \(keys)"
        case .scroll(_, let dir, let amt): return "📜 Scroll \(dir.rawValue) ×\(amt)"
        case .wait(let dur): return "⏳ Wait \(dur)s"
        case .zoom(let r): return "🔍 Zoom region (\(Int(r.origin.x)),\(Int(r.origin.y)))-(\(Int(r.maxX)),\(Int(r.maxY)))"
        }
    }
}

enum ScrollDirection: String, Codable {
    case up, down, left, right
}

// MARK: - Undo Record

struct UndoRecord: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let action: ComputerAction
    let screenshotBefore: Data?
    let description: String

    init(action: ComputerAction, screenshotBefore: Data?) {
        self.id = UUID()
        self.timestamp = Date()
        self.action = action
        self.screenshotBefore = screenshotBefore
        self.description = action.description
    }
}

// MARK: - Sensitive Operation

struct SensitiveOperation: Identifiable {
    let id = UUID()
    let action: ComputerAction
    let description: String
    let risk: RiskLevel

    enum RiskLevel: String {
        case low = "Low"
        case medium = "Medium"
        case high = "High"

        var color: String {
            switch self {
            case .low: return "yellow"
            case .medium: return "orange"
            case .high: return "red"
            }
        }
    }
}
