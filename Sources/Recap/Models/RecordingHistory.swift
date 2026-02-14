import Foundation

/// Manages recording history, storing metadata about past recordings
@MainActor
final class RecordingHistory: ObservableObject {
    static let shared = RecordingHistory()

    @Published var entries: [HistoryEntry] = []

    private let maxEntries = 50
    private let storageKey = "recordingHistory"

    private init() {
        loadHistory()
    }

    /// Add a completed recording to history
    func add(session: RecordingSession, outputURL: URL, format: OutputFormat) {
        let entry = HistoryEntry(
            id: session.id,
            name: session.displayName,
            date: session.startTime,
            duration: session.duration,
            format: format,
            outputPath: outputURL.path,
            fileSize: Self.fileSize(at: outputURL),
            frameCount: session.frameCount
        )

        entries.insert(entry, at: 0)

        // Trim old entries
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }

        saveHistory()
    }

    /// Remove an entry
    func remove(id: UUID) {
        if let entry = entries.first(where: { $0.id == id }) {
            // Delete the file too
            try? FileManager.default.removeItem(atPath: entry.outputPath)
        }
        entries.removeAll { $0.id == id }
        saveHistory()
    }

    /// Clear all history
    func clearAll() {
        for entry in entries {
            try? FileManager.default.removeItem(atPath: entry.outputPath)
        }
        entries.removeAll()
        saveHistory()
    }

    // MARK: - Persistence

    private func saveHistory() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode([HistoryEntry].self, from: data) else {
            return
        }
        // Filter out entries whose files no longer exist
        entries = saved.filter { FileManager.default.fileExists(atPath: $0.outputPath) }
    }

    private static func fileSize(at url: URL) -> Int64 {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
    }
}

// MARK: - HistoryEntry

struct HistoryEntry: Identifiable, Codable {
    let id: UUID
    let name: String
    let date: Date
    let duration: TimeInterval
    let format: OutputFormat
    let outputPath: String
    let fileSize: Int64
    let frameCount: Int

    var outputURL: URL { URL(fileURLWithPath: outputPath) }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    var formattedDuration: String {
        let seconds = Int(duration)
        if seconds < 60 {
            return "\(seconds)s"
        }
        return "\(seconds / 60)m \(seconds % 60)s"
    }

    var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
