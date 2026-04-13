import Foundation
import SwiftUI

// MARK: - Agent Loop

@MainActor
class AgentLoop: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var currentPlan: TaskPlan?
    @Published var isRunning = false
    @Published var isWaitingForConfirmation = false
    @Published var pendingSensitiveOp: SensitiveOperation?
    @Published var isInputControlled = false  // True when AI is controlling mouse/keyboard
    @Published var statusMessage: String = ""
    @Published var totalTokensUsed: Int = 0

    private var provider: LLMProvider?
    private var llmMessages: [LLMMessage] = []
    private let toolExecutor = ToolExecutor.shared
    private let terminalExecutor = TerminalExecutor.shared
    private let screenCapture = ScreenCapture.shared
    private var continuationForConfirmation: CheckedContinuation<Bool, Never>?
    private var currentTask: Task<Void, Never>?
    private let settings = AppSettings.shared

    var maxIterations: Int { settings.maxIterations }

    // MARK: - Provider Management

    func setupProvider() {
        let providerType = settings.selectedProvider
        let apiKey = settings.apiKey(for: providerType)

        guard !apiKey.isEmpty else {
            provider = nil
            return
        }

        switch providerType {
        case .claude:
            provider = ClaudeProvider(apiKey: apiKey, model: settings.selectedModel)
        case .openai:
            provider = OpenAIProvider(apiKey: apiKey, model: settings.selectedModel)
        case .gemini:
            provider = GeminiProvider(apiKey: apiKey, model: settings.selectedModel)
        case .custom:
            let modelName = settings.customModelName.isEmpty ? settings.selectedModel : settings.customModelName
            if settings.customApiFormat == "Claude" {
                provider = ClaudeProvider(apiKey: apiKey, model: modelName, customEndpoint: settings.customEndpoint)
            } else {
                provider = OpenAIProvider(apiKey: apiKey, model: modelName, customEndpoint: settings.customEndpoint)
            }
        }
    }

    // MARK: - Send Message

    func sendMessage(_ text: String, images: [Data] = []) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !isRunning else { return }

        setupProvider()
        guard provider != nil else {
            addMessage(.system(text: "⚠️ No API key configured. Please set up your API key in Settings."))
            return
        }

        // Add user message
        let userMsg = ChatMessage.user(text: text, images: images)
        addMessage(userMsg)

        // Start the agent task
        currentTask = Task {
            await runAgentLoop(userText: text, userImages: images)
        }
    }

    // MARK: - Agent Loop Core

    private func runAgentLoop(userText: String, userImages: [Data]) async {
        isRunning = true
        statusMessage = "Thinking..."

        // Get screen info
        let dims = screenCapture.getScaledDimensions()
        let displayInfo = screenCapture.getDisplayInfo()

        // Build system prompt and tools based on mode
        let systemPrompt: String
        let tools: [LLMTool]
        
        let isAgentMode = AppSettings.shared.isAgentMode
        
        if isAgentMode {
            systemPrompt = SystemPrompts.computerUsePrompt(
                screenWidth: displayInfo.width,
                screenHeight: displayInfo.height,
                scaledWidth: dims.width,
                scaledHeight: dims.height
            )
            tools = buildTools(scaledWidth: dims.width, scaledHeight: dims.height)
        } else {
            systemPrompt = SystemPrompts.chatOnlyPrompt()
            tools = []
        }

        // Initialize LLM messages
        var userContent: [LLMContent] = [.text(userText)]
        for img in userImages {
            userContent.append(.image(img.base64EncodedString(), mediaType: "image/jpeg"))
        }
        
        // In agent mode, automatically attach a screenshot for context
        // so the model doesn't need to waste a turn calling screenshot first
        if isAgentMode && userImages.isEmpty {
            statusMessage = "Capturing screen..."
            if let screenshotData = await screenCapture.captureScreenAsJPEG() {
                let b64 = screenshotData.base64EncodedString()
                userContent.append(.image(b64, mediaType: "image/jpeg"))
                userContent[0] = .text(userText + "\n\n[Current screenshot of the screen is attached above. You can see the current state — start working immediately without taking another screenshot.]")
                print("[AgentLoop] Pre-attached screenshot: \(screenshotData.count) bytes")
            }
        }
        
        llmMessages.append(LLMMessage(role: "user", content: userContent))

        // Agent loop
        var iterations = 0
        while iterations < maxIterations {
            iterations += 1
            statusMessage = "Processing... (step \(iterations))"

            do {
                guard let provider = self.provider else { break }

                let response = try await provider.sendMessage(
                    messages: llmMessages,
                    systemPrompt: systemPrompt,
                    tools: tools,
                    maxTokens: 4096
                )

                // Track token usage
                if let usage = response.usage {
                    totalTokensUsed += usage.inputTokens + usage.outputTokens
                }

                // Add assistant response to conversation
                llmMessages.append(LLMMessage.assistant(content: response.content))

                // Display text responses
                let textResponse = response.textContent
                
                // Detect "empty message" error from provider (Gemini specific)
                if textResponse.contains("It looks like your message came through empty") {
                    print("[AgentLoop] Received 'empty message' response. Retrying generation (step \(iterations))...")
                    statusMessage = "Retrying response..."
                    // Do not add to llmMessages, just retry the same turn
                    continue
                }

                if !textResponse.isEmpty {
                    addMessage(.assistant(text: textResponse))
                }

                // Check if there are tool calls
                if response.hasToolCalls {
                    // Process tool calls
                    var toolResults: [LLMContent] = []

                    for toolCall in response.toolCalls {
                        if toolCall.name == "computer" {
                            guard let action = toolExecutor.parseAction(from: toolCall.input) else {
                                toolResults.append(.toolResult(
                                    toolUseId: toolCall.id,
                                    toolName: toolCall.name,
                                    innerContent: [.text("Error: Could not parse action")]
                                ))
                                continue
                            }

                            // Check for sensitive operation
                            if let sensitiveOp = toolExecutor.checkSensitivity(action) {
                                statusMessage = "⚠️ Awaiting confirmation..."
                                let approved = await requestConfirmation(sensitiveOp)
                                if !approved {
                                    toolResults.append(.toolResult(
                                        toolUseId: toolCall.id,
                                        toolName: toolCall.name,
                                        innerContent: [.text("User declined this action. Try a different approach or skip this step.")]
                                    ))
                                    continue
                                }
                            }

                            // Show input control warning for non-screenshot actions
                            if action.requiresInputControl {
                                isInputControlled = true
                                statusMessage = "🖱️ Controlling: \(action.description)"
                            }

                            // Update plan progress
                            updatePlanProgress(for: action)

                            // Execute the action
                            let result = await toolExecutor.executeAction(action, scaleFactor: dims.scale)

                            isInputControlled = false

                            // Build tool result
                            var innerContent: [LLMContent] = [.text(result.message)]
                            if let screenshot = result.screenshot {
                                let b64 = screenshot.base64EncodedString()
                                print("[AgentLoop] Attaching screenshot to tool result: \(b64.count) chars base64 (\(screenshot.count) bytes)")
                                innerContent.append(.image(b64, mediaType: "image/jpeg"))
                            } else {
                                print("[AgentLoop] No screenshot in tool result for action: \(action.description)")
                            }
                            toolResults.append(.toolResult(toolUseId: toolCall.id, toolName: toolCall.name, innerContent: innerContent))
                        
                        } else if toolCall.name == "terminal" {
                            // Terminal tool
                            let command = toolCall.input["command"] as? String ?? ""
                            let timeoutVal = toolCall.input["timeout"] as? Double ?? 30.0
                            
                            guard !command.isEmpty else {
                                toolResults.append(.toolResult(
                                    toolUseId: toolCall.id,
                                    toolName: toolCall.name,
                                    innerContent: [.text("Error: No command provided")]
                                ))
                                continue
                            }
                            
                            // Check for dangerous commands
                            let lower = command.lowercased()
                            if lower.contains("rm -rf /") || lower.contains("mkfs") || lower.contains("dd if=") {
                                if AppSettings.shared.confirmSensitiveOps {
                                    let op = SensitiveOperation(
                                        action: .key(keys: command),
                                        description: "Dangerous terminal command: \(command)",
                                        risk: .high
                                    )
                                    statusMessage = "⚠️ Awaiting confirmation..."
                                    let approved = await requestConfirmation(op)
                                    if !approved {
                                        toolResults.append(.toolResult(
                                            toolUseId: toolCall.id,
                                            toolName: toolCall.name,
                                            innerContent: [.text("User declined this command.")]
                                        ))
                                        continue
                                    }
                                }
                            }
                            
                            statusMessage = "💻 Running: \(command.prefix(50))..."
                            print("[AgentLoop] Running terminal command: \(command)")
                            
                            let termResult = await terminalExecutor.runCommand(command, timeout: timeoutVal)
                            
                            print("[AgentLoop] Terminal exit code: \(termResult.exitCode), stdout: \(termResult.stdout.count) chars")
                            
                            toolResults.append(.toolResult(
                                toolUseId: toolCall.id,
                                toolName: toolCall.name,
                                innerContent: [.text(termResult.formattedOutput)]
                            ))
                        }
                    }

                    // Add tool results as user message
                    llmMessages.append(LLMMessage(role: "user", content: toolResults))
                } else {
                    // No tool calls — task is done
                    break
                }

                // Check if we should stop
                if response.stopReason == .endTurn || response.stopReason == .maxTokens {
                    if !response.hasToolCalls {
                        break
                    }
                }

            } catch {
                addMessage(.system(text: "❌ Error: \(error.localizedDescription)"))
                break
            }
        }

        if iterations >= maxIterations {
            addMessage(.system(text: "⚠️ Reached maximum iteration limit (\(maxIterations)). Task may be incomplete."))
        }

        // Mark plan as completed
        if var plan = currentPlan, !plan.isCompleted {
            plan.status = .completed
            currentPlan = plan
        }

        isRunning = false
        isInputControlled = false
        statusMessage = ""

        // Save to history
        HistoryManager.shared.saveSession(messages)
    }

    // MARK: - Confirmation

    func requestConfirmation(_ op: SensitiveOperation) async -> Bool {
        pendingSensitiveOp = op
        isWaitingForConfirmation = true

        return await withCheckedContinuation { continuation in
            continuationForConfirmation = continuation
        }
    }

    func respondToConfirmation(_ approved: Bool) {
        isWaitingForConfirmation = false
        pendingSensitiveOp = nil
        continuationForConfirmation?.resume(returning: approved)
        continuationForConfirmation = nil
    }

    // MARK: - Plan Management

    func setPlan(_ plan: TaskPlan) {
        currentPlan = plan
    }

    private func updatePlanProgress(for action: ComputerAction) {
        // Auto-advance plan steps based on actions
        guard var plan = currentPlan else { return }
        if plan.currentStepIndex != nil {
            // Keep current step running
            return
        }
        // Find next pending step and mark it running
        if let nextIdx = plan.steps.firstIndex(where: { $0.status == .pending }) {
            plan.markStepRunning(nextIdx)
            currentPlan = plan
        }
    }

    func markCurrentStepCompleted(note: String? = nil) {
        guard var plan = currentPlan,
              let idx = plan.currentStepIndex else { return }
        plan.markStepCompleted(idx, note: note)
        currentPlan = plan
    }

    // MARK: - Undo

    func undoLastAction() async -> String {
        return await ActionUndoManager.shared.undo()
    }

    // MARK: - Stop

    func stopExecution() {
        currentTask?.cancel()
        currentTask = nil
        isRunning = false
        isInputControlled = false
        statusMessage = "Stopped"

        if var plan = currentPlan {
            plan.status = .cancelled
            currentPlan = plan
        }
    }

    // MARK: - New Session

    func newSession() {
        messages.removeAll()
        llmMessages.removeAll()
        currentPlan = nil
        isRunning = false
        isInputControlled = false
        statusMessage = ""
        pendingSensitiveOp = nil
        isWaitingForConfirmation = false
        totalTokensUsed = 0
    }

    // MARK: - Helpers

    private func addMessage(_ msg: ChatMessage) {
        messages.append(msg)
    }

    private func buildTools(scaledWidth: Int, scaledHeight: Int) -> [LLMTool] {
        let isClaudeProvider = settings.selectedProvider == .claude

        var tools: [LLMTool] = []
        
        if isClaudeProvider {
            // Claude uses built-in computer use tool
            tools.append(
                LLMTool(
                    type: "computer_20250124",
                    name: "computer",
                    properties: [
                        "display_width_px": scaledWidth,
                        "display_height_px": scaledHeight,
                        "display_number": 1
                    ]
                )
            )
        } else {
            // Other providers use function calling
            tools.append(
                LLMTool(
                    type: "function",
                    name: "computer",
                    properties: [
                        "display_width_px": scaledWidth,
                        "display_height_px": scaledHeight
                    ]
                )
            )
        }
        
        // Terminal tool (available for all providers)
        tools.append(
            LLMTool(
                type: "function",
                name: "terminal",
                properties: [
                    "description": "Execute a shell command in the macOS terminal. Use this to navigate files, search text, or install packages instead of using UI when appropriate.",
                    "input_schema": [
                        "type": "object",
                        "properties": [
                            "command": [
                                "type": "string",
                                "description": "The exact shell command to execute"
                            ],
                            "timeout": [
                                "type": "number",
                                "description": "Timeout in seconds (default: 30)"
                            ]
                        ],
                        "required": ["command"]
                    ]
                ]
            )
        )
        
        return tools
    }
}
