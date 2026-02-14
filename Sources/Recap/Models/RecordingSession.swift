import Foundation
import CoreGraphics

/// Represents a single recording session with its captured data and metadata
@MainActor
final class RecordingSession: ObservableObject, Identifiable {
    let id: UUID
    let startTime: Date
    @Published var endTime: Date?
    @Published var state: RecordingState = .idle
    @Published var duration: TimeInterval = 0
    @Published var frameCount: Int = 0

    /// Temporary file URL where raw recording is stored
    var rawVideoURL: URL?

    /// Processed output file URL
    var outputURL: URL?

    /// Mouse events captured during recording for auto-enhancement
    var mouseEvents: [MouseEvent] = []

    /// Captured frames for GIF encoding (populated during processing)
    var capturedFrames: [CapturedFrame] = []

    init() {
        self.id = UUID()
        self.startTime = Date()
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let tenths = Int((duration - Double(Int(duration))) * 10)
        return String(format: "%d:%02d.%d", minutes, seconds, tenths)
    }

    var displayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return "Recap \(formatter.string(from: startTime))"
    }
}

// MARK: - Supporting Types

enum RecordingState: Equatable {
    case idle
    case preparing
    case recording
    case processing
    case complete
    case failed(String)

    var isRecording: Bool {
        if case .recording = self { return true }
        return false
    }
}

struct MouseEvent: Sendable {
    let timestamp: TimeInterval
    let location: CGPoint
    let type: MouseEventType
}

enum MouseEventType: Sendable {
    case move
    case click
    case drag
}

struct CapturedFrame: Sendable {
    let image: CGImage
    let timestamp: TimeInterval
    let cursorPosition: CGPoint?
    let isClick: Bool
}
