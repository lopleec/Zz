import Foundation

// MARK: - OpenAI Provider

class OpenAIProvider: LLMProvider {
    let name = "OpenAI"
    let providerType: LLMProviderType = .openai

    private let apiKey: String
    private let model: String
    private let customEndpoint: String?

    init(apiKey: String, model: String = "gpt-4o", customEndpoint: String? = nil) {
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
        let defaultUrl = "https://api.openai.com/v1/chat/completions"
        let urlStr = customEndpoint ?? defaultUrl
        let finalUrlStr = urlStr.contains("/chat/completions") ? urlStr : "\(urlStr)/chat/completions"
        
        guard let url = URL(string: finalUrlStr) else {
            throw LLMError.apiError(statusCode: 0, message: "Invalid endpoint URL: \(finalUrlStr)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 120

        var body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
        ]

        // Build messages with system prompt
        var oaiMessages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt]
        ]

        for msg in messages {
            oaiMessages.append(contentsOf: convertMessage(msg))
        }
        body["messages"] = oaiMessages

        // Convert tools to OpenAI function calling format
        let oaiTools = tools.compactMap { convertToFunctionTool($0) }
        if !oaiTools.isEmpty {
            body["tools"] = oaiTools
        }

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

    private func convertMessage(_ msg: LLMMessage) -> [[String: Any]] {
        if msg.role == "user" {
            // Check if this message contains tool results
            let toolResults = msg.content.compactMap { c -> (String, [LLMContent])? in
                if case .toolResult(let toolUseId, _, let inner) = c { return (toolUseId, inner) }
                return nil
            }
            
            if !toolResults.isEmpty {
                var messages: [[String: Any]] = []
                
                for (toolUseId, inner) in toolResults {
                    var textParts: [String] = []
                    var imageB64: String? = nil
                    
                    for ic in inner {
                        switch ic {
                        case .text(let t):
                            textParts.append(t)
                        case .image(let b64, _):
                            imageB64 = b64
                        default: break
                        }
                    }
                    
                    var toolText = textParts.joined(separator: "\n")
                    if imageB64 != nil {
                        toolText += "\n[Screenshot captured and attached in the next message. You MUST examine the image carefully.]"
                    }
                    
                    // Tool result message (text only — OpenAI tool messages don't reliably support images)
                    messages.append([
                        "role": "tool",
                        "tool_call_id": toolUseId,
                        "content": toolText
                    ])
                    
                    // If there's an image, send it as a separate user message so the model actually sees it
                    if let b64 = imageB64 {
                        messages.append([
                            "role": "user",
                            "content": [
                                ["type": "text", "text": "Here is the screenshot result from the tool call. Describe what you see and proceed with the task:"] as [String: Any],
                                ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(b64)"]] as [String: Any]
                            ] as [[String: Any]]
                        ])
                    }
                }
                
                return messages
            }
        }

        // Non-tool-result messages
        var result: [String: Any] = ["role": msg.role == "user" ? "user" : msg.role]

        // Check if content has images
        let hasImages = msg.content.contains {
            if case .image = $0 { return true }
            return false
        }

        if hasImages {
            var parts: [[String: Any]] = []
            for c in msg.content {
                switch c {
                case .text(let t):
                    parts.append(["type": "text", "text": t])
                case .image(let b64, _):
                    parts.append([
                        "type": "image_url",
                        "image_url": ["url": "data:image/jpeg;base64,\(b64)"]
                    ])
                default:
                    break
                }
            }
            result["content"] = parts
        } else {
            // Handle tool_use content for assistant messages
            if msg.role == "assistant" {
                var textParts: [String] = []
                var toolCalls: [[String: Any]] = []

                for c in msg.content {
                    switch c {
                    case .text(let t):
                        textParts.append(t)
                    case .toolUse(let id, let name, let input):
                        let inputJSON = (try? JSONSerialization.data(withJSONObject: input)).flatMap {
                            String(data: $0, encoding: .utf8)
                        } ?? "{}"
                        toolCalls.append([
                            "id": id,
                            "type": "function",
                            "function": [
                                "name": name,
                                "arguments": inputJSON
                            ]
                        ])
                    default:
                        break
                    }
                }

                result["content"] = textParts.joined(separator: "\n")
                if !toolCalls.isEmpty {
                    result["tool_calls"] = toolCalls
                }
            } else {
                result["content"] = msg.content.compactMap {
                    if case .text(let t) = $0 { return t }
                    return nil
                }.joined(separator: "\n")
            }
        }

        return [result]
    }

