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
    @Published var errorMessage: String?
    @Published var permissionStatus: PermissionStatus = .unknown

    private let captureEngine = CaptureEngine()
    private var durationTimer: Timer?

    enum PermissionStatus: Equatable {
        case unknown
        case granted
        case denied
        case checking
    }

    // MARK: - Permission Check

    /// Check if we have screen recording permission by attempting to list content
    func checkPermission() async {
        permissionStatus = .checking
        errorMessage = nil

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            self.availableDisplays = content.displays
            self.availableWindows = content.windows.filter { window in
                window.frame.width > 100 && window.frame.height > 100
                    && window.owningApplication != nil
                    && window.owningApplication?.bundleIdentifier != Bundle.main.bundleIdentifier
            }

            if content.displays.isEmpty {
                permissionStatus = .denied
                errorMessage = "Screen recording permission required. Open System Settings to grant access."
            } else {
                permissionStatus = .granted
            }
        } catch {
            permissionStatus = .denied
            let nsError = error as NSError
            if nsError.domain == "com.apple.ScreenCaptureKit.SCStreamErrorDomain" || nsError.code == -3801 {
                errorMessage = "Screen recording permission denied. Please enable it in System Settings."
            } else {
                errorMessage = "Cannot access screen content: \(error.localizedDescription)"
            }
        }
    }

    /// Open System Settings to the Screen Recording privacy pane
    func openScreenRecordingSettings() {
        // macOS 15+ (Sequoia) uses the new System Settings URL scheme
        let urls = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ScreenCapture",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture",
        ]

        for urlString in urls {
            if let url = URL(string: urlString) {
                let opened = NSWorkspace.shared.open(url)
                if opened { return }
            }
        }

        // Fallback: just open Privacy & Security
        if let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Content Discovery

    /// Refresh the list of available displays and windows
    func refreshAvailableContent() async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            self.availableDisplays = content.displays
            self.availableWindows = content.windows.filter { window in
                window.frame.width > 100 && window.frame.height > 100
                    && window.owningApplication != nil
                    && window.owningApplication?.bundleIdentifier != Bundle.main.bundleIdentifier
            }
            if !content.displays.isEmpty {
                permissionStatus = .granted
                errorMessage = nil
            }
        } catch {
            permissionStatus = .denied
            errorMessage = "Screen recording access needed. Click \"Grant Access\" below."
        }
    }

    // MARK: - Recording Control

    /// Start recording the primary display
    func startRecording(display: SCDisplay? = nil) async {
        guard !isRecording else { return }
        errorMessage = nil

        // Refresh content and check permission
        await refreshAvailableContent()

        guard permissionStatus == .granted else {
            errorMessage = "Screen recording permission required. Click \"Grant Access\" to open System Settings."
            return
        }

        guard let targetDisplay = display ?? availableDisplays.first else {
            errorMessage = "No display found. Try granting screen recording permission in System Settings."
            return
        }

        let session = RecordingSession()
        session.state = .preparing
        self.currentSession = session

        // Create temp file for raw video
        let tempDir = FileManager.default.temporaryDirectory
        let rawURL = tempDir.appendingPathComponent("\(session.id.uuidString)-raw.mp4")
        session.rawVideoURL = rawURL

        // Remove stale file if it exists
        try? FileManager.default.removeItem(at: rawURL)

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
            errorMessage = nil
            startDurationTimer()
        } catch {
            session.state = .failed("Failed to start recording: \(error.localizedDescription)")
            self.currentSession = nil
            errorMessage = "Recording failed: \(error.localizedDescription)"
        }
    }

    /// Start recording a specific window
    func startRecording(window: SCWindow) async {
        guard !isRecording else { return }
        errorMessage = nil

        let session = RecordingSession()
        session.state = .preparing
        self.currentSession = session

        let tempDir = FileManager.default.temporaryDirectory
        let rawURL = tempDir.appendingPathComponent("\(session.id.uuidString)-raw.mp4")
        session.rawVideoURL = rawURL

        try? FileManager.default.removeItem(at: rawURL)

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
            errorMessage = nil
            startDurationTimer()
        } catch {
            session.state = .failed("Failed to start recording: \(error.localizedDescription)")
            self.currentSession = nil
            errorMessage = "Recording failed: \(error.localizedDescription)"
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
            errorMessage = "Failed to finalize recording: \(error.localizedDescription)"
        }
    }

    /// Clear any error state
    func clearError() {
        errorMessage = nil
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
