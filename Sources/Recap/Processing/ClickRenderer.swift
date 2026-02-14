import Foundation
import CoreGraphics
import CoreImage

/// Renders click highlight ripple effects onto video frames
struct ClickRenderer {
    /// Draw a click ripple effect onto a CGImage at the specified position
    /// - Parameters:
    ///   - image: Source frame
    ///   - position: Click position in image coordinates
    ///   - progress: Animation progress (0.0 to 1.0)
    ///   - color: Ripple color
    /// - Returns: New image with ripple overlay
    static func renderClickRipple(
        on image: CGImage,
        at position: CGPoint,
        progress: CGFloat,
        color: CGColor = CGColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0)
    ) -> CGImage? {
        let width = image.width
        let height = image.height

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return image }

        // Draw original image
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Draw ripple effect
        let maxRadius: CGFloat = 40.0
        let currentRadius = maxRadius * progress
        let alpha = max(0, 1.0 - progress) * 0.6

        // Outer ring
        context.setStrokeColor(color.copy(alpha: alpha) ?? color)
        context.setLineWidth(3.0 * (1.0 - progress * 0.5))
        context.addArc(
            center: position,
            radius: currentRadius,
            startAngle: 0,
            endAngle: .pi * 2,
            clockwise: false
        )
        context.strokePath()

        // Inner dot (fades faster)
        let dotAlpha = max(0, 1.0 - progress * 2) * 0.8
        if dotAlpha > 0 {
            context.setFillColor(color.copy(alpha: dotAlpha) ?? color)
            context.fillEllipse(in: CGRect(
                x: position.x - 4,
                y: position.y - 4,
                width: 8,
                height: 8
            ))
        }

        return context.makeImage()
    }

    /// Apply click highlights to a sequence of frames based on mouse events
    /// - Parameters:
    ///   - frames: Source frames with timestamps
    ///   - clicks: Click events with positions and times
    ///   - displayHeight: The display height for coordinate conversion
    ///   - rippleDuration: How long each ripple animation lasts (seconds)
    /// - Returns: Enhanced frames with click ripples
    static func applyClickHighlights(
        frames: [(image: CGImage, timestamp: Double)],
        clicks: [MouseEvent],
        displaySize: CGSize,
        rippleDuration: Double = 0.4
    ) -> [(image: CGImage, timestamp: Double)] {
        let clickEvents = clicks.filter { $0.type == .click }
        guard !clickEvents.isEmpty else { return frames }

        return frames.map { frame in
            var currentImage = frame.image

            for click in clickEvents {
                let timeSinceClick = frame.timestamp - click.timestamp

                // Only render if within ripple duration
                guard timeSinceClick >= 0 && timeSinceClick <= rippleDuration else { continue }

                let progress = CGFloat(timeSinceClick / rippleDuration)

                // Convert screen coordinates to image coordinates
                let scaleX = CGFloat(currentImage.width) / displaySize.width
                let scaleY = CGFloat(currentImage.height) / displaySize.height
                let imagePos = CGPoint(
                    x: click.location.x * scaleX,
                    y: CGFloat(currentImage.height) - click.location.y * scaleY // Flip Y
                )

                if let enhanced = renderClickRipple(on: currentImage, at: imagePos, progress: progress) {
                    currentImage = enhanced
                }
            }

            return (image: currentImage, timestamp: frame.timestamp)
        }
    }
}
