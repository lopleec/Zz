import Foundation

// MARK: - Terminal Executor

class TerminalExecutor {
    static let shared = TerminalExecutor()
    
    /// Run a shell command and return the output
    func runCommand(_ command: String, timeout: TimeInterval = 30) async -> TerminalResult {
        let startTime = Date()
        
        return await withCheckedContinuation { continuation in
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-c", command]
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            process.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
            
            // Set up environment
            var env = ProcessInfo.processInfo.environment
            env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:" + (env["PATH"] ?? "")
            env["HOME"] = NSHomeDirectory()
            env["LANG"] = "en_US.UTF-8"
            process.environment = env
            
            // Timeout handling
            let timeoutWorkItem = DispatchWorkItem {
                if process.isRunning {
                    process.terminate()
                }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutWorkItem)
            
            do {
                try process.run()
                process.waitUntilExit()
                timeoutWorkItem.cancel()
                
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let stdout = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let stderr = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                
                let exitCode = process.terminationStatus
                let duration = Date().timeIntervalSince(startTime)
                
                // Truncate very long output
                let maxLen = 8000
                let truncatedStdout = stdout.count > maxLen ? String(stdout.prefix(maxLen)) + "\n... [truncated, \(stdout.count) total chars]" : stdout
                let truncatedStderr = stderr.count > maxLen ? String(stderr.prefix(maxLen)) + "\n... [truncated, \(stderr.count) total chars]" : stderr
                
                continuation.resume(returning: TerminalResult(
                    exitCode: Int(exitCode),
                    stdout: truncatedStdout,
                    stderr: truncatedStderr,
                    duration: duration,
                    timedOut: false
                ))
            } catch {
                timeoutWorkItem.cancel()
                continuation.resume(returning: TerminalResult(
                    exitCode: -1,
                    stdout: "",
                    stderr: "Failed to launch process: \(error.localizedDescription)",
                    duration: Date().timeIntervalSince(startTime),
                    timedOut: false
                ))
            }
        }
    }
}

// MARK: - Terminal Result

struct TerminalResult {
    let exitCode: Int
    let stdout: String
    let stderr: String
    let duration: TimeInterval
    let timedOut: Bool
    
    var isSuccess: Bool { exitCode == 0 }
    
    var formattedOutput: String {
        var result = ""
        if !stdout.isEmpty {
            result += stdout
        }
        if !stderr.isEmpty {
            if !result.isEmpty { result += "\n" }
            result += "[stderr] \(stderr)"
        }
        if timedOut {
            result += "\n[TIMEOUT] Command exceeded time limit"
        }
        result += "\n[exit code: \(exitCode)]"
        return result
    }
}
