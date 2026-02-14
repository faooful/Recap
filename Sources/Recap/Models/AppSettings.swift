import Foundation

/// User-configurable settings persisted via UserDefaults
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    // MARK: - Recording

    @Published var outputFormat: OutputFormat {
        didSet { UserDefaults.standard.set(outputFormat.rawValue, forKey: "outputFormat") }
    }

    @Published var captureFrameRate: Int {
        didSet { UserDefaults.standard.set(captureFrameRate, forKey: "captureFrameRate") }
    }

    @Published var gifFrameRate: Int {
        didSet { UserDefaults.standard.set(gifFrameRate, forKey: "gifFrameRate") }
    }

    @Published var maxGifDuration: Double {
        didSet { UserDefaults.standard.set(maxGifDuration, forKey: "maxGifDuration") }
    }

    // MARK: - Auto-Enhancement

    @Published var autoTrimSilence: Bool {
        didSet { UserDefaults.standard.set(autoTrimSilence, forKey: "autoTrimSilence") }
    }

    @Published var autoZoomOnClicks: Bool {
        didSet { UserDefaults.standard.set(autoZoomOnClicks, forKey: "autoZoomOnClicks") }
    }

    @Published var highlightClicks: Bool {
        didSet { UserDefaults.standard.set(highlightClicks, forKey: "highlightClicks") }
    }

    @Published var speedUpInactivity: Bool {
        didSet { UserDefaults.standard.set(speedUpInactivity, forKey: "speedUpInactivity") }
    }

    @Published var inactivityThreshold: Double {
        didSet { UserDefaults.standard.set(inactivityThreshold, forKey: "inactivityThreshold") }
    }

    @Published var inactivitySpeedMultiplier: Double {
        didSet { UserDefaults.standard.set(inactivitySpeedMultiplier, forKey: "inactivitySpeedMultiplier") }
    }

    // MARK: - Appearance

    @Published var showCursor: Bool {
        didSet { UserDefaults.standard.set(showCursor, forKey: "showCursor") }
    }

    @Published var cursorScale: Double {
        didSet { UserDefaults.standard.set(cursorScale, forKey: "cursorScale") }
    }

    // MARK: - Output

    @Published var defaultSaveLocation: URL {
        didSet { UserDefaults.standard.set(defaultSaveLocation.path, forKey: "defaultSaveLocation") }
    }

    @Published var copyToClipboardAfterExport: Bool {
        didSet { UserDefaults.standard.set(copyToClipboardAfterExport, forKey: "copyToClipboardAfterExport") }
    }

    // MARK: - Init

    private init() {
        let defaults = UserDefaults.standard

        self.outputFormat = OutputFormat(rawValue: defaults.string(forKey: "outputFormat") ?? "") ?? .gif
        self.captureFrameRate = defaults.object(forKey: "captureFrameRate") as? Int ?? 30
        self.gifFrameRate = defaults.object(forKey: "gifFrameRate") as? Int ?? 12
        self.maxGifDuration = defaults.object(forKey: "maxGifDuration") as? Double ?? 30.0
        self.autoTrimSilence = defaults.object(forKey: "autoTrimSilence") as? Bool ?? true
        self.autoZoomOnClicks = defaults.object(forKey: "autoZoomOnClicks") as? Bool ?? true
        self.highlightClicks = defaults.object(forKey: "highlightClicks") as? Bool ?? true
        self.speedUpInactivity = defaults.object(forKey: "speedUpInactivity") as? Bool ?? true
        self.inactivityThreshold = defaults.object(forKey: "inactivityThreshold") as? Double ?? 1.5
        self.inactivitySpeedMultiplier = defaults.object(forKey: "inactivitySpeedMultiplier") as? Double ?? 4.0
        self.showCursor = defaults.object(forKey: "showCursor") as? Bool ?? true
        self.cursorScale = defaults.object(forKey: "cursorScale") as? Double ?? 1.5
        self.copyToClipboardAfterExport = defaults.object(forKey: "copyToClipboardAfterExport") as? Bool ?? true

        if let path = defaults.string(forKey: "defaultSaveLocation") {
            self.defaultSaveLocation = URL(fileURLWithPath: path)
        } else {
            self.defaultSaveLocation = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        }
    }
}

// MARK: - Output Format

enum OutputFormat: String, CaseIterable, Identifiable {
    case gif = "gif"
    case mp4 = "mp4"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gif: return "GIF"
        case .mp4: return "MP4"
        }
    }

    var fileExtension: String { rawValue }

    var utType: String {
        switch self {
        case .gif: return "com.compuserve.gif"
        case .mp4: return "public.mpeg-4"
        }
    }
}
