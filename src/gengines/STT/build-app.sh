#!/bin/bash

set -e

echo "🔨 Building STT Dictate.app..."

# Build the Swift package
swift build -c release

# Create app bundle structure
APP_NAME="STT Dictate"
APP_DIR="$APP_NAME.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Copy executable
cp .build/release/STTDictate "$APP_DIR/Contents/MacOS/"

# Copy Info.plist
cp Info.plist "$APP_DIR/Contents/"

# Copy WhisperKit models
if [ -d "WhisperKit/Models" ]; then
    cp -r WhisperKit "$APP_DIR/Contents/Resources/"
fi

# Sign the app with entitlements (Wispr Flow approach - no sandbox)
codesign --force --deep --sign - --entitlements STTDictate.entitlements "$APP_DIR"

echo "✅ Built: $APP_DIR"
echo ""
echo "To install:"
echo "1. Move to Applications: mv \"$APP_DIR\" /Applications/"
echo "2. Open from Applications folder"
echo "3. Grant Accessibility permissions when prompted"
echo ""
echo "The app will appear as 🎤 in your menu bar"