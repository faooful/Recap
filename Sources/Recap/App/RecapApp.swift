import SwiftUI

/// Recap - Lightweight automated walkthrough recorder
/// A menubar app that captures screen recordings and automatically
/// enhances them with dead-time compression, click highlights, and
/// auto-zoom for effortless team sharing.
@main
struct RecapApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Settings window (opened via menubar)
        Settings {
            SettingsView()
                .frame(minWidth: 400, minHeight: 500)
        }
    }
}
