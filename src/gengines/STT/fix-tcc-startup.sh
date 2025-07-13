#!/bin/bash

# STT Dictate TCC Cache Bug Auto-Fix Script
# Handles the macOS Sequoia TCC caching bug at startup

echo "🔧 STT Dictate TCC Cache Bug Auto-Fix"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Step 1: Kill all existing instances
echo "🔫 Step 1: Terminating existing STT Dictate instances..."
pkill -9 -f "STT Dictate" 2>/dev/null || true
pkill -9 -f "STTDictate" 2>/dev/null || true
sleep 2
echo "✅ Process cleanup complete"
echo ""

# Step 2: Reset TCC database
echo "🗃️ Step 2: Resetting TCC database..."
tccutil reset Accessibility com.stt.dictate 2>/dev/null && echo "✅ TCC database reset successful" || echo "⚠️ TCC reset not needed or failed"
echo ""

# Step 3: Reload system daemons
echo "🔄 Step 3: Reloading system daemons..."
killall cfprefsd 2>/dev/null && echo "✅ cfprefsd reloaded" || echo "⚠️ cfprefsd reload failed"
sudo killall tccd 2>/dev/null && echo "✅ tccd reloaded" || echo "⚠️ tccd reload failed (requires sudo)"
sleep 3
echo ""

# Step 4: Build and install fresh app
echo "🔨 Step 4: Building fresh STT Dictate..."
if ./build-app.sh; then
    echo "✅ Build successful"
    
    # Remove old app
    rm -rf "/Applications/STT Dictate.app" 2>/dev/null
    
    # Install new app
    if mv "STT Dictate.app" /Applications/; then
        echo "✅ Fresh app installed"
    else
        echo "❌ Failed to install app"
        exit 1
    fi
else
    echo "❌ Build failed"
    exit 1
fi
echo ""

# Step 5: Check current permission status
echo "🔍 Step 5: Checking permission status..."
if ./test-permissions.swift; then
    echo "✅ System-level permissions look good"
else
    echo "⚠️ System-level permission issues detected"
fi
echo ""

# Step 6: Launch and test
echo "🚀 Step 6: Launching STT Dictate with TCC bug detection..."
echo ""
echo "📋 What to expect:"
echo "   → Enhanced TCC cache bug detection will run"
echo "   → If bug detected: Clear instructions will be provided"
echo "   → If bug bypassed: AXUIElement should work instantly"
echo ""

# Launch the app
open "/Applications/STT Dictate.app"

echo "✅ STT Dictate launched!"
echo ""
echo "🔍 Monitor Console.app for logs:"
echo "   → Filter: 'STT' or 'process:STTDictate'"
echo "   → Look for: '🔐 Starting comprehensive TCC cache bug detection'"
echo "   → Success: '✅ AXUIElement insertion successful - bypassed TCC cache bug!'"
echo "   → Manual fix needed: '🔧 MANUAL TCC CACHE BUG FIX REQUIRED'"
echo ""
echo "💡 If manual fix is needed, follow the detailed instructions in the logs"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"