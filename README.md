# Recap

**Lightweight automated walkthrough recorder for macOS.**

Record your screen, and Recap automatically makes it look good — trimming dead time, highlighting clicks, and exporting as a GIF or MP4 ready to drop in a PR, Slack thread, or doc. No editing required.

<img width="320" alt="Recap menubar" src="https://img.shields.io/badge/macOS-14%2B-blue?style=flat-square&logo=apple"/>

---

## Why Recap?

Most screen recording tools fall into two camps: **simple but raw** (Kap, LICEcap) or **polished but manual** (Screen Studio, Loom). Recap sits in the middle — it gives you **auto-enhanced output with zero effort**, optimized for sharing with your team.

### The Workflow

1. **Hit ⌘⇧6** (or click the menubar icon)
2. **Do your walkthrough** — show the bug, demo the feature, walk through the PR
3. **Hit ⌘⇧6 again** to stop
4. **Recap auto-processes**: trims dead time, highlights clicks, and encodes a compact GIF
5. **It's on your clipboard** — paste it wherever

### Key Features

- **Menubar app** — lives in your status bar, always one shortcut away
- **Auto dead-time compression** — speeds up periods where nothing happens
- **Click highlighting** — mouse clicks are tracked for visual emphasis
- **Auto-zoom on activity** — follows cursor to the action (coming soon)
- **GIF-first output** — optimized for Slack, GitHub, and docs
- **MP4 export** — full quality when you need it
- **One-click clipboard copy** — processed output goes straight to clipboard
- **Window or full-screen capture** — record a specific app or everything
- **Lightweight** — native Swift, no Electron, minimal resource usage

## Getting Started

### Requirements

- macOS 14 (Sonoma) or later
- Xcode Command Line Tools (`xcode-select --install`)

### Build & Run

```bash
# Clone the repo
git clone https://github.com/faooful/Recap.git
cd Recap

# Build the app bundle
./Scripts/build.sh

# Launch
open Recap.app
```

On first launch, macOS will ask for **Screen Recording** permission. Go to **System Settings → Privacy & Security → Screen Recording** and enable Recap.

### Development

```bash
# Build for debugging
swift build

# Run directly (without .app bundle)
swift run Recap

# Build release
swift build -c release
```

## Architecture

Recap is built with native macOS technologies for minimal overhead:

| Component | Technology |
|-----------|-----------|
| UI | SwiftUI + AppKit (menubar) |
| Screen Capture | ScreenCaptureKit |
| Video Processing | AVFoundation |
| GIF Encoding | ImageIO (CGImageDestination) |
| Mouse Tracking | NSEvent global monitors |

### Project Structure

```
Sources/Recap/
├── App/
│   ├── RecapApp.swift          # @main entry point
│   └── AppDelegate.swift       # Menubar, hotkeys, window management
├── Recording/
│   ├── ScreenRecorder.swift    # High-level recording API
│   └── CaptureEngine.swift     # ScreenCaptureKit + AVAssetWriter
├── Processing/
│   ├── GifEncoder.swift        # Video → animated GIF
│   └── AutoEnhancer.swift      # Dead time, clicks, zoom analysis
├── UI/
│   ├── MenuBarView.swift       # Menubar popover UI
│   ├── PreviewWindow.swift     # Post-recording preview + export
│   └── SettingsView.swift      # Preferences
├── Export/
│   └── ShareManager.swift      # Clipboard, file save, Finder reveal
└── Models/
    ├── RecordingSession.swift  # Session state + captured data
    └── AppSettings.swift       # UserDefaults-backed settings
```

## Roadmap

- [ ] Auto-zoom with smooth easing on cursor activity
- [ ] Click ripple effect overlay on exported GIF
- [ ] Step-number annotations (auto-detected from clicks)
- [ ] Drag-to-select recording region
- [ ] Custom background/padding (Screen Studio style)
- [ ] Shareable link generation (upload to S3/Cloudflare R2)
- [ ] Audio narration support
- [ ] Recording history with thumbnails

## Design Principles

1. **Zero-config by default** — works great out of the box
2. **Speed over polish** — optimized for the "quick share" use case
3. **GIF-native** — GIFs play everywhere, no video player needed
4. **Lightweight** — native code, small binary, low memory usage
5. **Privacy-first** — everything happens locally, nothing uploaded

## License

MIT
