import Foundation

// MARK: - LLM Provider Protocol

protocol LLMProvider {
    var name: String { get }
    var providerType: LLMProviderType { get }

    func sendMessage(
        messages: [LLMMessage],
        systemPrompt: String,
        tools: [LLMTool],
        maxTokens: Int
    ) async throws -> LLMResponse
}

// MARK: - LLM Message (normalized format for all providers)

struct LLMMessage: Codable {
    let role: String  // "user", "assistant", "system", "tool"
    var content: [LLMContent]

    static func user(text: String, images: [Data] = []) -> LLMMessage {
        var contents: [LLMContent] = [.text(text)]
        for img in images {
            contents.append(.image(img.base64EncodedString(), mediaType: "image/jpeg"))
        }
        return LLMMessage(role: "user", content: contents)
    }

    static func assistant(content: [LLMContent]) -> LLMMessage {
        return LLMMessage(role: "assistant", content: content)
    }

    static func toolResult(toolUseId: String, toolName: String, content: String, image: Data? = nil) -> LLMMessage {
        var contents: [LLMContent] = [.text(content)]
        if let img = image {
            contents.append(.image(img.base64EncodedString(), mediaType: "image/jpeg"))
        }
        return LLMMessage(role: "user", content: [.toolResult(toolUseId: toolUseId, toolName: toolName, innerContent: contents)])
    }
}

// MARK: - LLM Content

enum LLMContent: Codable {
    case text(String)
    case image(String, mediaType: String)  // base64, mediaType
    case toolUse(id: String, name: String, input: [String: Any])
    case toolResult(toolUseId: String, toolName: String, innerContent: [LLMContent])
    case thinking(String)

    enum CodingKeys: String, CodingKey {
        case type, text, source, id, name, input, toolUseId, content
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let t):
            try container.encode("text", forKey: .type)
            try container.encode(t, forKey: .text)
        case .image(let data, let mediaType):
            try container.encode("image", forKey: .type)
            try container.encode(["type": "base64", "media_type": mediaType, "data": data], forKey: .source)
        case .toolUse(let id, let name, _):
            try container.encode("tool_use", forKey: .type)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
        case .toolResult(let toolUseId, let toolName, let content):
            try container.encode("tool_result", forKey: .type)
            try container.encode(toolUseId, forKey: .toolUseId)
            try container.encode(toolName, forKey: .name)
            try container.encode(content, forKey: .content)
        case .thinking(let t):
            try container.encode("thinking", forKey: .type)
            try container.encode(t, forKey: .text)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "text":
            let text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
            self = .text(text)
        case "thinking":
            let text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
            self = .thinking(text)
        case "image":
            let source = try container.decode([String: String].self, forKey: .source)
            let data = source["data"] ?? ""
            let mediaType = source["media_type"] ?? "image/jpeg"
            self = .image(data, mediaType: mediaType)
        case "tool_result":
            let id = try container.decode(String.self, forKey: .toolUseId)
            let name = try container.decodeIfPresent(String.self, forKey: .name) ?? "computer"
            let content = try container.decodeIfPresent([LLMContent].self, forKey: .content) ?? []
            self = .toolResult(toolUseId: id, toolName: name, innerContent: content)
        default:
            self = .text("")
        }
    }
}

// MARK: - LLM Tool

struct LLMTool {
    let type: String
    let name: String
    let properties: [String: Any]
}

// MARK: - LLM Response

struct LLMResponse {
    let content: [LLMContent]
    let stopReason: StopReason
    let usage: TokenUsage?

    var textContent: String {
        content.compactMap {
            if case .text(let t) = $0 { return t }
            return nil
        }.joined(separator: "\n")
    }

    var toolCalls: [(id: String, name: String, input: [String: Any])] {
        content.compactMap {
            if case .toolUse(let id, let name, let input) = $0 {
                return (id, name, input)
            }
            return nil
        }
    }

    var hasToolCalls: Bool {
        !toolCalls.isEmpty
    }
}

enum StopReason: String {
    case endTurn = "end_turn"
    case toolUse = "tool_use"
    case maxTokens = "max_tokens"
    case stop = "stop"
    case unknown
}

struct TokenUsage {
    let inputTokens: Int
    let outputTokens: Int
}
