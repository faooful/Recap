import SwiftUI
import AVKit

/// Preview window shown after recording completes - allows playback, processing, and export
struct PreviewWindow: View {
    @ObservedObject var session: RecordingSession
    @ObservedObject var enhancer: AutoEnhancer
    @ObservedObject var shareManager: ShareManager
    @ObservedObject private var settings = AppSettings.shared

    @ObservedObject private var history = RecordingHistory.shared

    @State private var player: AVPlayer?
    @State private var isProcessing = false
    @State private var processedURL: URL?
    @State private var errorMessage: String?
    @State private var fileSize: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Video preview
            videoPreview
                .frame(minHeight: 300)

            Divider()

            // Controls
            controlsBar
        }
        .frame(minWidth: 600, minHeight: 460)
        .onAppear {
            setupPlayer()
        }
    }

    // MARK: - Video Preview

    private var videoPreview: some View {
        ZStack {
            Color.black

            if let player = player {
                VideoPlayer(player: player)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "film")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No preview available")
                        .foregroundColor(.secondary)
                }
            }

            // Processing overlay
            if isProcessing {
                processingOverlay
            }
        }
    }

    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)

            VStack(spacing: 16) {
                ProgressView(value: enhancer.progress)
                    .progressViewStyle(.circular)
                    .scaleEffect(1.5)

                Text(enhancer.status)
                    .font(.subheadline)
                    .foregroundColor(.white)

                if enhancer.progress > 0 {
                    ProgressView(value: enhancer.progress)
                        .frame(width: 200)
                }
            }
        }
    }

    // MARK: - Controls Bar

    private var controlsBar: some View {
        VStack(spacing: 12) {
            // Info row
            HStack {
                Label(session.formattedDuration, systemImage: "clock")
                    .font(.caption)

                Spacer()

                if !fileSize.isEmpty {
                    Label(fileSize, systemImage: "doc")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Picker("Format", selection: $settings.outputFormat) {
                    ForEach(OutputFormat.allCases) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
            }

            // Enhancement options
            HStack(spacing: 16) {
                Toggle("Trim dead time", isOn: $settings.speedUpInactivity)
                    .font(.caption)
                Toggle("Highlight clicks", isOn: $settings.highlightClicks)
                    .font(.caption)
                Spacer()
            }

            // Error display
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            // Action buttons
            HStack(spacing: 8) {
                // Process & Export
                Button(action: { Task { await processAndExport() } }) {
                    HStack {
                        Image(systemName: "wand.and.stars")
                        Text(processedURL != nil ? "Re-process" : "Process & Export")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isProcessing)

                // Copy to clipboard
                if let url = processedURL {
                    Button(action: { copyToClipboard(url: url) }) {
                        HStack {
                            Image(systemName: "doc.on.clipboard")
                            Text("Copy")
                        }
                    }
                    .buttonStyle(.bordered)

                    // Save As
                    Button(action: { saveAs(url: url) }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Save")
                        }
                    }
                    .buttonStyle(.bordered)

                    // Reveal in Finder
                    Button(action: { shareManager.revealInFinder(fileURL: url) }) {
                        Image(systemName: "folder")
                    }
                    .buttonStyle(.bordered)
                }
            }

            // Status
            if !shareManager.exportStatus.isEmpty {
                Text(shareManager.exportStatus)
                    .font(.caption)
                    .foregroundColor(.green)
                    .transition(.opacity)
            }
        }
        .padding(16)
    }

    // MARK: - Actions

    private func setupPlayer() {
        if let url = session.rawVideoURL, FileManager.default.fileExists(atPath: url.path) {
            player = AVPlayer(url: url)
            player?.play()

            // Loop playback
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player?.currentItem,
                queue: .main
            ) { _ in
                player?.seek(to: .zero)
                player?.play()
            }
        }
    }

    private func processAndExport() async {
        isProcessing = true
        errorMessage = nil

        let tempDir = FileManager.default.temporaryDirectory
        let outputName = "\(session.displayName).\(settings.outputFormat.fileExtension)"
        let outputURL = tempDir.appendingPathComponent(outputName)

        // Remove existing file
        try? FileManager.default.removeItem(at: outputURL)

        do {
            try await enhancer.process(
                session: session,
                settings: settings,
                outputURL: outputURL
            )

            processedURL = outputURL
            fileSize = ShareManager.formattedFileSize(url: outputURL)

            // Save to history
            history.add(session: session, outputURL: outputURL, format: settings.outputFormat)

            // Auto-copy to clipboard if enabled
            if settings.copyToClipboardAfterExport {
                _ = shareManager.copyToClipboard(fileURL: outputURL)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isProcessing = false
    }

    private func copyToClipboard(url: URL) {
        _ = shareManager.copyToClipboard(fileURL: url)
    }

    private func saveAs(url: URL) {
        _ = shareManager.saveToFile(
            sourceURL: url,
            suggestedName: "\(session.displayName).\(settings.outputFormat.fileExtension)"
        )
    }
}
