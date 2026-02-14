import Foundation
import ScreenCaptureKit
import CoreGraphics

/// High-level screen recorder that manages capture sessions
@MainActor
final class ScreenRecorder: ObservableObject {
    @Published var availableDisplays: [SCDisplay] = []
    @Published var availableWindows: [SCWindow] = []
    @Published var currentSession: RecordingSession?
    @Published var isRecording: Bool = false

    private let captureEngine = CaptureEngine()
    private var durationTimer: Timer?

    // MARK: - Content Discovery

    /// Refresh the list of available displays and windows
    func refreshAvailableContent() async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            self.availableDisplays = content.displays
            self.availableWindows = content.windows.filter { window in
                // Filter out tiny windows and system windows
                window.frame.width > 100 && window.frame.height > 100
                    && window.owningApplication != nil
                    && window.owningApplication?.bundleIdentifier != Bundle.main.bundleIdentifier
            }
        } catch {
            print("Failed to get shareable content: \(error.localizedDescription)")
        }
    }

    // MARK: - Recording Control

    /// Start recording the primary display
    func startRecording(display: SCDisplay? = nil) async {
        guard !isRecording else { return }

        // Refresh content
        await refreshAvailableContent()

        guard let targetDisplay = display ?? availableDisplays.first else {
            print("No display available for recording")
            return
        }

        let session = RecordingSession()
        session.state = .preparing
        self.currentSession = session

        // Create temp file for raw video
        let tempDir = FileManager.default.temporaryDirectory
        let rawURL = tempDir.appendingPathComponent("\(session.id.uuidString)-raw.mp4")
        session.rawVideoURL = rawURL

        // Configure capture
        let config = SCStreamConfiguration()
        config.width = Int(targetDisplay.width) * 2  // Retina
        config.height = Int(targetDisplay.height) * 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(AppSettings.shared.captureFrameRate))
        config.showsCursor = AppSettings.shared.showCursor
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.queueDepth = 8

        // Create content filter for the display
        let filter = SCContentFilter(display: targetDisplay, excludingApplications: [], exceptingWindows: [])

        do {
            try await captureEngine.startCapture(
                filter: filter,
                configuration: config,
                outputURL: rawURL
            )
            session.state = .recording
            isRecording = true
            startDurationTimer()
        } catch {
            session.state = .failed("Failed to start recording: \(error.localizedDescription)")
            print("Recording failed: \(error)")
        }
    }

    /// Start recording a specific window
    func startRecording(window: SCWindow) async {
        guard !isRecording else { return }

        let session = RecordingSession()
        session.state = .preparing
        self.currentSession = session

        let tempDir = FileManager.default.temporaryDirectory
        let rawURL = tempDir.appendingPathComponent("\(session.id.uuidString)-raw.mp4")
        session.rawVideoURL = rawURL

        let config = SCStreamConfiguration()
        config.width = Int(window.frame.width) * 2
        config.height = Int(window.frame.height) * 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(AppSettings.shared.captureFrameRate))
        config.showsCursor = AppSettings.shared.showCursor
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.queueDepth = 8

        let filter = SCContentFilter(desktopIndependentWindow: window)

        do {
            try await captureEngine.startCapture(
                filter: filter,
                configuration: config,
                outputURL: rawURL
            )
            session.state = .recording
            isRecording = true
            startDurationTimer()
        } catch {
            session.state = .failed("Failed to start recording: \(error.localizedDescription)")
            print("Recording failed: \(error)")
        }
    }

    /// Stop the current recording
    func stopRecording() async {
        guard isRecording, let session = currentSession else { return }

        stopDurationTimer()
        isRecording = false
        session.state = .processing
        session.endTime = Date()
        session.mouseEvents = captureEngine.mouseEvents
        session.frameCount = captureEngine.totalFrameCount

        do {
            let outputURL = try await captureEngine.stopCapture()
            session.rawVideoURL = outputURL
            session.state = .complete
        } catch {
            session.state = .failed("Failed to stop recording: \(error.localizedDescription)")
        }
    }

    // MARK: - Duration Timer

    private func startDurationTimer() {
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, let session = self.currentSession else { return }
                session.duration = Date().timeIntervalSince(session.startTime)
            }
        }
    }

    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
    }
}
