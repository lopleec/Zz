import Foundation
import SwiftUI

// MARK: - LLM Provider Type

enum LLMProviderType: String, Codable, CaseIterable, Identifiable {
    case claude = "Claude"
    case openai = "OpenAI"
    case gemini = "Gemini"
    case custom = "Custom"

    var id: String { rawValue }

    var defaultModel: String {
        switch self {
        case .claude: return "claude-sonnet-4-20250514"
        case .openai: return "gpt-4o"
        case .gemini: return "gemini-2.5-flash"
        case .custom: return ""
        }
    }

    var iconName: String {
        switch self {
        case .claude: return "c.circle"
        case .openai: return "o.circle"
        case .gemini: return "g.circle"
        case .custom: return "gearshape.circle"
        }
    }
}

// MARK: - App Settings

class AppSettings: ObservableObject {
    static let shared = AppSettings()

    // API Keys
    @AppStorage("claudeAPIKey") var claudeAPIKey: String = ""
    @AppStorage("openaiAPIKey") var openaiAPIKey: String = ""
    @AppStorage("geminiAPIKey") var geminiAPIKey: String = ""
    @AppStorage("customAPIKey") var customAPIKey: String = ""
    @AppStorage("customEndpoint") var customEndpoint: String = ""
    @AppStorage("customModelName") var customModelName: String = ""
    @AppStorage("customApiFormat") var customApiFormat: String = "OpenAI"

    // Modes
    @AppStorage("isAgentMode") var isAgentMode: Bool = true

    // Provider Selection
    @AppStorage("selectedProvider") var selectedProviderRaw: String = LLMProviderType.claude.rawValue
    @AppStorage("selectedModel") var selectedModel: String = "claude-sonnet-4-20250514"

    // Hotkey
    @AppStorage("hotkeyModifiers") var hotkeyModifiers: Int = 0x180100    // Cmd+Shift
    @AppStorage("hotkeyKeyCode") var hotkeyKeyCode: Int = 49             // Space

    // Agent
    @AppStorage("maxIterations") var maxIterations: Int = 30
    @AppStorage("autoExecutePlan") var autoExecutePlan: Bool = true
    @AppStorage("confirmSensitiveOps") var confirmSensitiveOps: Bool = true

    // UI
    @AppStorage("showPlanForSimpleTasks") var showPlanForSimpleTasks: Bool = false

    // Onboarding
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false

    var selectedProvider: LLMProviderType {
        get { LLMProviderType(rawValue: selectedProviderRaw) ?? .claude }
        set { selectedProviderRaw = newValue.rawValue }
    }

    func apiKey(for provider: LLMProviderType) -> String {
        switch provider {
        case .claude: return claudeAPIKey
        case .openai: return openaiAPIKey
        case .gemini: return geminiAPIKey
        case .custom: return customAPIKey
        }
    }

    func setApiKey(_ key: String, for provider: LLMProviderType) {
        switch provider {
        case .claude: claudeAPIKey = key
        case .openai: openaiAPIKey = key
        case .gemini: geminiAPIKey = key
        case .custom: customAPIKey = key
        }
    }

    var hasValidConfig: Bool {
        let key = apiKey(for: selectedProvider)
        if selectedProvider == .custom {
            return !key.isEmpty && !customEndpoint.isEmpty
        }
        return !key.isEmpty
    }
}
