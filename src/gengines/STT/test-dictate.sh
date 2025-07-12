#!/bin/bash

echo "🎤 Starting STT Dictation Test"
echo "=============================="
echo ""
echo "Building the project..."
swift build

echo ""
echo "Running STTDictate..."
echo "Press Fn key to toggle recording"
echo "Press Ctrl+C to quit"
echo ""

# Run with unbuffered output
./.build/debug/STTDictate