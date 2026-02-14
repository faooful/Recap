import SwiftUI
import ScreenCaptureKit

/// The main popover view shown from the menu bar
struct MenuBarView: View {
    @ObservedObject var recorder: ScreenRecorder
    @ObservedObject var enhancer: AutoEnhancer
    @ObservedObject var shareManager: ShareManager
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var history = RecordingHistory.shared

    var onShowPreview: (RecordingSession) -> Void

    @State private var selectedWindow: SCWindow?
    @State private var recordMode: RecordMode = .fullScreen
    @State private var showSettings = false
    @State private var showHistory = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            if recorder.isRecording {
                recordingView
            } else if let session = recorder.currentSession, session.state == .complete {
                completedView(session: session)
            } else if let session = recorder.currentSession, case .failed(let msg) = session.state {
                failedView(message: msg)
            } else if showHistory {
                historyView
            } else {
                setupView
            }

            Divider()

            // Footer
            footer
        }
        .frame(width: 320)
        .task {
            await recorder.checkPermission()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "record.circle.fill")
                .foregroundColor(.red)
                .font(.title2)

            Text("Recap")
                .font(.headline)

            Spacer()

            Text("⌘⇧6")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.15))
                .cornerRadius(4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Setup View (not recording)

    private var setupView: some View {
        VStack(spacing: 12) {
            // Permission / error banner
            if recorder.permissionStatus == .denied {
                permissionBanner
            } else if let error = recorder.errorMessage {
                errorBanner(message: error)
            }

            // Record mode picker
            Picker("Capture", selection: $recordMode) {
                ForEach(RecordMode.allCases) { mode in
                    Label(mode.displayName, systemImage: mode.icon)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)

            // Window picker (if window mode)
            if recordMode == .window {
                windowPicker
            }

            // Output format
            HStack {
                Text("Output")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Picker("", selection: $settings.outputFormat) {
                    ForEach(OutputFormat.allCases) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
            }
            .padding(.horizontal, 16)

            // Enhancement toggles
            VStack(spacing: 6) {
                Toggle("Auto-trim dead time", isOn: $settings.speedUpInactivity)
                Toggle("Highlight clicks", isOn: $settings.highlightClicks)
                Toggle("Auto-zoom on activity", isOn: $settings.autoZoomOnClicks)
            }
            .font(.caption)
            .padding(.horizontal, 16)

            // Record button
            Button(action: {
                Task { await startRecording() }
            }) {
                HStack {
                    Image(systemName: "circle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                    Text("Start Recording")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red.opacity(0.85))
            .padding(.horizontal, 16)
            .disabled(recorder.permissionStatus == .checking)
        }
        .padding(.vertical, 12)
    }

    // MARK: - Permission & Error Banners

    private var permissionBanner: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "lock.shield")
                    .foregroundColor(.orange)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Screen Recording Access Needed")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text("Recap needs permission to capture your screen.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            Button(action: {
                recorder.openScreenRecordingSettings()
            }) {
                HStack {
                    Image(systemName: "gear")
                        .font(.caption)
                    Text("Grant Access in System Settings")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)

            Button("Re-check Permission") {
                Task { await recorder.checkPermission() }
            }
            .font(.caption2)
            .buttonStyle(.borderless)
            .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color.orange.opacity(0.08))
        .cornerRadius(8)
        .padding(.horizontal, 16)
    }

    private func errorBanner(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
                .font(.caption)

            Text(message)
                .font(.caption2)
                .foregroundColor(.red)
                .lineLimit(3)

            Spacer()

            Button(action: { recorder.clearError() }) {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
            .buttonStyle(.borderless)
        }
        .padding(10)
        .background(Color.red.opacity(0.08))
        .cornerRadius(8)
        .padding(.horizontal, 16)
    }

    // MARK: - Recording View

    private var recordingView: some View {
        VStack(spacing: 16) {
            // Recording indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(.red)
                    .frame(width: 10, height: 10)
                    .pulsingAnimation()

                Text("Recording")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Text(recorder.currentSession?.formattedDuration ?? "0:00.0")
                    .font(.system(.title2, design: .monospaced))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 16)

            // Stop button
            Button(action: {
                Task { await stopRecording() }
            }) {
                HStack {
                    Image(systemName: "stop.fill")
                        .font(.caption)
                    Text("Stop Recording")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.primary.opacity(0.8))
            .padding(.horizontal, 16)

            Text("or press ⌘⇧6")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 16)
    }

    // MARK: - Completed View

    private func completedView(session: RecordingSession) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)

                VStack(alignment: .leading) {
                    Text("Recording Complete")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("\(session.formattedDuration) • \(session.frameCount) frames")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 16)

            HStack(spacing: 8) {
                Button("Preview & Export") {
                    onShowPreview(session)
                }
                .buttonStyle(.borderedProminent)

                Button("New Recording") {
                    recorder.currentSession = nil
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 16)
    }

    // MARK: - Failed View

    private func failedView(message: String) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .font(.title2)

                VStack(alignment: .leading) {
                    Text("Recording Failed")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }

                Spacer()
            }
            .padding(.horizontal, 16)

            HStack(spacing: 8) {
                Button("Try Again") {
                    recorder.currentSession = nil
                    recorder.clearError()
                }
                .buttonStyle(.borderedProminent)

                Button("Open Settings") {
                    recorder.openScreenRecordingSettings()
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 16)
    }

    // MARK: - Window Picker

    private var windowPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(recorder.availableWindows, id: \.windowID) { window in
                        HStack {
                            if let appName = window.owningApplication?.applicationName {
                                Text(appName)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            if let title = window.title, !title.isEmpty {
                                Text("- \(title)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(selectedWindow?.windowID == window.windowID ? Color.accentColor.opacity(0.2) : Color.clear)
                        .cornerRadius(4)
                        .onTapGesture {
                            selectedWindow = window
                        }
                    }
                }
            }
            .frame(maxHeight: 120)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - History View

    private var historyView: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Recent Recordings")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Button("Back") { showHistory = false }
                    .font(.caption)
                    .buttonStyle(.borderless)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            if history.entries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "film.stack")
                        .font(.title)
                        .foregroundColor(.secondary)
                    Text("No recordings yet")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(height: 120)
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(history.entries) { entry in
                            historyRow(entry: entry)
                        }
                    }
                }
                .frame(maxHeight: 240)
            }
        }
        .padding(.vertical, 8)
    }

    private func historyRow(entry: HistoryEntry) -> some View {
        HStack(spacing: 8) {
            Image(systemName: entry.format == .gif ? "photo.badge.arrow.down" : "film")
                .foregroundColor(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(entry.formattedDuration)
                    Text("•")
                    Text(entry.formattedSize)
                    Text("•")
                    Text(entry.formattedDate)
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }

            Spacer()

            // Quick copy
            Button(action: {
                _ = shareManager.copyToClipboard(fileURL: entry.outputURL)
            }) {
                Image(systemName: "doc.on.clipboard")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .help("Copy to clipboard")

            // Reveal in Finder
            Button(action: {
                shareManager.revealInFinder(fileURL: entry.outputURL)
            }) {
                Image(systemName: "folder")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .help("Reveal in Finder")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button(action: { showSettings.toggle() }) {
                Image(systemName: "gear")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .popover(isPresented: $showSettings) {
                SettingsView()
                    .frame(width: 300, height: 400)
            }

            Button(action: { showHistory.toggle() }) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .help("Recording history")

            Spacer()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Actions

    private func startRecording() async {
        recorder.clearError()

        switch recordMode {
        case .fullScreen:
            await recorder.startRecording()
        case .window:
            if let window = selectedWindow {
                await recorder.startRecording(window: window)
            } else {
                await recorder.startRecording()
            }
        }

        // If recording started, the popover will be closed by AppDelegate
        // If it failed, the error banner will show in the current view
    }

    private func stopRecording() async {
        await recorder.stopRecording()
    }
}

// MARK: - Record Mode

enum RecordMode: String, CaseIterable, Identifiable {
    case fullScreen = "fullscreen"
    case window = "window"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fullScreen: return "Full Screen"
        case .window: return "Window"
        }
    }

    var icon: String {
        switch self {
        case .fullScreen: return "rectangle.dashed"
        case .window: return "macwindow"
        }
    }
}

// MARK: - Pulsing Animation

struct PulsingModifier: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? 0.4 : 1.0)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear { isPulsing = true }
    }
}

extension View {
    func pulsingAnimation() -> some View {
        modifier(PulsingModifier())
    }
}
