import Foundation

// MARK: - Task Plan

struct TaskPlan: Codable, Identifiable {
    let id: UUID
    let goal: String
    var steps: [PlanStep]
    var status: PlanStatus
    let createdAt: Date

    init(goal: String, steps: [PlanStep]) {
        self.id = UUID()
        self.goal = goal
        self.steps = steps
        self.status = .pending
        self.createdAt = Date()
    }

    var currentStepIndex: Int? {
        steps.firstIndex { $0.status == .running }
    }

    var completedCount: Int {
        steps.filter { $0.status == .completed }.count
    }

    var progress: Double {
        guard !steps.isEmpty else { return 0 }
        return Double(completedCount) / Double(steps.count)
    }

    var isCompleted: Bool {
        status == .completed || status == .failed
    }

    mutating func markStepRunning(_ index: Int) {
        guard index < steps.count else { return }
        steps[index].status = .running
        status = .running
    }

    mutating func markStepCompleted(_ index: Int, note: String? = nil) {
        guard index < steps.count else { return }
        steps[index].status = .completed
        steps[index].verificationNote = note
        if completedCount == steps.count {
            status = .completed
        }
    }

    mutating func markStepFailed(_ index: Int, error: String?) {
        guard index < steps.count else { return }
        steps[index].status = .failed
        steps[index].verificationNote = error
        status = .failed
    }
}

// MARK: - Plan Step

struct PlanStep: Codable, Identifiable {
    let id: UUID
    let stepNumber: Int
    let description: String
    var status: StepStatus
    var verificationNote: String?

    init(stepNumber: Int, description: String) {
        self.id = UUID()
        self.stepNumber = stepNumber
        self.description = description
        self.status = .pending
    }
}

// MARK: - Status Enums

enum PlanStatus: String, Codable {
    case pending
    case running
    case completed
    case failed
    case cancelled
}

enum StepStatus: String, Codable {
    case pending
    case running
    case completed
    case failed
    case skipped
}
