import Foundation

// MARK: - Claude Provider

class ClaudeProvider: LLMProvider {
    let name = "Claude"
    let providerType: LLMProviderType = .claude

    private let apiKey: String
    private let model: String
    private let customEndpoint: String?
    private let betaHeader = "computer-use-2025-01-24"

    init(apiKey: String, model: String = "claude-sonnet-4-20250514", customEndpoint: String? = nil) {
        self.apiKey = apiKey
        self.model = model
        if let endpoint = customEndpoint, !endpoint.isEmpty {
            self.customEndpoint = endpoint.hasSuffix("/") ? String(endpoint.dropLast()) : endpoint
        } else {
            self.customEndpoint = nil
        }
    }

    func sendMessage(
        messages: [LLMMessage],
        systemPrompt: String,
        tools: [LLMTool],
        maxTokens: Int
    ) async throws -> LLMResponse {
        let defaultUrl = "https://api.anthropic.com/v1/messages"
        let urlStr = customEndpoint ?? defaultUrl
        let finalUrlStr = urlStr.contains("/messages") ? urlStr : "\(urlStr)/messages"
        
        guard let url = URL(string: finalUrlStr) else {
            throw LLMError.apiError(statusCode: 0, message: "Invalid endpoint URL: \(finalUrlStr)")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "content-type")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.addValue(betaHeader, forHTTPHeaderField: "anthropic-beta")
        request.timeoutInterval = 120

        // Build request body
        var body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "system": systemPrompt,
        ]

        // Convert messages
        body["messages"] = messages.map { convertMessage($0) }

        // Convert tools
        body["tools"] = tools.map { convertTool($0) }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw LLMError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        return try parseResponse(data)
    }

    // MARK: - Private

    private func convertMessage(_ msg: LLMMessage) -> [String: Any] {
        var result: [String: Any] = ["role": msg.role]
        var content: [[String: Any]] = []

        for c in msg.content {
            switch c {
            case .text(let text):
                content.append(["type": "text", "text": text])
            case .image(let b64, let mediaType):
                content.append([
                    "type": "image",
                    "source": [
                        "type": "base64",
                        "media_type": mediaType,
                        "data": b64
                    ]
                ])
            case .toolUse(let id, let name, let input):
                content.append([
                    "type": "tool_use",
                    "id": id,
                    "name": name,
                    "input": input
                ])
            case .toolResult(let toolUseId, _, let innerContent):
                var inner: [[String: Any]] = []
                for ic in innerContent {
                    switch ic {
                    case .text(let t):
                        inner.append(["type": "text", "text": t])
                    case .image(let b64, let mt):
                        inner.append([
                            "type": "image",
                            "source": ["type": "base64", "media_type": mt, "data": b64]
                        ])
                    default:
                        break
                    }
                }
                content.append([
                    "type": "tool_result",
                    "tool_use_id": toolUseId,
                    "content": inner
                ])
            case .thinking:
                break
            }
        }

        result["content"] = content
        return result
    }

    private func convertTool(_ tool: LLMTool) -> [String: Any] {
        var result: [String: Any] = [
            "type": tool.type,
            "name": tool.name
        ]
        for (k, v) in tool.properties {
            result[k] = v
        }
        return result
    }

    private func parseResponse(_ data: Data) throws -> LLMResponse {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LLMError.parseError
        }

        let stopReason = StopReason(rawValue: json["stop_reason"] as? String ?? "") ?? .unknown

        var content: [LLMContent] = []

        if let contentArray = json["content"] as? [[String: Any]] {
            for item in contentArray {
                let type = item["type"] as? String ?? ""
                switch type {
                case "text":
                    let text = item["text"] as? String ?? ""
                    content.append(.text(text))
                case "tool_use":
                    let id = item["id"] as? String ?? ""
                    let name = item["name"] as? String ?? ""
                    let input = item["input"] as? [String: Any] ?? [:]
                    content.append(.toolUse(id: id, name: name, input: input))
                case "thinking":
                    let text = item["thinking"] as? String ?? ""
                    content.append(.thinking(text))
                default:
                    break
                }
            }
        }

        var usage: TokenUsage?
        if let usageDict = json["usage"] as? [String: Any] {
            usage = TokenUsage(
                inputTokens: usageDict["input_tokens"] as? Int ?? 0,
                outputTokens: usageDict["output_tokens"] as? Int ?? 0
            )
        }

        return LLMResponse(content: content, stopReason: stopReason, usage: usage)
    }
}

// MARK: - LLM Error

enum LLMError: LocalizedError {
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case parseError
    case noApiKey
    case unsupportedProvider

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid response from API"
        case .apiError(let code, let msg): return "API Error (\(code)): \(msg)"
        case .parseError: return "Failed to parse API response"
        case .noApiKey: return "No API key configured"
        case .unsupportedProvider: return "Unsupported LLM provider"
        }
    }
}
