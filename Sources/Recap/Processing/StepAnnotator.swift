import Foundation
import CoreGraphics
import CoreText

/// Detects discrete "steps" from click patterns and renders step number badges
/// This auto-annotates walkthrough recordings with step indicators
struct StepAnnotator {
    /// Detect steps from mouse events - each significant click is a "step"
    /// Clicks close together in time (< mergeThreshold) are merged into one step
    static func detectSteps(
        from mouseEvents: [MouseEvent],
        mergeThreshold: Double = 0.5
    ) -> [WalkthroughStep] {
        let clicks = mouseEvents
            .filter { $0.type == .click }
            .sorted { $0.timestamp < $1.timestamp }

        guard !clicks.isEmpty else { return [] }

        var steps: [WalkthroughStep] = []
        var currentGroup: [MouseEvent] = [clicks[0]]

        for i in 1..<clicks.count {
            let gap = clicks[i].timestamp - clicks[i - 1].timestamp
            if gap < mergeThreshold {
                // Merge with current group
                currentGroup.append(clicks[i])
            } else {
                // Finalize current group as a step
                let step = createStep(from: currentGroup, number: steps.count + 1)
                steps.append(step)
                currentGroup = [clicks[i]]
            }
        }

        // Finalize last group
        if !currentGroup.isEmpty {
            let step = createStep(from: currentGroup, number: steps.count + 1)
            steps.append(step)
        }

        return steps
    }

    private static func createStep(from events: [MouseEvent], number: Int) -> WalkthroughStep {
        let avgX = events.map(\.location.x).reduce(0, +) / CGFloat(events.count)
        let avgY = events.map(\.location.y).reduce(0, +) / CGFloat(events.count)
        let timestamp = events.first?.timestamp ?? 0

        return WalkthroughStep(
            number: number,
            timestamp: timestamp,
            position: CGPoint(x: avgX, y: avgY),
            duration: (events.last?.timestamp ?? timestamp) - timestamp + 0.5
        )
    }

    /// Render a step number badge onto a frame
    static func renderStepBadge(
        on image: CGImage,
        step: WalkthroughStep,
        displaySize: CGSize,
        progress: CGFloat // 0 = just appeared, 1 = about to disappear
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

        // Convert coordinates
        let scaleX = CGFloat(width) / displaySize.width
        let scaleY = CGFloat(height) / displaySize.height
        let pos = CGPoint(
            x: step.position.x * scaleX,
            y: CGFloat(height) - step.position.y * scaleY
        )

        let badgeSize: CGFloat = 28
        let alpha = min(1.0, progress < 0.1 ? progress * 10 : (progress > 0.9 ? (1 - progress) * 10 : 1.0))

        // Badge background (red circle)
        context.setFillColor(CGColor(red: 0.9, green: 0.2, blue: 0.2, alpha: alpha))
        context.fillEllipse(in: CGRect(
            x: pos.x - badgeSize / 2 + 20,
            y: pos.y - badgeSize / 2 - 20,
            width: badgeSize,
            height: badgeSize
        ))

        // Step number text
        let text = "\(step.number)" as CFString
        let font = CTFontCreateWithName("Helvetica-Bold" as CFString, 16, nil)
        let attributes: [CFString: Any] = [
            kCTFontAttributeName: font,
            kCTForegroundColorAttributeName: CGColor(red: 1, green: 1, blue: 1, alpha: alpha),
        ]
        let attrString = CFAttributedStringCreate(nil, text, attributes as CFDictionary)!
        let line = CTLineCreateWithAttributedString(attrString)
        let textBounds = CTLineGetBoundsWithOptions(line, [])

        context.textPosition = CGPoint(
            x: pos.x + 20 - textBounds.width / 2,
            y: pos.y - 20 - textBounds.height / 4
        )
        CTLineDraw(line, context)

        return context.makeImage()
    }
}

// MARK: - WalkthroughStep

struct WalkthroughStep {
    let number: Int
    let timestamp: TimeInterval
    let position: CGPoint
    let duration: TimeInterval
}
