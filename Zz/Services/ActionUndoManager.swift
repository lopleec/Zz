import Foundation

// MARK: - Action Undo Manager

class ActionUndoManager: ObservableObject {
    static let shared = ActionUndoManager()

    @Published var undoStack: [UndoRecord] = []
    private let maxUndoSteps = 50

    /// Record an action before execution
    func recordAction(_ action: ComputerAction, screenshotBefore: Data?) {
        let record = UndoRecord(action: action, screenshotBefore: screenshotBefore)
        undoStack.append(record)

        if undoStack.count > maxUndoSteps {
            undoStack.removeFirst()
        }
    }

    /// Get the last action that can be undone
    var lastAction: UndoRecord? {
        undoStack.last
    }

    /// Can undo?
    var canUndo: Bool {
        !undoStack.isEmpty
    }

    /// Perform undo: try to reverse the last action
    /// Returns a description of how the undo was handled
    func undo() async -> String {
        guard let last = undoStack.popLast() else {
            return "Nothing to undo"
        }

        // Perform reverse action based on what was done
        switch last.action {
        case .type(let text):
            // Undo typing by pressing backspace for each character
            for _ in 0..<text.count {
                InputSimulator.shared.pressKey(KeyCodes.kVK_Delete)
                try? await Task.sleep(nanoseconds: 20_000_000)
            }
            return "Undid typing of \"\(text.prefix(20))...\""

        case .key(let keys):
            let lower = keys.lowercased()
            // Special undo for common operations
            if lower.contains("cmd") && lower.contains("v") {
                // Undo paste → Cmd+Z
                InputSimulator.shared.pressKeyCombo("cmd+z")
                return "Undid paste (Cmd+Z)"
            } else if lower.contains("cmd") && lower.contains("x") {
                // Undo cut → Cmd+Z
                InputSimulator.shared.pressKeyCombo("cmd+z")
                return "Undid cut (Cmd+Z)"
            } else {
                // Generic undo
                InputSimulator.shared.pressKeyCombo("cmd+z")
                return "Performed Cmd+Z to undo '\(keys)'"
            }

        case .leftClick, .rightClick, .doubleClick, .tripleClick, .middleClick:
            // Can't easily undo clicks, but we can try Cmd+Z
            InputSimulator.shared.pressKeyCombo("cmd+z")
            return "Performed Cmd+Z to undo click action"

        case .leftClickDrag:
            InputSimulator.shared.pressKeyCombo("cmd+z")
            return "Performed Cmd+Z to undo drag"

        case .scroll:
            // Reverse scroll is possible but contextual
            return "Scroll undo - scroll back manually if needed"

        case .screenshot, .mouseMove, .wait, .zoom:
            return "No action needed to undo (non-destructive operation)"
        }
    }

    /// Clear undo history
    func clearHistory() {
        undoStack.removeAll()
    }
}
