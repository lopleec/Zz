import SwiftUI
import AppKit

// MARK: - Onboarding View

struct OnboardingView: View {
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var settings = AppSettings.shared
    @State private var currentStep = 0
    @State private var apiKeyInput = ""
    @State private var selectedProvider: LLMProviderType = .claude
    @State private var hasAXPermission = AccessibilityReader.shared.hasPermission
    @State private var hasSCPermission = ScreenCapture.shared.hasScreenRecordingPermission
    let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    var onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Zz")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("Step \(currentStep + 1)/3")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.primary.opacity(0.08))
                    Rectangle()
                        .fill(Color.primary.opacity(0.4))
                        .frame(width: geo.size.width * CGFloat(currentStep + 1) / 3)
                        .animation(.easeInOut(duration: 0.3), value: currentStep)
                }
            }
            .frame(height: 2)

            // Content
            TabView(selection: $currentStep) {
                welcomeStep.tag(0)
                permissionsStep.tag(1)
                apiKeyStep.tag(2)
            }
            .tabViewStyle(.automatic)

            // Navigation
            HStack {
                if currentStep > 0 {
                    Button("Back") {
                        withAnimation { currentStep -= 1 }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    .font(.system(size: 12, weight: .medium))
                }

                Spacer()

                if currentStep < 2 {
                    Button(action: {
                        withAnimation { currentStep += 1 }
                    }) {
                        Text("Next")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(colorScheme == .dark ? .black : .white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 7)
                            .background(
                                Capsule().fill(Color.primary)
                            )
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: {
                        saveAndComplete()
                    }) {
                        Text("Get Started")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(colorScheme == .dark ? .black : .white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 7)
                            .background(
                                Capsule().fill(Color.primary)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 380, height: 460)
        .background(.regularMaterial)
    }

    // MARK: - Step 1: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 36))
                .foregroundColor(.primary)

            VStack(spacing: 6) {
                Text("Welcome to Zz")
                    .font(.system(size: 18, weight: .semibold))

                Text("Your AI desktop assistant that can see and control your Mac.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            VStack(alignment: .leading, spacing: 10) {
                featureRow(icon: "keyboard", text: "Summon with ⌘+Shift+Space")
                featureRow(icon: "eye", text: "See your screen content")
                featureRow(icon: "cursorarrow.click", text: "Control mouse & keyboard")
                featureRow(icon: "brain.head.profile", text: "Plan and execute tasks")
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .padding()
    }

    // MARK: - Step 2: Permissions

    private var permissionsStep: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("Grant Permissions")
                .font(.system(size: 16, weight: .semibold))

            Text("Zz needs these permissions to work properly.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            VStack(spacing: 12) {
                permissionCard(
                    icon: "hand.raised",
                    title: "Accessibility",
                    description: "Read UI elements, simulate input, global hotkey",
                    granted: hasAXPermission,
                    action: {
                        AccessibilityReader.shared.requestPermission()
                    }
                )

                permissionCard(
                    icon: "rectangle.dashed.badge.record",
                    title: "Screen Recording",
                    description: "Capture screenshots for AI to understand your screen",
                    granted: hasSCPermission,
                    action: {
                        ScreenCapture.shared.requestPermission()
                        let _ = CGWindowListCreateImage(.null, .optionOnScreenOnly, kCGNullWindowID, .bestResolution)
                    }
                )
            }
            .padding(.horizontal, 20)

            Text("You may need to restart the app after granting permissions.")
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding()
        .onReceive(timer) { _ in
            if currentStep == 1 {
                hasAXPermission = AccessibilityReader.shared.hasPermission
                hasSCPermission = ScreenCapture.shared.hasScreenRecordingPermission
            }
        }
    }

    // MARK: - Step 3: API Key

    private var apiKeyStep: some View {
        VStack(spacing: 16) {
            Spacer()

            Text("Configure AI Provider")
                .font(.system(size: 16, weight: .semibold))

            Text("Enter an API key for your preferred LLM provider.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // Provider picker
            Picker("", selection: $selectedProvider) {
                ForEach(LLMProviderType.allCases) { p in
                    Text(p.rawValue).tag(p)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)

            // API Key input
            VStack(alignment: .leading, spacing: 4) {
                Text("API Key")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                SecureField("Paste your API key here...", text: $apiKeyInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
            }
            .padding(.horizontal, 20)

            if selectedProvider == .custom {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Endpoint URL")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    TextField("https://api.example.com/v1", text: $settings.customEndpoint)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))

                    Text("Model Name")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    TextField("model-name", text: $settings.customModelName)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))

                    Text("API Format")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Picker("", selection: $settings.customApiFormat) {
                        Text("OpenAI").tag("OpenAI")
                        Text("Claude").tag("Claude")
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal, 20)
            }

            if apiKeyInput.isEmpty {
                Text("You can also configure this later in Settings.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .onChange(of: selectedProvider) {
            apiKeyInput = settings.apiKey(for: selectedProvider)
        }
        .onAppear {
            apiKeyInput = settings.apiKey(for: selectedProvider)
        }
    }

    // MARK: - Helpers

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .frame(width: 20)
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.primary)
        }
    }

    private func permissionCard(icon: String, title: String, description: String,
                                 granted: Bool, action: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(granted ? .green : .primary)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Text(description)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            if granted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 16))
            } else {
                Button("Grant") { action() }
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.primary.opacity(0.1)))
                    .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
        )
    }

    private func saveAndComplete() {
        if !apiKeyInput.isEmpty {
            settings.setApiKey(apiKeyInput, for: selectedProvider)
            settings.selectedProvider = selectedProvider
            settings.selectedModel = selectedProvider.defaultModel
        }
        settings.hasCompletedOnboarding = true
        onComplete()
    }
}
