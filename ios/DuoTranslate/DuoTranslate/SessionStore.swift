import Combine
import Foundation

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var sessions: [ConversationSession] = []

    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = support.appendingPathComponent("DuoTranslate", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("sessions.json")

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        load()
    }

    func add(_ session: ConversationSession) {
        sessions.removeAll { $0.id == session.id }
        sessions.insert(session, at: 0)
        if sessions.count > 100 { sessions.removeLast(sessions.count - 100) }
        persist()
    }

    func updateSummary(sessionID: UUID, summary: SessionSummary) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        sessions[index].summary = summary
        persist()
    }

    func delete(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) where sessions.indices.contains(index) {
            sessions.remove(at: index)
        }
        persist()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? decoder.decode([ConversationSession].self, from: data) else { return }
        sessions = decoded
    }

    private func persist() {
        guard let data = try? encoder.encode(sessions) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
