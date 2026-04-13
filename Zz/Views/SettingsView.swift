import SwiftUI

// MARK: - Settings View

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab = 0
    @State private var hasAXPermission = AccessibilityReader.shared.hasPermission
    @State private var hasSCPermission = ScreenCapture.shared.hasScreenRecordingPermission
    let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Picker("", selection: $selectedTab) {
                Text("Keys").tag(0)
                Text("Model").tag(1)
                Text("General").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.bottom, 10)

            Divider().opacity(0.3)

            ScrollView {
                VStack(spacing: 14) {
                    switch selectedTab {
                    case 0: apiKeysSection
                    case 1: modelSection
                    case 2: generalSection
                    default: EmptyView()
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 360, height: 380)
        .background(.regularMaterial)
        .onReceive(timer) { _ in
            if selectedTab == 2 {
                hasAXPermission = AccessibilityReader.shared.hasPermission
                hasSCPermission = ScreenCapture.shared.hasScreenRecordingPermission
            }
        }
    }

    // MARK: - API Keys

    private var apiKeysSection: some View {
        VStack(spacing: 12) {
            keyField("Claude", key: $settings.claudeAPIKey)
            keyField("OpenAI", key: $settings.openaiAPIKey)
            keyField("Gemini", key: $settings.geminiAPIKey)

            Divider().opacity(0.3)

            VStack(alignment: .leading, spacing: 6) {
                Text("Custom Provider")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                keyField("API Key", key: $settings.customAPIKey)
                labeledField("Endpoint", text: $settings.customEndpoint, placeholder: "https://...")
                labeledField("Model", text: $settings.customModelName, placeholder: "model-name")
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("API Format")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Picker("", selection: $settings.customApiFormat) {
                        Text("OpenAI").tag("OpenAI")
                        Text("Claude").tag("Claude")
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
    }

    private func keyField(_ title: String, key: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Spacer()
                if !key.wrappedValue.isEmpty {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9))
                        .foregroundColor(.green)
                }
            }
            SecureField("sk-...", text: key)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11, design: .monospaced))
        }
    }

    private func labeledField(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11))
        }
    }

    // MARK: - Model

    private var modelSection: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Provider")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Picker("", selection: $settings.selectedProviderRaw) {
                    ForEach(LLMProviderType.allCases) { p in
                        Text(p.rawValue).tag(p.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }

            labeledField("Model", text: $settings.selectedModel, placeholder: "model-name")

            // Presets
            let presets = presetsFor(settings.selectedProvider)
            if !presets.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Presets")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    FlowLayout(spacing: 4) {
                        ForEach(presets, id: \.self) { p in
                            Button(p) { settings.selectedModel = p }
                                .font(.system(size: 9, weight: .medium))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule().fill(
                                        settings.selectedModel == p
                                            ? Color.primary.opacity(0.12)
                                            : Color.primary.opacity(0.04)
                                    )
                                )
                                .buttonStyle(.plain)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Max iterations: \(settings.maxIterations)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Slider(value: Binding(
                    get: { Double(settings.maxIterations) },
                    set: { settings.maxIterations = Int($0) }
                ), in: 5...100, step: 5)
            }
        }
    }

    // MARK: - General

    private var generalSection: some View {
        VStack(spacing: 12) {
            // Permissions
            VStack(alignment: .leading, spacing: 6) {
                Text("Permissions")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                permRow("Accessibility", granted: hasAXPermission) {
                    AccessibilityReader.shared.requestPermission()
                }
                permRow("Screen Recording", granted: hasSCPermission) {
                    ScreenCapture.shared.requestPermission()
                    // Fallback to trigger prompt if SCShareableContent fails
                    let _ = CGWindowListCreateImage(.null, .optionOnScreenOnly, kCGNullWindowID, .bestResolution)
                }
            }

            Divider().opacity(0.3)

            Toggle("Confirm sensitive operations", isOn: $settings.confirmSensitiveOps)
                .font(.system(size: 11))
            Toggle("Auto-execute plans", isOn: $settings.autoExecutePlan)
                .font(.system(size: 11))

            Divider().opacity(0.3)

            HStack {
                Text("Hotkey: ⌘⇧Space")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Spacer()
            }

            Button("Clear History") {
                HistoryManager.shared.clearHistory()
            }
            .font(.system(size: 11))
            .foregroundColor(.red)
            .buttonStyle(.plain)
        }
    }

    private func permRow(_ title: String, granted: Bool, action: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle" : "xmark.circle")
                .font(.system(size: 11))
                .foregroundColor(granted ? .green : .red)
            Text(title)
                .font(.system(size: 11))
            Spacer()
            if !granted {
                Button("Grant") { action() }
                    .font(.system(size: 10, weight: .medium))
                    .buttonStyle(.plain)
                    .foregroundColor(.primary.opacity(0.6))
            }
        }
    }

    private func presetsFor(_ provider: LLMProviderType) -> [String] {
        switch provider {
        case .claude: return ["claude-sonnet-4-20250514", "claude-opus-4-20250514"]
        case .openai: return ["gpt-4o", "gpt-4o-mini", "o1"]
        case .gemini: return ["gemini-2.5-flash", "gemini-2.5-pro"]
        case .custom: return []
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let r = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return r.size
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let r = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (i, pos) in r.positions.enumerated() {
            subviews[i].place(at: CGPoint(x: bounds.minX + pos.x, y: bounds.minY + pos.y), proposal: .unspecified)
        }
    }
    struct FlowResult {
        var positions: [CGPoint] = []
        var size: CGSize = .zero
        init(in maxW: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0; var y: CGFloat = 0; var rh: CGFloat = 0
            for sv in subviews {
                let s = sv.sizeThatFits(.unspecified)
                if x + s.width > maxW && x > 0 { x = 0; y += rh + spacing; rh = 0 }
                positions.append(CGPoint(x: x, y: y))
                rh = max(rh, s.height); x += s.width + spacing
                size.width = max(size.width, x)
            }
            size.height = y + rh
        }
    }
}
