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
        speedMultipliers: [TimeRange: Double]? = nil
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
            guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { continue }

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
