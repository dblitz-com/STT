#!/bin/bash

# Safe Development Build Script
# Creates "Zeus_STT Dev.app" with feature flags to prevent CGEventTap conflicts

set -e  # Exit on any error

echo "🔨 Building SAFE dev version with conflict prevention..."
echo ""

# Safety check: Warn if production app is running
if pgrep -f "Zeus_STT.app" > /dev/null; then
    echo "⚠️  WARNING: Production Zeus_STT is currently running!"
    echo "⚠️  For safety, close production app before testing dev version"
    echo "⚠️  Two CGEventTaps can cause system freezes"
    echo ""
    read -p "🔧 Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Build cancelled for safety"
        exit 1
    fi
fi

echo "🔧 Building with DEBUG configuration (disables CGEventTap)..."

# Build with debug configuration to enable feature flags
swift build -c debug
BUILD_EXIT_CODE=$?

if [ $BUILD_EXIT_CODE -ne 0 ]; then
    echo "❌ Swift build failed"
    exit 1
fi

echo "📦 Creating app bundle..."

# Create app structure
rm -rf "Zeus_STT Dev.app"
mkdir -p "Zeus_STT Dev.app/Contents"
mkdir -p "Zeus_STT Dev.app/Contents/MacOS"
mkdir -p "Zeus_STT Dev.app/Contents/Resources"

# Copy the debug binary
cp .build/debug/STTDictate "Zeus_STT Dev.app/Contents/MacOS/"

# Copy and modify Info.plist for dev version
cp Info.plist "Zeus_STT Dev.app/Contents/"

# Update bundle ID and name for separate permissions
sed -i '' 's/com.zeus.stt/com.zeus.stt.dev/' "Zeus_STT Dev.app/Contents/Info.plist"
sed -i '' 's/<string>Zeus_STT<\/string>/<string>Zeus_STT Dev<\/string>/' "Zeus_STT Dev.app/Contents/Info.plist"

# Copy resources from production build or development paths
if [ -d "Resources" ]; then
    cp -r Resources/* "Zeus_STT Dev.app/Contents/Resources/" 2>/dev/null || true
fi

# Copy venv if it exists
if [ -d "venv" ]; then
    echo "📦 Copying Python virtual environment..."
    cp -r venv "Zeus_STT Dev.app/Contents/Resources/"
fi

# Copy AI scripts
for script in ai_editor.py ai_command_processor.py; do
    if [ -f "$script" ]; then
        cp "$script" "Zeus_STT Dev.app/Contents/Resources/"
    fi
done

# Copy dictation sounds
for sound in dictation_event1.wav dictation_event2.wav; do
    if [ -f "$sound" ]; then
        cp "$sound" "Zeus_STT Dev.app/Contents/Resources/"
    fi
done

echo "🔐 Code signing dev version..."
codesign --force --deep --sign - "Zeus_STT Dev.app" || echo "⚠️ Code signing failed (may work anyway)"

echo ""
echo "✅ Built: Zeus_STT Dev.app (DEBUG mode)"
echo ""
echo "🔧 DEV FEATURES ENABLED:"
echo "   • CGEventTap DISABLED (prevents conflicts)"
echo "   • Cmd+Shift+D keyboard shortcut for testing"
echo "   • Mock session testing: swift run STTDictate --mock-session"
echo "   • AI-only testing: swift run STTDictate --test-ai"
echo ""
echo "💡 Install: mv \"Zeus_STT Dev.app\" /Applications/"
echo "💡 Grant separate permissions in System Settings > Privacy & Security"
echo ""
echo "⚠️  IMPORTANT: Don't run dev and production apps simultaneously!"
echo "⚠️  Bundle ID: com.zeus.stt.dev (separate from production)"