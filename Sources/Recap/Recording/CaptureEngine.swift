import Foundation
import ScreenCaptureKit
import AVFoundation
import CoreMedia
import CoreGraphics

/// Low-level capture engine that interfaces with ScreenCaptureKit
/// Receives CMSampleBuffers and writes them to a video file via AVAssetWriter
final class CaptureEngine: NSObject, @unchecked Sendable {
    private var stream: SCStream?
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var startTimestamp: CMTime?
    private var frameCount = 0
    private let captureQueue = DispatchQueue(label: "com.recap.capture", qos: .userInteractive)

    // Mouse tracking
    private var mouseMonitor: Any?
    private var clickMonitor: Any?
    private(set) var mouseEvents: [MouseEvent] = []
    private var recordingStartTime: Date?

    /// Start recording the specified content filter to a file
    func startCapture(
        filter: SCContentFilter,
        configuration: SCStreamConfiguration,
        outputURL: URL
    ) async throws {
        // Set up AVAssetWriter for the temp video file
        let writer = try AVAssetWriter(url: outputURL, fileType: .mp4)

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: configuration.width,
            AVVideoHeightKey: configuration.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 8_000_000,
                AVVideoMaxKeyFrameIntervalKey: 30,
            ] as [String: Any],
        ]

        let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        input.expectsMediaDataInRealTime = true
        writer.add(input)

        self.assetWriter = writer
        self.videoInput = input
        self.startTimestamp = nil
        self.frameCount = 0
        self.mouseEvents = []
        self.recordingStartTime = Date()

        // Create and configure the stream
        let stream = SCStream(filter: filter, configuration: configuration, delegate: nil)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: captureQueue)

        self.stream = stream

        // Start mouse tracking on main thread
        await MainActor.run {
            startMouseTracking()
        }

        // Start the stream
        try await stream.startCapture()
    }

    /// Stop the current capture
    func stopCapture() async throws -> URL? {
        guard let stream = self.stream else { return nil }

        // Stop stream
        try await stream.stopCapture()
        self.stream = nil

        // Stop mouse tracking on main thread
        await MainActor.run {
            stopMouseTracking()
        }

        // Finalize the asset writer
        guard let writer = self.assetWriter, let input = self.videoInput else { return nil }

        input.markAsFinished()

        let outputURL = writer.outputURL
        return await withCheckedContinuation { continuation in
            writer.finishWriting {
                continuation.resume(returning: outputURL)
            }
        }
    }

    var totalFrameCount: Int { frameCount }

    // MARK: - Mouse Tracking

    @MainActor
    private func startMouseTracking() {
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]) { [weak self] event in
            guard let self = self, let start = self.recordingStartTime else { return }
            let timestamp = Date().timeIntervalSince(start)
            let location = NSEvent.mouseLocation
            self.mouseEvents.append(MouseEvent(
                timestamp: timestamp,
                location: CGPoint(x: location.x, y: location.y),
                type: .move
            ))
        }

        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, let start = self.recordingStartTime else { return }
            let timestamp = Date().timeIntervalSince(start)
            let location = NSEvent.mouseLocation
            self.mouseEvents.append(MouseEvent(
                timestamp: timestamp,
                location: CGPoint(x: location.x, y: location.y),
                type: .click
            ))
        }
    }

    @MainActor
    private func stopMouseTracking() {
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
    }
}

// MARK: - SCStreamOutput

extension CaptureEngine: SCStreamOutput {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }
        guard sampleBuffer.isValid else { return }

        // Skip frames without image data
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let statusRawValue = attachments.first?[.status] as? Int,
              let status = SCFrameStatus(rawValue: statusRawValue),
              status == .complete else {
            return
        }

        guard let writer = assetWriter, let input = videoInput else { return }

        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        // Initialize writer on first frame
        if startTimestamp == nil {
            startTimestamp = timestamp
            writer.startWriting()
            writer.startSession(atSourceTime: timestamp)
        }

        if input.isReadyForMoreMediaData {
            input.append(sampleBuffer)
            frameCount += 1
        }
    }
}
