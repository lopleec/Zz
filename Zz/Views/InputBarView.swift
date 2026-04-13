import SwiftUI
import UniformTypeIdentifiers

// MARK: - Input Bar View

struct InputBarView: View {
    @Binding var text: String
    @Binding var attachedImages: [Data]
    let isRunning: Bool
    let onSend: () -> Void
    let onStop: () -> Void
    let onSettings: () -> Void

    @Environment(\.colorScheme) var colorScheme
    @StateObject private var settings = AppSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Attached images (compact)
            if !attachedImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(attachedImages.indices, id: \.self) { i in
                            ZStack(alignment: .topTrailing) {
                                if let img = NSImage(data: attachedImages[i]) {
                                    Image(nsImage: img)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 40, height: 40)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                Button(action: { attachedImages.remove(at: i) }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white)
                                        .shadow(radius: 2)
                                }
                                .buttonStyle(.plain)
                                .offset(x: 6, y: -6)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                }
                .frame(height: 50)
            }

            // Top row: Text field
            TextField("询问任何问题", text: $text, axis: .vertical)
                .font(.system(size: 14))
                .textFieldStyle(.plain)
                .lineLimit(1...8)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 12)
                .onSubmit {
                    if !isRunning && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        onSend()
                    }
                }

            // Bottom row: Toolbar
            HStack(spacing: 16) {
                // Attach
                Button(action: pickImage) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .regular))
                }
                .buttonStyle(.plain)
                .foregroundColor(.primary.opacity(0.7))

                // Toggle Agent / Ask mode
                Button(action: {
                    settings.isAgentMode.toggle()
                }) {
                    Image(systemName: "cursorarrow.rays")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(settings.isAgentMode ? .blue : .primary.opacity(0.4))
                }
                .buttonStyle(.plain)
                .help(settings.isAgentMode ? "Agent Mode (Computer Control)" : "Ask Mode (Chat Only)")
                
                // Settings
                Button(action: onSettings) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.primary.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help("Settings")

                // Model Selection Menu
                Menu {
                    ForEach(LLMProviderType.allCases) { provider in
                        let models = presetsFor(provider)
                        if !models.isEmpty {
                            Menu(provider.rawValue) {
                                ForEach(models, id: \.self) { model in
                                    Button(model) {
                                        settings.selectedProviderRaw = provider.rawValue
                                        settings.selectedModel = model
                                    }
                                }
                            }
                        } else {
                            // Custom
                            Button("Custom Provider (\(settings.customModelName.isEmpty ? "Unknown" : settings.customModelName))") {
                                settings.selectedProviderRaw = provider.rawValue
                            }
                        }
                    }
                } label: {
                    Text(humanReadableModelName())
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary.opacity(0.8))
                }
                .menuStyle(.borderlessButton)
                .frame(width: 120, alignment: .leading)
                .help("Select Model")

                Spacer()

                // Stop / Send
                if isRunning {
                    Button(action: onStop) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color(NSColor.labelColor))
                            .frame(width: 28, height: 28)
                            .background(Circle().stroke(Color.primary.opacity(0.2), lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                } else {
                    let isDisabled = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    Button(action: onSend) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(isDisabled ? .primary.opacity(0.3) : Color(NSColor.windowBackgroundColor))
                            .frame(width: 28, height: 28)
                            .background(
                                Circle().fill(isDisabled ? Color.primary.opacity(0.08) : Color.primary)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(isDisabled)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.primary.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 10, x: 0, y: 4)
        )
        // Only padding on sides, bottom handled by ChatView if needed
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
        .padding(.top, 14) // Ensures standalone pill looks nice
    }

    private func pickImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .jpeg, .png]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        if panel.runModal() == .OK {
            for url in panel.urls {
                if let data = try? Data(contentsOf: url),
                   let nsImg = NSImage(data: data),
                   let jpeg = ImageUtils.nsImageToJPEGData(nsImg) {
                    attachedImages.append(jpeg)
                }
            }
        }
    }
    
    private func presetsFor(_ provider: LLMProviderType) -> [String] {
        switch provider {
        case .claude: return ["claude-sonnet-3.5", "claude-opus-3"]
        case .openai: return ["gpt-4o", "gpt-4o-mini", "o1-mini"]
        case .gemini: return ["gemini-2.5-flash", "gemini-2.5-pro", "gemini-3.1-pro-low"]
        case .custom: return []
        }
    }
    
    private func humanReadableModelName() -> String {
        let provider = settings.selectedProviderRaw.lowercased()
        if provider == "custom" {
            return settings.customModelName.isEmpty ? "Custom" : settings.customModelName
        }
        let raw = settings.selectedModel
        if raw.isEmpty { return settings.selectedProviderRaw }
        if raw.contains("gemini") && raw.contains("pro") { return "Gemini Pro" }
        if raw.contains("flash") { return "Gemini Flash" }
        if raw.contains("sonnet") { return "Claude Sonnet" }
        if raw.contains("opus") { return "Claude Opus" }
        if raw.contains("gpt-4o-mini") { return "GPT-4o Mini" }
        if raw.contains("gpt-4o") { return "GPT-4o" }
        if raw.contains("o1") { return "o1" }
        return raw.count > 18 ? String(raw.prefix(18)) + "…" : raw
    }
}
