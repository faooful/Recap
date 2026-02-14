import Foundation
import CoreGraphics
import ImageIO
import AVFoundation
import CoreImage
import UniformTypeIdentifiers

/// Encodes video frames into an animated GIF with optimizations
struct GifEncoder {
    /// Encode a video file to an animated GIF
    /// - Parameters:
    ///   - videoURL: Source video file
    ///   - outputURL: Destination GIF file
    ///   - frameRate: Target frames per second for the GIF
    ///   - maxWidth: Maximum width (height scales proportionally)
    ///   - speedMultipliers: Optional per-segment speed adjustments (for dead time compression)
    static func encode(
        videoURL: URL,
        outputURL: URL,
        frameRate: Int = 12,
        maxWidth: Int = 960,
        speedMultipliers: [TimeRange: Double]? = nil,
        mouseEvents: [MouseEvent]? = nil,
        displaySize: CGSize? = nil,
        highlightClicks: Bool = false,
        annotateSteps: Bool = false
    ) async throws {
        let asset = AVAsset(url: videoURL)
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)

        guard durationSeconds > 0 else {
            throw GifEncoderError.invalidVideo
        }

        // Get video track for dimensions
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw GifEncoderError.noVideoTrack
        }
        let naturalSize = try await videoTrack.load(.naturalSize)

        // Calculate output dimensions
        let scale = min(1.0, Double(maxWidth) / naturalSize.width)
        let outputWidth = Int(naturalSize.width * scale)
        let outputHeight = Int(naturalSize.height * scale)

        // Create asset reader
        let reader = try AVAssetReader(asset: asset)
        let outputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: outputWidth,
            kCVPixelBufferHeightKey as String: outputHeight,
        ]
        let readerOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: outputSettings)
        readerOutput.alwaysCopiesSampleData = false
        reader.add(readerOutput)

        guard reader.startReading() else {
            throw GifEncoderError.readerFailed(reader.error?.localizedDescription ?? "Unknown error")
        }

        // Create GIF destination
        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            UTType.gif.identifier as CFString,
            0,  // 0 = unknown frame count
            nil
        ) else {
            throw GifEncoderError.createDestinationFailed
        }

        // Set GIF properties (loop forever)
        let gifProperties: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFLoopCount as String: 0,
            ] as [String: Any],
        ]
        CGImageDestinationSetProperties(destination, gifProperties as CFDictionary)

        // Sample frames at the target frame rate
        let frameInterval = 1.0 / Double(frameRate)
        let delayTime = frameInterval
        let ciContext = CIContext()
        var lastSampleTime: Double = -frameInterval
        var framesWritten = 0

        while let sampleBuffer = readerOutput.copyNextSampleBuffer() {
            let presentationTime = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))

            // Only take frames at our target interval
            guard presentationTime - lastSampleTime >= frameInterval * 0.9 else { continue }
            lastSampleTime = presentationTime

            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { continue }

            // Convert to CGImage
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            guard var cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { continue }

            // Apply click ripple highlights
            if highlightClicks, let events = mouseEvents, let size = displaySize {
                let clicks = events.filter { $0.type == .click }
                for click in clicks {
                    let timeSinceClick = presentationTime - click.timestamp
                    guard timeSinceClick >= 0 && timeSinceClick <= 0.4 else { continue }
                    let progress = CGFloat(timeSinceClick / 0.4)
                    let scaleX = CGFloat(cgImage.width) / size.width
                    let scaleY = CGFloat(cgImage.height) / size.height
                    let imagePos = CGPoint(
                        x: click.location.x * scaleX,
                        y: CGFloat(cgImage.height) - click.location.y * scaleY
                    )
                    if let enhanced = ClickRenderer.renderClickRipple(on: cgImage, at: imagePos, progress: progress) {
                        cgImage = enhanced
                    }
                }
            }

            // Apply step number badges
            if annotateSteps, let events = mouseEvents, let size = displaySize {
                let steps = StepAnnotator.detectSteps(from: events)
                for step in steps {
                    let timeSinceStep = presentationTime - step.timestamp
                    guard timeSinceStep >= -0.1 && timeSinceStep <= step.duration else { continue }
                    let progress = CGFloat(timeSinceStep / step.duration)
                    if let enhanced = StepAnnotator.renderStepBadge(on: cgImage, step: step, displaySize: size, progress: progress) {
                        cgImage = enhanced
                    }
                }
            }

            // Calculate delay for this frame (may be adjusted for speed-up)
            var frameDelay = delayTime
            if let multipliers = speedMultipliers {
                for (range, multiplier) in multipliers {
                    if presentationTime >= range.start && presentationTime <= range.end {
                        frameDelay = delayTime / multiplier
                        break
                    }
                }
            }

            // Add frame to GIF
            let frameProperties: [String: Any] = [
                kCGImagePropertyGIFDictionary as String: [
                    kCGImagePropertyGIFDelayTime as String: frameDelay,
                    kCGImagePropertyGIFUnclampedDelayTime as String: frameDelay,
                ] as [String: Any],
            ]
            CGImageDestinationAddImage(destination, cgImage, frameProperties as CFDictionary)
            framesWritten += 1
        }

        guard framesWritten > 0 else {
            throw GifEncoderError.noFramesEncoded
        }

        guard CGImageDestinationFinalize(destination) else {
            throw GifEncoderError.finalizeFailed
        }
    }
}

// MARK: - TimeRange

struct TimeRange: Hashable {
    let start: Double
    let end: Double

    var duration: Double { end - start }
}

// MARK: - Errors

enum GifEncoderError: LocalizedError {
    case invalidVideo
    case noVideoTrack
    case readerFailed(String)
    case createDestinationFailed
    case noFramesEncoded
    case finalizeFailed

    var errorDescription: String? {
        switch self {
        case .invalidVideo: return "Invalid video file"
        case .noVideoTrack: return "No video track found"
        case .readerFailed(let msg): return "Asset reader failed: \(msg)"
        case .createDestinationFailed: return "Failed to create GIF destination"
        case .noFramesEncoded: return "No frames were encoded"
        case .finalizeFailed: return "Failed to finalize GIF"
        }
    }
}
