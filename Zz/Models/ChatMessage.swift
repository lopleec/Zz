import Foundation
import AppKit

// MARK: - Chat Message

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let role: MessageRole
    let timestamp: Date
    var content: [MessageContent]
    var plan: TaskPlan?
    var isStreaming: Bool

    init(role: MessageRole, content: [MessageContent], plan: TaskPlan? = nil) {
        self.id = UUID()
        self.role = role
        self.timestamp = Date()
        self.content = content
        self.plan = plan
        self.isStreaming = false
    }

    static func user(text: String, images: [Data] = []) -> ChatMessage {
        var contents: [MessageContent] = [.text(text)]
        for img in images {
            contents.append(.image(img))
        }
        return ChatMessage(role: .user, content: contents)
    }

    static func assistant(text: String) -> ChatMessage {
        return ChatMessage(role: .assistant, content: [.text(text)])
    }

    static func system(text: String) -> ChatMessage {
        return ChatMessage(role: .system, content: [.text(text)])
    }

    var textContent: String {
        content.compactMap {
            if case .text(let t) = $0 { return t }
            return nil
        }.joined(separator: "\n")
    }
}

// MARK: - Message Role

enum MessageRole: String, Codable {
    case user
    case assistant
    case system
    case tool
}

// MARK: - Message Content

enum MessageContent: Codable {
    case text(String)
    case image(Data)
    case toolCall(ToolCall)
    case toolResult(ToolResult)

    enum CodingKeys: String, CodingKey {
        case type, value, data
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let s):
            try container.encode("text", forKey: .type)
            try container.encode(s, forKey: .value)
        case .image(let d):
            try container.encode("image", forKey: .type)
            try container.encode(d.base64EncodedString(), forKey: .data)
        case .toolCall(let tc):
            try container.encode("tool_call", forKey: .type)
            try container.encode(tc, forKey: .value)
        case .toolResult(let tr):
            try container.encode("tool_result", forKey: .type)
            try container.encode(tr, forKey: .value)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "text":
            let s = try container.decode(String.self, forKey: .value)
            self = .text(s)
        case "image":
            let d = try container.decode(String.self, forKey: .data)
            self = .image(Data(base64Encoded: d) ?? Data())
        case "tool_call":
            let tc = try container.decode(ToolCall.self, forKey: .value)
            self = .toolCall(tc)
        case "tool_result":
            let tr = try container.decode(ToolResult.self, forKey: .value)
            self = .toolResult(tr)
        default:
            self = .text("")
        }
    }
}

// MARK: - Tool Call / Result

struct ToolCall: Codable, Identifiable {
    let id: String
    let name: String
    let input: [String: AnyCodable]
}

struct ToolResult: Codable {
    let toolUseId: String
    let content: String
    let isError: Bool
    var screenshot: Data?
}

// MARK: - AnyCodable Helper

struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            value = intVal
        } else if let doubleVal = try? container.decode(Double.self) {
            value = doubleVal
        } else if let boolVal = try? container.decode(Bool.self) {
            value = boolVal
        } else if let stringVal = try? container.decode(String.self) {
            value = stringVal
        } else if let arrayVal = try? container.decode([AnyCodable].self) {
            value = arrayVal.map { $0.value }
        } else if let dictVal = try? container.decode([String: AnyCodable].self) {
            value = dictVal.mapValues { $0.value }
        } else {
            value = ""
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let intVal = value as? Int {
            try container.encode(intVal)
        } else if let doubleVal = value as? Double {
            try container.encode(doubleVal)
        } else if let boolVal = value as? Bool {
            try container.encode(boolVal)
        } else if let stringVal = value as? String {
            try container.encode(stringVal)
        } else {
            try container.encode("\(value)")
        }
    }
}