    private func convertToFunctionTool(_ tool: LLMTool) -> [String: Any]? {
        // Convert computer use tool to OpenAI function calling format
        if tool.name == "computer" {
            return [
                "type": "function",
                "function": [
                    "name": "computer",
                    "description": "Control the computer: take screenshots, click, type, scroll, press keys",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "action": [
                                "type": "string",
                                "enum": ["screenshot", "left_click", "right_click", "double_click",
                                        "triple_click", "middle_click", "mouse_move", "left_click_drag",
                                        "type", "key", "scroll", "wait"],
                                "description": "The action to perform"
                            ],
                            "coordinate": [
                                "type": "array",
                                "items": ["type": "number"],
                                "description": "x,y coordinates for mouse actions"
                            ],
                            "start_coordinate": [
                                "type": "array",
                                "items": ["type": "number"],
                                "description": "Start x,y for drag actions"
                            ],
                            "text": [
                                "type": "string",
                                "description": "Text to type"
                            ],
                            "key": [
                                "type": "string",
                                "description": "Key combo like cmd+s"
                            ],
                            "direction": [
                                "type": "string",
                                "enum": ["up", "down", "left", "right"]
                            ],
                            "amount": [
                                "type": "integer",
                                "description": "Scroll amount"
                            ],
                            "duration": [
                                "type": "number",
                                "description": "Wait duration in seconds"
                            ]
                        ],
                        "required": ["action"]
                    ] as [String : Any]
                ] as [String : Any]
            ]
        } else if tool.name == "terminal" {
            return [
                "type": "function",
                "function": [
                    "name": "terminal",
                    "description": "Execute a shell command in the macOS terminal. Use this to navigate files, search text, or install packages instead of using UI when appropriate.",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "command": [
                                "type": "string",
                                "description": "The exact shell command to execute"
                            ],
                            "timeout": [
                                "type": "number",
                                "description": "Timeout in seconds (default: 30, max: 120)"
                            ]
                        ],
                        "required": ["command"]
                    ] as [String : Any]
                ] as [String : Any]
            ]
        }
        return nil
    }

    private func parseResponse(_ data: Data) throws -> LLMResponse {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let choice = choices.first,
              let message = choice["message"] as? [String: Any] else {
            throw LLMError.parseError
        }

        let finishReason = choice["finish_reason"] as? String ?? ""
        let stopReason: StopReason
        switch finishReason {
        case "stop": stopReason = .endTurn
        case "tool_calls": stopReason = .toolUse
        case "length": stopReason = .maxTokens
        default: stopReason = .unknown
        }

        var content: [LLMContent] = []

        // Parse text content
        if let text = message["content"] as? String, !text.isEmpty {
            content.append(.text(text))
        }

        // Parse tool calls
        if let toolCalls = message["tool_calls"] as? [[String: Any]] {
            for tc in toolCalls {
                let id = tc["id"] as? String ?? UUID().uuidString
                if let function = tc["function"] as? [String: Any] {
                    let name = function["name"] as? String ?? ""
                    let argsStr = function["arguments"] as? String ?? "{}"
                    let input = (try? JSONSerialization.jsonObject(
                        with: argsStr.data(using: .utf8) ?? Data()
                    ) as? [String: Any]) ?? [:]
                    content.append(.toolUse(id: id, name: name, input: input))
                }
            }
        }

        var usage: TokenUsage?
        if let usageDict = json["usage"] as? [String: Any] {
            usage = TokenUsage(
                inputTokens: usageDict["prompt_tokens"] as? Int ?? 0,
                outputTokens: usageDict["completion_tokens"] as? Int ?? 0
            )
        }

        return LLMResponse(content: content, stopReason: stopReason, usage: usage)
    }
}
