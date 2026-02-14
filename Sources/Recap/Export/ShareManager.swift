import AppKit
import Foundation
import UniformTypeIdentifiers

/// Handles exporting and sharing recordings via clipboard, file save, and drag
@MainActor
final class ShareManager: ObservableObject {
    @Published var lastExportedURL: URL?
    @Published var exportStatus: String = ""

    /// Copy a file (GIF or MP4) to the system clipboard
    func copyToClipboard(fileURL: URL) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        guard let data = try? Data(contentsOf: fileURL) else {
            exportStatus = "Failed to read file"
            return false
        }

        let fileExtension = fileURL.pathExtension.lowercased()

        if fileExtension == "gif" {
            // For GIFs, write as file URL and as GIF data
            pasteboard.setData(data, forType: .init("com.compuserve.gif"))
            pasteboard.writeObjects([fileURL as NSURL])
        } else {
            // For other formats, write as file URL
            pasteboard.writeObjects([fileURL as NSURL])
        }

        exportStatus = "Copied to clipboard"
        lastExportedURL = fileURL
        return true
    }

    /// Save a recording to a user-selected location
    func saveToFile(sourceURL: URL, suggestedName: String) -> URL? {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = suggestedName
        panel.allowedContentTypes = [
            sourceURL.pathExtension == "gif" ? UTType.gif : UTType.mpeg4Movie
        ]

        guard panel.runModal() == .OK, let destURL = panel.url else {
            return nil
        }

        do {
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
            lastExportedURL = destURL
            exportStatus = "Saved to \(destURL.lastPathComponent)"
            return destURL
        } catch {
            exportStatus = "Failed to save: \(error.localizedDescription)"
            return nil
        }
    }

    /// Quick-save to the default save location
    func quickSave(sourceURL: URL, name: String) -> URL? {
        let settings = AppSettings.shared
        let destURL = settings.defaultSaveLocation
            .appendingPathComponent(name)
            .appendingPathExtension(settings.outputFormat.fileExtension)

        do {
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
            lastExportedURL = destURL
            exportStatus = "Saved to Desktop"
            return destURL
        } catch {
            exportStatus = "Failed to save: \(error.localizedDescription)"
            return nil
        }
    }

    /// Reveal a file in Finder
    func revealInFinder(fileURL: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
    }

    /// Get the file size as a human-readable string
    static func formattedFileSize(url: URL) -> String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int64 else {
            return "Unknown size"
        }

        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}
