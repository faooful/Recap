import SwiftUI

/// Settings/preferences view for the app
struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Form {
            // Recording
            Section("Recording") {
                Picker("Frame Rate", selection: $settings.captureFrameRate) {
                    Text("15 fps").tag(15)
                    Text("24 fps").tag(24)
                    Text("30 fps").tag(30)
                    Text("60 fps").tag(60)
                }

                Toggle("Show cursor", isOn: $settings.showCursor)

                if settings.showCursor {
                    HStack {
                        Text("Cursor size")
                        Slider(value: $settings.cursorScale, in: 1.0...3.0, step: 0.25)
                        Text("\(settings.cursorScale, specifier: "%.1fx")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 36)
                    }
                }
            }

            // Output
            Section("Output") {
                Picker("Default format", selection: $settings.outputFormat) {
                    ForEach(OutputFormat.allCases) { format in
                        Text(format.displayName).tag(format)
                    }
                }

                if settings.outputFormat == .gif {
                    Picker("GIF frame rate", selection: $settings.gifFrameRate) {
                        Text("8 fps (smaller)").tag(8)
                        Text("12 fps (balanced)").tag(12)
                        Text("15 fps (smoother)").tag(15)
                    }
                }

                Toggle("Copy to clipboard after export", isOn: $settings.copyToClipboardAfterExport)
            }

            // Auto-Enhancement
            Section("Auto-Enhancement") {
                Toggle("Speed up inactive periods", isOn: $settings.speedUpInactivity)

                if settings.speedUpInactivity {
                    HStack {
                        Text("Inactivity threshold")
                        Slider(value: $settings.inactivityThreshold, in: 0.5...5.0, step: 0.5)
                        Text("\(settings.inactivityThreshold, specifier: "%.1fs")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 36)
                    }

                    HStack {
                        Text("Speed multiplier")
                        Slider(value: $settings.inactivitySpeedMultiplier, in: 2.0...10.0, step: 1.0)
                        Text("\(Int(settings.inactivitySpeedMultiplier))x")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 36)
                    }
                }

                Toggle("Highlight mouse clicks", isOn: $settings.highlightClicks)
                Toggle("Auto-zoom on activity", isOn: $settings.autoZoomOnClicks)
            }

            // About
            Section("About") {
                HStack {
                    Text("Recap")
                        .fontWeight(.medium)
                    Spacer()
                    Text("v1.0.0")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Shortcut")
                    Spacer()
                    Text("⌘⇧6")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 8)
    }
}
