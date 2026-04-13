import Foundation

// MARK: - Tool Executor

class ToolExecutor {
    static let shared = ToolExecutor()

    private let inputSimulator = InputSimulator.shared
    private let screenCapture = ScreenCapture.shared
    private let undoManager = ActionUndoManager.shared

    /// Parse tool input from Claude/OpenAI response and convert to ComputerAction
    func parseAction(from input: [String: Any]) -> ComputerAction? {
        guard let actionStr = input["action"] as? String else { return nil }

        switch actionStr {
        case "screenshot":
            return .screenshot

        case "left_click":
            guard let coord = parseCoordinate(input["coordinate"]) else { return nil }
            return .leftClick(coordinate: coord)

        case "right_click":
            guard let coord = parseCoordinate(input["coordinate"]) else { return nil }
            return .rightClick(coordinate: coord)

        case "double_click":
            guard let coord = parseCoordinate(input["coordinate"]) else { return nil }
            return .doubleClick(coordinate: coord)

        case "triple_click":
            guard let coord = parseCoordinate(input["coordinate"]) else { return nil }
            return .tripleClick(coordinate: coord)

        case "middle_click":
            guard let coord = parseCoordinate(input["coordinate"]) else { return nil }
            return .middleClick(coordinate: coord)

        case "mouse_move":
            guard let coord = parseCoordinate(input["coordinate"]) else { return nil }
            return .mouseMove(coordinate: coord)

        case "left_click_drag":
            guard let startCoord = parseCoordinate(input["start_coordinate"]),
                  let endCoord = parseCoordinate(input["coordinate"]) else { return nil }
            return .leftClickDrag(startCoordinate: startCoord, coordinate: endCoord)

        case "type":
            guard let text = input["text"] as? String else { return nil }
            return .type(text: text)

        case "key":
            guard let keys = input["key"] as? String else { return nil }
            return .key(keys: keys)

        case "scroll":
            let coord = parseCoordinate(input["coordinate"]) ?? CGPoint(x: 500, y: 400)
            let dirStr = input["direction"] as? String ?? "down"
            let direction = ScrollDirection(rawValue: dirStr) ?? .down
            let amount = input["amount"] as? Int ?? 3
            return .scroll(coordinate: coord, direction: direction, amount: amount)

        case "wait":
            let duration = input["duration"] as? Double ?? 1.0
            return .wait(duration: duration)

        case "zoom":
            guard let region = input["region"] as? [Double], region.count == 4 else { return nil }
            let rect = CGRect(x: region[0], y: region[1],
                            width: region[2] - region[0],
                            height: region[3] - region[1])
            return .zoom(region: rect)

        default:
            print("[ToolExecutor] Unknown action: \(actionStr)")
            return nil
        }
    }

    /// Execute a computer action and return the result
    func executeAction(_ action: ComputerAction, scaleFactor: CGFloat) async -> ToolExecutionResult {
        // Record for undo (capture screenshot before for non-screenshot actions)
        if action.requiresInputControl {
            let screenshotBefore = await screenCapture.captureScreenAsJPEG()
            undoManager.recordAction(action, screenshotBefore: screenshotBefore)
        }

        // Execute the action
        let startTime = Date()

        switch action {
        case .screenshot:
            // Special handling: return the screenshot as the result
            if let screenshotData = await screenCapture.captureScreenAsJPEG() {
                return ToolExecutionResult(
                    success: true,
                    message: "Screenshot captured successfully",
                    screenshot: screenshotData,
                    duration: Date().timeIntervalSince(startTime)
                )
            } else {
                return ToolExecutionResult(
                    success: false,
                    message: "Failed to capture screenshot",
                    duration: Date().timeIntervalSince(startTime)
                )
            }

        default:
            // Execute the action on a background thread to avoid blocking the main thread
            // (InputSimulator uses usleep which would freeze the UI on MainActor)
            await Task.detached(priority: .userInitiated) {
                _ = await self.inputSimulator.execute(action, scaleFactor: scaleFactor)
            }.value

            // Wait a moment for the action to take effect
            try? await Task.sleep(nanoseconds: 500_000_000)  // 500ms

            // Take a verification screenshot
            let screenshotAfter = await screenCapture.captureScreenAsJPEG()

            return ToolExecutionResult(
                success: true,
                message: action.description,
                screenshot: screenshotAfter,
                duration: Date().timeIntervalSince(startTime)
            )
        }
    }

    /// Check if an action is sensitive and needs user confirmation
    func checkSensitivity(_ action: ComputerAction) -> SensitiveOperation? {
        guard AppSettings.shared.confirmSensitiveOps else { return nil }

        // Check built-in sensitivity
        if action.isSensitive {
            return SensitiveOperation(
                action: action,
                description: "This action may have significant consequences: \(action.description)",
                risk: .medium
            )
        }

        // Additional checks based on context
        switch action {
        case .key(let keys):
            let lower = keys.lowercased()
            // High risk: quit app, delete
            if (lower.contains("cmd") && lower.contains("q")) {
                return SensitiveOperation(action: action, description: "Quit application", risk: .high)
            }
            if lower.contains("cmd") && lower.contains("delete") {
                return SensitiveOperation(action: action, description: "Delete operation", risk: .high)
            }
        case .type(let text):
            let lower = text.lowercased()
            if lower.contains("rm ") || lower.contains("sudo") || lower.contains("format") {
                return SensitiveOperation(action: action, description: "Potentially destructive command: \(text)", risk: .high)
            }
        default:
            break
        }

        return nil
    }

    // MARK: - Private

    private func parseCoordinate(_ value: Any?) -> CGPoint? {
        if let arr = value as? [Double], arr.count >= 2 {
            return CGPoint(x: arr[0], y: arr[1])
        }
        if let arr = value as? [Int], arr.count >= 2 {
            return CGPoint(x: Double(arr[0]), y: Double(arr[1]))
        }
        if let arr = value as? [NSNumber], arr.count >= 2 {
            return CGPoint(x: arr[0].doubleValue, y: arr[1].doubleValue)
        }
        return nil
    }
}

// MARK: - Execution Result

struct ToolExecutionResult {
    let success: Bool
    let message: String
    var screenshot: Data?
    let duration: TimeInterval
}
