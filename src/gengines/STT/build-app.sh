#!/bin/bash

set -e

echo "🔨 Building Zeus_STT.app..."

# Kill any existing Zeus_STT instances
echo "🔫 Killing any existing Zeus_STT instances..."
pkill -f "Zeus_STT" || true
sleep 0.5  # Give it time to fully quit

# Build the Swift package
swift build -c release

# Create app bundle structure
APP_NAME="Zeus_STT"
APP_DIR="$APP_NAME.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Copy executable
cp .build/release/STTDictate "$APP_DIR/Contents/MacOS/"

# Copy Info.plist
cp Info.plist "$APP_DIR/Contents/"

# Generate and copy Zeus_STT lightning bolt icon
if [ -f "generate_icon.swift" ]; then
    swift generate_icon.swift
    if [ -f "Zeus_STT.icns" ]; then
        cp Zeus_STT.icns "$APP_DIR/Contents/Resources/"
        echo "⚡ Copied Zeus_STT lightning bolt .icns icon"
    else
        echo "⚠️ Zeus_STT.icns generation failed"
    fi
else
    echo "⚠️ Icon generator script not found"
fi

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


# Copy command processor script
if [ -f "ai_command_processor.py" ]; then
    cp ai_command_processor.py "$APP_DIR/Contents/Resources/"
    echo "✅ Copied command processor script to app bundle"
else
    echo "⚠️ Command processor script not found"
fi

# Copy Phase 4A hands-free components
if [ -f "vad_processor.py" ]; then
    cp vad_processor.py "$APP_DIR/Contents/Resources/"
    echo "✅ Copied VAD processor script to app bundle"
else
    echo "⚠️ VAD processor script not found"
fi

if [ -f "wake_word_detector.py" ]; then
    cp wake_word_detector.py "$APP_DIR/Contents/Resources/"
    echo "✅ Copied wake word detector script to app bundle"
else
    echo "⚠️ Wake word detector script not found"
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