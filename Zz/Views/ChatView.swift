import SwiftUI

// MARK: - Main Chat View

struct ChatView: View {
    @StateObject private var agent = AgentLoop()
    @State private var inputText = ""
    @State private var attachedImages: [Data] = []
    @State private var showSettings = false
    @State private var showHistory = false
    @Environment(\.colorScheme) var colorScheme

    var isExpanded: Bool {
        !agent.messages.isEmpty || agent.isRunning
    }

    private var visibleMessages: [ChatMessage] {
        agent.messages.filter { msg in
            if msg.role == .user || msg.role == .assistant { return true }
            if msg.role == .system && (msg.textContent.contains("↩️") || msg.textContent.contains("Error")) { return true }
            return false // Hide tool calls and thinking from UI
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if isExpanded {
                VStack(spacing: 0) {
                    // Top Action Bar inside chat area (Close, Undo, Settings, New session)
                HStack {
                    // Close
                    Button(action: { NSApp.hide(nil) }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .help("Close")
                    
                    if ActionUndoManager.shared.canUndo {
                        Button(action: {
                            Task {
                                let result = await agent.undoLastAction()
                                if !result.isEmpty {
                                    agent.messages.append(.system(text: "↩️ \(result)"))
                                }
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.uturn.backward")
                                Text("Undo")
                            }
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.primary.opacity(0.1)))
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    // History
                    Button(action: { showHistory = true }) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 16))
                            .foregroundColor(.primary.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .help("History")
                    .padding(.trailing, 8)

                    // New Chat
                    Button(action: { agent.newSession() }) {
                        Image(systemName: "plus.bubble")
                            .font(.system(size: 16))
                            .foregroundColor(.primary.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .help("New Chat")

                    // Settings removed from here, now in InputBarView
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 4)

                // Input control warning
                if agent.isInputControlled {
                    InputControlBanner()
                        .padding(.top, 4)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(visibleMessages) { msg in
                                MessageBubbleView(message: msg)
                                    .id(msg.id)
                            }

                            // Plan
                            if let plan = agent.currentPlan {
                                PlanProgressView(plan: plan)
                                    .transition(.opacity)
                            }

                            // Confirmation
                            if agent.isWaitingForConfirmation, let op = agent.pendingSensitiveOp {
                                ConfirmationDialogView(
                                    operation: op,
                                    onConfirm: { agent.respondToConfirmation(true) },
                                    onDeny: { agent.respondToConfirmation(false) }
                                )
                                .transition(.scale.combined(with: .opacity))
                            }

                            // Status
                            if agent.isRunning && !agent.isWaitingForConfirmation {
                                HStack(spacing: 6) {
                                    LoadingSpinner(size: 12)
                                    Text(agent.statusMessage.isEmpty ? "Thinking..." : agent.statusMessage)
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                            }

                            Color.clear.frame(height: 1).id("bottom")
                        }
                        .padding(.bottom, 12)
                    }
                    .onChange(of: agent.messages.count) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.easeOut(duration: 0.15)) {
                                proxy.scrollTo("bottom", anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: agent.statusMessage) {
                        DispatchQueue.main.async {
                            withAnimation(.easeOut(duration: 0.1)) {
                                proxy.scrollTo("bottom", anchor: .bottom)
                            }
                        }
                    }
                } // End ScrollViewReader
            } // End VStack
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        } else {
            Spacer().frame(height: 0) // Takes no space when collapsed
        }

        // Input
        InputBarView(
            text: $inputText,
            attachedImages: $attachedImages,
            isRunning: agent.isRunning,
            onSend: sendMessage,
            onStop: { agent.stopExecution() },
            onSettings: { showSettings = true }
        )
        }
        // Inner wrap tightly around content or expand to 500
        .frame(width: 380, height: isExpanded ? 500 : nil)
        .background(isExpanded ? AnyView(Rectangle().fill(.regularMaterial)) : AnyView(Color.clear))
        .clipShape(RoundedRectangle(cornerRadius: isExpanded ? 24 : 0))
        .overlay(
            isExpanded ? RoundedRectangle(cornerRadius: 24).stroke(Color.primary.opacity(0.06), lineWidth: 0.5) : nil
        )
        .shadow(color: isExpanded ? .black.opacity(colorScheme == .dark ? 0.3 : 0.1) : .clear, radius: 20, x: 0, y: 10)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isExpanded)
        // Outer frame to position it at the bottom of the 500pt clear NSPanel
        .frame(width: 380, height: 500, alignment: .bottom)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showHistory) {
            HistoryView(agent: agent)
        }
    }

    // MARK: - Actions

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let images = attachedImages
        inputText = ""
        attachedImages = []
        agent.sendMessage(text, images: images)
    }
}
