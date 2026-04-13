import SwiftUI

// MARK: - Confirmation Dialog

struct ConfirmationDialogView: View {
    let operation: SensitiveOperation
    let onConfirm: () -> Void
    let onDeny: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 12) {
            // Icon
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 20, weight: .light))
                .foregroundColor(riskColor)

            // Title
            Text("Confirm Action")
                .font(.system(size: 13, weight: .semibold))

            // Description
            Text(operation.description)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)

            // Action detail
            Text(operation.action.description)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.primary.opacity(0.7))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.primary.opacity(0.04))
                )

            // Buttons
            HStack(spacing: 10) {
                Button(action: onDeny) {
                    Text("Deny")
                        .font(.system(size: 11, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)

                Button(action: onConfirm) {
                    Text("Allow")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(colorScheme == .dark ? .black : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.primary)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(riskColor.opacity(0.2), lineWidth: 0.5)
                )
        )
        .padding(.horizontal, 14)
    }

    private var riskColor: Color {
        switch operation.risk {
        case .low: return .yellow
        case .medium: return .orange
        case .high: return .red
        }
    }
}
