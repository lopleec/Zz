import SwiftUI

struct HistoryView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var agent: AgentLoop
    
    @State private var sessions: [HistorySessionMeta] = []
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Chat History")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            Divider()
            
            if sessions.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                    Text("No history yet.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                List {
                    ForEach(sessions) { session in
                        Button(action: {
                            loadSession(session)
                        }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.title)
                                    .font(.system(size: 13, weight: .medium))
                                    .lineLimit(1)
                                
                                HStack {
                                    Text("\(session.messageCount) messages")
                                    Spacer()
                                    Text(formatDate(session.createdAt))
                                }
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: deleteSession)
                }
                .listStyle(.inset)
            }
            
            Divider()
            
            // Footer
            HStack {
                Button(action: {
                    HistoryManager.shared.clearHistory()
                    loadSessions()
                }) {
                    Text("Clear All")
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .disabled(sessions.isEmpty)
                
                Spacer()
            }
            .padding()
        }
        .frame(width: 320, height: 400)
        .onAppear {
            loadSessions()
        }
    }
    
    private func loadSessions() {
        sessions = HistoryManager.shared.listSessions()
    }
    
    private func loadSession(_ meta: HistorySessionMeta) {
        if let fullSession = HistoryManager.shared.loadSession(id: meta.id) {
            agent.newSession() // clear current
            agent.messages = fullSession.messages
            dismiss()
        }
    }
    
    private func deleteSession(at offsets: IndexSet) {
        for index in offsets {
            let session = sessions[index]
            HistoryManager.shared.deleteSession(id: session.id)
        }
        loadSessions()
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
