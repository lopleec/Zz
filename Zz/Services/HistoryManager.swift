import Foundation

// MARK: - History Manager

class HistoryManager {
    static let shared = HistoryManager()

    private let historyDir: URL
    private let maxHistoryItems = 500

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        historyDir = appSupport.appendingPathComponent("Zz/History", isDirectory: true)
        try? FileManager.default.createDirectory(at: historyDir, withIntermediateDirectories: true)
    }

    /// Save a conversation session
    func saveSession(_ messages: [ChatMessage], title: String? = nil) {
        let session = HistorySession(
            id: UUID(),
            title: title ?? generateTitle(from: messages),
            messages: messages,
            createdAt: Date(),
            messageCount: messages.count
        )

        let fileName = "\(session.id.uuidString).json"
        let fileURL = historyDir.appendingPathComponent(fileName)

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(session)
            try data.write(to: fileURL)
        } catch {
            print("[HistoryManager] Failed to save session: \(error)")
        }

        trimHistory()
    }

    /// Load all saved sessions (metadata only)
    func listSessions() -> [HistorySessionMeta] {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: historyDir,
                includingPropertiesForKeys: [.creationDateKey])
                .filter { $0.pathExtension == "json" }
                .sorted { a, b in
                    let dateA = (try? a.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                    let dateB = (try? b.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                    return dateA > dateB
                }

            return files.compactMap { url -> HistorySessionMeta? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                guard let session = try? decoder.decode(HistorySession.self, from: data) else { return nil }
                return HistorySessionMeta(
                    id: session.id,
                    title: session.title,
                    createdAt: session.createdAt,
                    messageCount: session.messageCount,
                    filePath: url
                )
            }
        } catch {
            print("[HistoryManager] Failed to list sessions: \(error)")
            return []
        }
    }

    /// Load a full session by ID
    func loadSession(id: UUID) -> HistorySession? {
        let fileURL = historyDir.appendingPathComponent("\(id.uuidString).json")
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(HistorySession.self, from: data)
    }

    /// Delete a session
    func deleteSession(id: UUID) {
        let fileURL = historyDir.appendingPathComponent("\(id.uuidString).json")
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// Delete all sessions
    func clearHistory() {
        let sessions = listSessions()
        for session in sessions {
            try? FileManager.default.removeItem(at: session.filePath)
        }
    }

    // MARK: - Private

    private func generateTitle(from messages: [ChatMessage]) -> String {
        guard let firstUser = messages.first(where: { $0.role == .user }) else {
            return "Untitled Session"
        }
        let text = firstUser.textContent
        if text.count <= 50 { return text }
        return String(text.prefix(47)) + "..."
    }

    private func trimHistory() {
        let sessions = listSessions()
        if sessions.count > maxHistoryItems {
            let toDelete = sessions.suffix(from: maxHistoryItems)
            for session in toDelete {
                try? FileManager.default.removeItem(at: session.filePath)
            }
        }
    }
}

// MARK: - Models

struct HistorySession: Codable {
    let id: UUID
    let title: String
    let messages: [ChatMessage]
    let createdAt: Date
    let messageCount: Int
}

struct HistorySessionMeta: Identifiable {
    let id: UUID
    let title: String
    let createdAt: Date
    let messageCount: Int
    let filePath: URL
}
