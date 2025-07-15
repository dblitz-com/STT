#!/bin/bash

echo "🔍 Diagnosing Zeus_STT Dev logging issues"
echo "========================================"

# Get app PID
PID=$(pgrep -f "Zeus_STT Dev.app")
if [ -z "$PID" ]; then
    echo "❌ App not running!"
    exit 1
fi

echo "✅ App running with PID: $PID"

# Test 1: Check if app is linked with logging libraries
echo -e "\n1. Checking app binary for logging symbols..."
if otool -L "/Applications/Zeus_STT Dev.app/Contents/MacOS/STTDictate" | grep -q "log"; then
    echo "✅ App linked with logging libraries"
else
    echo "⚠️  No explicit log library linkage found"
fi

# Test 2: Check if NSLog symbols are present
echo -e "\n2. Checking for NSLog symbols..."
if nm "/Applications/Zeus_STT Dev.app/Contents/MacOS/STTDictate" | grep -q "NSLog"; then
    echo "✅ NSLog symbols found in binary"
else
    echo "❌ NSLog symbols NOT found - might be stripped or optimized out"
fi

# Test 3: Try different log commands
echo -e "\n3. Trying different log viewing methods..."

echo -e "\nMethod A: Using log show with process name"
log show --last 30s --process STTDictate 2>/dev/null | grep -E "Phase|VAD|wake" | tail -5

echo -e "\nMethod B: Using log stream (run for 5 seconds)..."
timeout 5 log stream --process STTDictate 2>/dev/null | grep -E "Phase|VAD|wake" &

echo -e "\nMethod C: Check stderr output"
echo "Run this command in another terminal:"
echo "sudo dtrace -p $PID -n 'syscall::write*:entry /arg0 == 2/ { printf(\"%s\", copyinstr(arg1)); }'"

echo -e "\n4. Alternative: Force a log message via lldb"
echo "Run this command:"
echo "lldb -p $PID"
echo "Then in lldb:"
echo "(lldb) expr (void)NSLog(@\"TEST: This is a forced log message\")"
echo "(lldb) c"
echo "(lldb) quit"

echo -e "\n5. Check Console.app settings:"
echo "   - Open Console.app"
echo "   - Action menu > Include Info Messages ✓"
echo "   - Action menu > Include Debug Messages ✓"
echo "   - Search for: STTDictate"

echo -e "\n💡 MOST LIKELY ISSUE:"
echo "In DEBUG builds, NSLog might be redirected to stderr instead of system log."
echo "The app is probably logging, just not where we're looking!"