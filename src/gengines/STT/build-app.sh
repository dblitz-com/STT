#!/bin/bash

set -e

echo "🔨 Building STT Dictate.app..."

# Kill any existing STT Dictate instances
echo "🔫 Killing any existing STT Dictate instances..."
pkill -f "STT Dictate" || true
sleep 0.5  # Give it time to fully quit

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

# Copy custom dictation sounds
if [ -f "Resources/dictation_event1.wav" ] && [ -f "Resources/dictation_event2.wav" ]; then
    cp Resources/dictation_event*.wav "$APP_DIR/Contents/Resources/"
    echo "✅ Copied dictation sounds to app bundle"
else
    echo "⚠️ Dictation sounds not found in Resources/"
fi

# Copy AI editor script and virtual environment
if [ -f "ai_editor.py" ]; then
    cp ai_editor.py "$APP_DIR/Contents/Resources/"
    echo "✅ Copied AI editor script to app bundle"
else
    echo "⚠️ AI editor script not found"
fi

if [ -d "venv" ]; then
    cp -r venv "$APP_DIR/Contents/Resources/"
    echo "✅ Copied Python virtual environment to app bundle"
else
    echo "⚠️ Python virtual environment not found"
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