import Foundation

// MARK: - Gemini Provider

class GeminiProvider: LLMProvider {
    let name = "Gemini"
    let providerType: LLMProviderType = .gemini

    private let apiKey: String
    private let model: String

    init(apiKey: String, model: String = "gemini-2.5-flash") {
        self.apiKey = apiKey
        self.model = model
    }

    func sendMessage(
        messages: [LLMMessage],
        systemPrompt: String,
        tools: [LLMTool],
        maxTokens: Int
    ) async throws -> LLMResponse {
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120

        var body: [String: Any] = [:]

        // System instruction
        body["systemInstruction"] = [
            "parts": [["text": systemPrompt]]
        ]

        // Convert messages to Gemini format
        var contents: [[String: Any]] = []
        for msg in messages {
            contents.append(convertMessage(msg))
        }
        body["contents"] = contents

        // Tools
        let geminiTools = convertTools(tools)
        if !geminiTools.isEmpty {
            body["tools"] = geminiTools
        }

        // Generation config
        body["generationConfig"] = [
            "maxOutputTokens": maxTokens,
            "temperature": 0.7
        ]

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
        let role = msg.role == "assistant" ? "model" : "user"
        var parts: [[String: Any]] = []

        for c in msg.content {
            switch c {
            case .text(let t):
                parts.append(["text": t])
            case .image(let b64, let mediaType):
                parts.append([
                    "inlineData": [
                        "mimeType": mediaType,
                        "data": b64
                    ]
                ])
            case .toolUse(_, let name, let input):
                parts.append([
                    "functionCall": [
                        "name": name,
                        "args": input
                    ]
                ])
            case .toolResult(_, let toolName, let innerContent):
                var hasText = false
                var textResult = "Success"
                var hasImage = false
                
                for ic in innerContent {
                    switch ic {
                    case .text(let t):
                        textResult = t
                        hasText = true
                    case .image(let b64, let mediaType):
                        hasImage = true
                        parts.append([
                            "inlineData": [
                                "mimeType": mediaType,
                                "data": b64
                            ]
                        ])
                    default:
                        break
                    }
                }
                
                if hasImage {
                    textResult = textResult == "Success" ? "Success. The screenshot image is attached in this message. You MUST read the inline image data provided here." : textResult + " (The screenshot image is attached in this message. You MUST read the inline image data provided here.)"
                }
                
                parts.append([
                    "functionResponse": [
                        "name": toolName,
                        "response": ["result": textResult]
                    ]
                ])
            case .thinking:
                break
            }
        }

        return ["role": role, "parts": parts]
    }

    private func convertTools(_ tools: [LLMTool]) -> [[String: Any]] {
        var functionDeclarations: [[String: Any]] = []

        for tool in tools {
            if tool.name == "computer" {
                functionDeclarations.append([
                    "name": "computer",
                    "description": "Control the computer: take screenshots, click, type, scroll, press keys on macOS desktop",
                    "parameters": [
                        "type": "OBJECT",
                        "properties": [
                            "action": [
                                "type": "STRING",
                                "enum": ["screenshot", "left_click", "right_click", "double_click",
                                        "mouse_move", "left_click_drag", "type", "key", "scroll", "wait"],
                                "description": "The action to perform"
                            ],
                            "coordinate": [
                                "type": "ARRAY",
                                "items": ["type": "NUMBER"],
                                "description": "x,y coordinates for mouse actions"
                            ],
                            "start_coordinate": [
                                "type": "ARRAY",
                                "items": ["type": "NUMBER"],
                                "description": "Start x,y for drag"
                            ],
                            "text": ["type": "STRING", "description": "Text to type"],
                            "key": ["type": "STRING", "description": "Key combo"],
                            "direction": [
                                "type": "STRING",
                                "enum": ["up", "down", "left", "right"]
                            ],
                            "amount": ["type": "INTEGER", "description": "Scroll amount"],
                            "duration": ["type": "NUMBER", "description": "Wait seconds"]
                        ],
                        "required": ["action"]
                    ] as [String : Any]
                ])
            } else if tool.name == "terminal" {
                functionDeclarations.append([
                    "name": "terminal",
                    "description": "Execute a shell command in the macOS terminal. Use this to navigate files, search text, or install packages instead of using UI when appropriate.",
                    "parameters": [
                        "type": "OBJECT",
                        "properties": [
                            "command": [
                                "type": "STRING",
                                "description": "The exact shell command to execute"
                            ],
                            "timeout": [
                                "type": "NUMBER",
                                "description": "Timeout in seconds (default: 30)"
                            ]
                        ],
                        "required": ["command"]
                    ] as [String : Any]
                ])
            }
        }

        if functionDeclarations.isEmpty { return [] }
        return [["functionDeclarations": functionDeclarations]]
    }

    private func parseResponse(_ data: Data) throws -> LLMResponse {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let candidate = candidates.first,
              let contentDict = candidate["content"] as? [String: Any],
              let parts = contentDict["parts"] as? [[String: Any]] else {
            throw LLMError.parseError
        }

        let finishReason = candidate["finishReason"] as? String ?? ""
        let stopReason: StopReason = finishReason == "STOP" ? .endTurn : .toolUse

        var content: [LLMContent] = []

        for part in parts {
            if let text = part["text"] as? String {
                content.append(.text(text))
            }
            if let fc = part["functionCall"] as? [String: Any] {
                let name = fc["name"] as? String ?? ""
                let args = fc["args"] as? [String: Any] ?? [:]
                content.append(.toolUse(id: UUID().uuidString, name: name, input: args))
            }
        }

        var usage: TokenUsage?
        if let usageDict = json["usageMetadata"] as? [String: Any] {
            usage = TokenUsage(
                inputTokens: usageDict["promptTokenCount"] as? Int ?? 0,
                outputTokens: usageDict["candidatesTokenCount"] as? Int ?? 0
            )
        }

        return LLMResponse(content: content, stopReason: content.contains(where: {
            if case .toolUse = $0 { return true }
            return false
        }) ? .toolUse : stopReason, usage: usage)
    }
}
