import Foundation
import AVFoundation
import CoreGraphics
import CoreImage

/// Automatically enhances recordings by detecting and compressing inactive periods,
/// highlighting clicks, and applying cursor-follow zoom
@MainActor
final class AutoEnhancer: ObservableObject {
    @Published var progress: Double = 0
    @Published var status: String = ""

    /// Analyze a recording session and produce speed multipliers for dead time compression
    func analyzeInactivity(
        mouseEvents: [MouseEvent],
        duration: TimeInterval,
        threshold: Double = 1.5
    ) -> [TimeRange: Double] {
        var speedMultipliers: [TimeRange: Double] = [:]

        guard mouseEvents.count > 1 else { return speedMultipliers }

        // Find gaps between mouse events that exceed the threshold
        var lastEventTime: Double = 0

        for event in mouseEvents.sorted(by: { $0.timestamp < $1.timestamp }) {
            let gap = event.timestamp - lastEventTime
            if gap > threshold {
                // This is a dead period - speed it up
                let range = TimeRange(start: lastEventTime + 0.2, end: event.timestamp - 0.2)
                if range.duration > 0.5 {
                    speedMultipliers[range] = AppSettings.shared.inactivitySpeedMultiplier
                }
            }
            lastEventTime = event.timestamp
        }

        // Check for trailing inactivity
        let trailingGap = duration - lastEventTime
        if trailingGap > threshold {
            let range = TimeRange(start: lastEventTime + 0.2, end: duration - 0.1)
            if range.duration > 0.5 {
                speedMultipliers[range] = AppSettings.shared.inactivitySpeedMultiplier
            }
        }

        return speedMultipliers
    }

    /// Generate click highlight overlay data from mouse events
    func extractClickHighlights(from mouseEvents: [MouseEvent]) -> [ClickHighlight] {
        return mouseEvents
            .filter { $0.type == .click }
            .map { event in
                ClickHighlight(
                    timestamp: event.timestamp,
                    position: event.location,
                    radius: 30,
                    duration: 0.4
                )
            }
    }

    /// Detect auto-zoom regions based on cursor activity clustering
    func computeZoomRegions(
        mouseEvents: [MouseEvent],
        displaySize: CGSize,
        zoomFactor: CGFloat = 1.5
    ) -> [ZoomRegion] {
        var regions: [ZoomRegion] = []

        let clicks = mouseEvents.filter { $0.type == .click }
        guard clicks.count >= 2 else { return regions }

        for i in 0..<clicks.count {
            let click = clicks[i]
            let nextTime = i + 1 < clicks.count ? clicks[i + 1].timestamp : click.timestamp + 2.0

            // Create a zoom region centered on the click
            let zoomWidth = displaySize.width / zoomFactor
            let zoomHeight = displaySize.height / zoomFactor

            let centerX = max(zoomWidth / 2, min(click.location.x, displaySize.width - zoomWidth / 2))
            let centerY = max(zoomHeight / 2, min(click.location.y, displaySize.height - zoomHeight / 2))

            let rect = CGRect(
                x: centerX - zoomWidth / 2,
                y: centerY - zoomHeight / 2,
                width: zoomWidth,
                height: zoomHeight
            )

            regions.append(ZoomRegion(
                startTime: click.timestamp - 0.3,
                endTime: nextTime - 0.3,
                sourceRect: rect,
                zoomFactor: zoomFactor
            ))
        }

        return regions
    }

    /// Full processing pipeline: analyze, enhance, and export
    func process(
        session: RecordingSession,
        settings: AppSettings,
        outputURL: URL
    ) async throws {
        guard let rawURL = session.rawVideoURL else {
            throw AutoEnhancerError.noRawVideo
        }

        status = "Analyzing recording..."
        progress = 0.1

        // Step 1: Analyze inactivity for dead time compression
        var speedMultipliers: [TimeRange: Double]? = nil
        if settings.speedUpInactivity {
            speedMultipliers = analyzeInactivity(
                mouseEvents: session.mouseEvents,
                duration: session.duration,
                threshold: settings.inactivityThreshold
            )
            if speedMultipliers?.isEmpty == true {
                speedMultipliers = nil
            }
        }

        progress = 0.3

        // Step 2: Export based on format
        status = "Encoding \(settings.outputFormat.displayName)..."

        switch settings.outputFormat {
        case .gif:
            try await GifEncoder.encode(
                videoURL: rawURL,
                outputURL: outputURL,
                frameRate: settings.gifFrameRate,
                maxWidth: 960,
                speedMultipliers: speedMultipliers
            )

        case .mp4:
            // For MP4, copy the raw file (future: apply zoom/speed adjustments)
            try FileManager.default.copyItem(at: rawURL, to: outputURL)
        }

        progress = 0.9
        status = "Finalizing..."

        session.outputURL = outputURL
        progress = 1.0
        status = "Complete"
    }
}

// MARK: - Supporting Types

struct ClickHighlight {
    let timestamp: TimeInterval
    let position: CGPoint
    let radius: CGFloat
    let duration: TimeInterval
}

struct ZoomRegion {
    let startTime: TimeInterval
    let endTime: TimeInterval
    let sourceRect: CGRect
    let zoomFactor: CGFloat
}

enum AutoEnhancerError: LocalizedError {
    case noRawVideo
    case processingFailed(String)

    var errorDescription: String? {
        switch self {
        case .noRawVideo: return "No raw video file found"
        case .processingFailed(let msg): return "Processing failed: \(msg)"
        }
    }
}
