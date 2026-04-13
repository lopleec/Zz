import SwiftUI

// MARK: - Message Bubble View

struct MessageBubbleView: View {
    let message: ChatMessage
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if message.role == .user {
                Spacer(minLength: 40)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                // Content
                VStack(alignment: .leading, spacing: 8) {
                    // Images
                    ForEach(imageContents.indices, id: \.self) { idx in
                        if let nsImage = NSImage(data: imageContents[idx]) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: 220, maxHeight: 150)
                                .cornerRadius(8)
                        }
                    }

                    // Text
                    if !message.textContent.isEmpty {
                        Text(LocalizedStringKey(message.textContent))
                            .font(.system(size: 13))
                            .foregroundColor(message.role == .system ? .orange : .primary)
                            .textSelection(.enabled)
                            .lineSpacing(2)
                    }
                }
                .padding(.horizontal, message.role == .user ? 14 : 4)
                .padding(.vertical, message.role == .user ? 10 : 4)
                .background(bubbleBackground)
                .clipShape(RoundedRectangle(cornerRadius: message.role == .user ? 16 : 8))

                // Action area for assistant/system
                if message.role != .user && !message.textContent.isEmpty {
                    HStack(spacing: 12) {
                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(message.textContent, forType: .string)
                        }) {
                            Image(systemName: "square.on.square")
                        }
                        .buttonStyle(.plain)
                        .help("Copy")

                        Image(systemName: "speaker.wave.2")
                        Image(systemName: "hand.thumbsup")
                        Image(systemName: "hand.thumbsdown")
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.leading, 4)
                    .padding(.top, 2)
                }
            }

            if message.role != .user {
                Spacer(minLength: 40)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var bubbleBackground: some View {
        switch message.role {
        case .user:
            Color.primary.opacity(colorScheme == .dark ? 0.15 : 0.08)
        default:
            Color.clear
        }
    }

    private var imageContents: [Data] {
        message.content.compactMap { c in
            if case .image(let d) = c { return d }
            return nil
        }
    }
}
