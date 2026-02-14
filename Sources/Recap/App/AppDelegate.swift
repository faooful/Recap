import AppKit
import SwiftUI
import Carbon

/// Manages the menu bar status item, popover, and global hotkeys
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var previewWindow: NSWindow?
    private var eventMonitor: Any?

    let recorder = ScreenRecorder()
    let enhancer = AutoEnhancer()
    let shareManager = ShareManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create the status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "record.circle", accessibilityDescription: "Recap")
            image?.isTemplate = true
            button.image = image
            button.action = #selector(togglePopover)
            button.target = self
        }

        // Create the popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 420)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView(
                recorder: recorder,
                enhancer: enhancer,
                shareManager: shareManager,
                onShowPreview: { [weak self] session in
                    self?.showPreviewWindow(session: session)
                }
            )
        )

        // Register global hotkey (Cmd+Shift+R)
        registerGlobalHotkey()

        // Monitor for clicks outside popover to close it
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if let popover = self?.popover, popover.isShown {
                popover.performClose(nil)
            }
        }
    }

    // MARK: - Popover

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - Preview Window

    func showPreviewWindow(session: RecordingSession) {
        // Close existing preview window
        previewWindow?.close()

        let previewView = PreviewWindow(
            session: session,
            enhancer: enhancer,
            shareManager: shareManager
        )

        let hostingController = NSHostingController(rootView: previewView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Recap - \(session.displayName)"
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        window.setContentSize(NSSize(width: 700, height: 520))
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.isReleasedWhenClosed = false

        NSApp.activate(ignoringOtherApps: true)
        self.previewWindow = window
    }

    // MARK: - Global Hotkey

    private func registerGlobalHotkey() {
        // Cmd+Shift+6 (avoiding conflicts with common shortcuts)
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Cmd+Shift+6
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 22 {
                Task { @MainActor [weak self] in
                    await self?.toggleRecording()
                }
            }
        }

        // Also monitor local events (when our app is focused)
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 22 {
                Task { @MainActor [weak self] in
                    await self?.toggleRecording()
                }
                return nil
            }
            return event
        }
    }

    private func toggleRecording() async {
        if recorder.isRecording {
            await recorder.stopRecording()
            updateStatusIcon(recording: false)

            // Show preview if recording completed
            if let session = recorder.currentSession, session.state == .complete {
                showPreviewWindow(session: session)
            }
        } else {
            updateStatusIcon(recording: true)
            await recorder.startRecording()
        }
    }

    private func updateStatusIcon(recording: Bool) {
        if let button = statusItem.button {
            let symbolName = recording ? "record.circle.fill" : "record.circle"
            let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Recap")
            image?.isTemplate = !recording
            if recording {
                button.contentTintColor = .systemRed
            } else {
                button.contentTintColor = nil
            }
            button.image = image
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
