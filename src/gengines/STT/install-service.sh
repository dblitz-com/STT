#!/bin/bash

set -e

PLIST_NAME="com.stt.dictate"
PLIST_FILE="${PLIST_NAME}.plist"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
SERVICE_PATH="${LAUNCH_AGENTS_DIR}/${PLIST_FILE}"

echo "🚀 Installing STT Dictation Service"
echo "==================================="

# Check if app is installed
if [ ! -d "/Applications/STT Dictate.app" ]; then
    echo "❌ STT Dictate.app not found in /Applications/"
    echo "Please run ./build-app.sh first and move the app to /Applications/"
    exit 1
fi

# Check if service is already installed
if launchctl list | grep -q "${PLIST_NAME}"; then
    echo "⚠️  Service already running. Stopping..."
    launchctl unload "${SERVICE_PATH}" 2>/dev/null || true
fi

# Create LaunchAgents directory if it doesn't exist
mkdir -p "${LAUNCH_AGENTS_DIR}"

# Copy plist to LaunchAgents
cp "${PLIST_FILE}" "${SERVICE_PATH}"

# Load the service
launchctl load "${SERVICE_PATH}"

echo "✅ Service installed successfully!"
echo ""
echo "The STT dictation service is now running in the background."
echo "• Press Fn key to toggle dictation"
echo "• Check logs at: /tmp/stt-dictate.log"
echo "• Check errors at: /tmp/stt-dictate.err"
echo ""
echo "To uninstall, run:"
echo "  launchctl unload ~/Library/LaunchAgents/${PLIST_FILE}"
echo "  rm ~/Library/LaunchAgents/${PLIST_FILE}"