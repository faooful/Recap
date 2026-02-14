#!/bin/bash
set -euo pipefail

# Recap Build Script
# Builds the Swift package and wraps it in a macOS .app bundle

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/.build"
APP_NAME="Recap"
APP_BUNDLE="$PROJECT_DIR/$APP_NAME.app"

echo "🎬 Building Recap..."

# Step 1: Build with Swift Package Manager
cd "$PROJECT_DIR"
swift build -c release 2>&1

EXECUTABLE="$BUILD_DIR/release/$APP_NAME"

if [ ! -f "$EXECUTABLE" ]; then
    echo "❌ Build failed - executable not found at $EXECUTABLE"
    exit 1
fi

echo "✅ Build successful"

# Step 2: Create .app bundle
echo "📦 Creating app bundle..."

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy executable
cp "$EXECUTABLE" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Copy Info.plist
cp "$PROJECT_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/"

# Copy entitlements (for reference)
cp "$PROJECT_DIR/Resources/Recap.entitlements" "$APP_BUNDLE/Contents/Resources/"

# Create PkgInfo
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

# Step 3: Ad-hoc code sign
echo "🔏 Code signing..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo ""
echo "✅ Recap.app built successfully!"
echo "📍 Location: $APP_BUNDLE"
echo ""
echo "To run:"
echo "  open $APP_BUNDLE"
echo ""
echo "Note: On first launch, macOS will ask for Screen Recording permission."
echo "Go to System Settings > Privacy & Security > Screen Recording and enable Recap."
