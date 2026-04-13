import SwiftUI

// MARK: - Plan Progress View

struct PlanProgressView: View {
    let plan: TaskPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack {
                Image(systemName: "list.bullet")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text("Plan")
                    .font(.system(size: 11, weight: .medium))
                Spacer()
                Text("\(plan.completedCount)/\(plan.steps.count)")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.06))
                        Capsule()
                            .fill(Color.primary.opacity(0.3))
                            .frame(width: geo.size.width * plan.progress)
                    }
                }
                .frame(width: 40, height: 3)
            }

            // Steps
            ForEach(plan.steps) { step in
                HStack(alignment: .top, spacing: 6) {
                    Group {
                        switch step.status {
                        case .pending:
                            Circle()
                                .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                                .frame(width: 12, height: 12)
                        case .running:
                            LoadingSpinner(size: 12, lineWidth: 1)
                        case .completed:
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.primary.opacity(0.5))
                        case .failed:
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.red.opacity(0.6))
                        case .skipped:
                            Image(systemName: "forward.circle")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(width: 12, height: 12)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(step.description)
                            .font(.system(size: 10))
                            .foregroundColor(step.status == .pending ? .secondary : .primary)
                        if let note = step.verificationNote, !note.isEmpty {
                            Text(note)
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
                )
        )
        .padding(.horizontal, 10)
    }
}
