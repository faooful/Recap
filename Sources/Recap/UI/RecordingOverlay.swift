import SwiftUI

/// Floating overlay shown during recording - displays timer and stop button
struct RecordingOverlay: View {
    @ObservedObject var recorder: ScreenRecorder

    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: 12) {
            // Recording indicator
            Circle()
                .fill(.red)
                .frame(width: 10, height: 10)
                .opacity(isPulsing ? 0.4 : 1.0)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPulsing)
                .onAppear { isPulsing = true }

            // Timer
            Text(recorder.currentSession?.formattedDuration ?? "0:00.0")
                .font(.system(.body, design: .monospaced))
                .fontWeight(.medium)
                .foregroundColor(.primary)

            Divider()
                .frame(height: 16)

            // Stop button
            Button(action: {
                Task { await recorder.stopRecording() }
            }) {
                Image(systemName: "stop.fill")
                    .font(.caption)
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(.red)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.2), radius: 8, y: 2)
    }
}

/// Window controller for the floating recording overlay
@MainActor
final class RecordingOverlayController {
    private var window: NSWindow?

    func show(recorder: ScreenRecorder) {
        guard window == nil else { return }

        let overlay = RecordingOverlay(recorder: recorder)
        let hostingView = NSHostingView(rootView: overlay)
        hostingView.frame = NSRect(x: 0, y: 0, width: 220, height: 44)

        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 44),
            styleMask: [.nonactivatingPanel, .hudWindow],
            backing: .buffered,
            defer: false
        )

        window.contentView = hostingView
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.hasShadow = false
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Position at top-center of screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - 110
            let y = screenFrame.maxY - 60
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }

        window.orderFrontRegardless()
        self.window = window
    }

    func hide() {
        window?.close()
        window = nil
    }
}
