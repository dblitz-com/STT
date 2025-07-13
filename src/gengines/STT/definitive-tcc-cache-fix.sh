#!/bin/bash
# STT Dictate - Definitive TCC Cache Bug Fix for macOS Sequoia
# Comprehensive solution for cached permission denial affecting rebuilt/self-signed apps
# Based on successful fixes for pynput, Input Leap, and other accessibility apps

set -e

echo "🔧 STT Dictate - Definitive TCC Cache Bug Fix"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 This script resolves the macOS Sequoia TCC caching bug where:"
echo "   • AXIsProcessTrusted() returns false despite granted permissions"
echo "   • Runtime cache tied to bundle ID survives resets and restarts"
echo "   • Affects rebuilt/self-signed apps with LSUIElement=true"
echo ""
echo "⚠️  WARNING: This will:"
echo "   • Kill all STT Dictate processes"
echo "   • Reset system daemons (cfprefsd, tccd)"
echo "   • Remove and re-add accessibility permissions"
echo "   • Require manual re-authorization"
echo ""
read -p "Continue with definitive TCC cache fix? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Aborted by user"
    exit 1
fi

echo ""
echo "🎯 STEP 1: Kill All Processes and Daemons"
echo "────────────────────────────────────────────"

echo "🔫 Killing all STT Dictate processes..."
pkill -9 -f "STT Dictate" 2>/dev/null || echo "   No STT Dictate processes found"
pkill -9 -f "STTDictate" 2>/dev/null || echo "   No STTDictate processes found"

echo "🔄 Killing system daemons to force cache reload..."
sudo killall cfprefsd 2>/dev/null || echo "   cfprefsd already stopped"
sudo killall tccd 2>/dev/null || echo "   tccd already stopped"

echo "⏳ Waiting for daemon restart..."
sleep 5

echo "✅ All processes and daemons killed"
echo ""

echo "🎯 STEP 2: Reset TCC Database"
echo "────────────────────────────────────────"

echo "🗃️ Resetting TCC database for com.stt.dictate..."
tccutil reset Accessibility com.stt.dictate 2>/dev/null && echo "✅ TCC database reset successful" || echo "⚠️  No TCC entry found (already clear)"

echo ""

echo "🎯 STEP 3: Manual Removal in System Settings"
echo "─────────────────────────────────────────────"

echo "📱 Opening System Settings to Accessibility panel..."
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"

echo ""
echo "👆 MANUAL ACTION REQUIRED:"
echo "   1. Find 'STT Dictate' in the Accessibility list"
echo "   2. If found: Uncheck the box, then click the '-' button to remove"
echo "   3. Confirm removal when prompted"
echo "   4. If not found in the list, continue to next step"
echo ""
read -p "Press ENTER when removal is complete (or if not found): "

echo ""
echo "🎯 STEP 4: Re-Add the App Manually"
echo "──────────────────────────────────────"

echo "👆 MANUAL ACTION REQUIRED:"
echo "   1. In the same Accessibility panel, click the '+' button"
echo "   2. Navigate to /Applications/STT Dictate.app"
echo "   3. Select and add the app"
echo "   4. Check the checkbox to enable it"
echo "   5. Confirm any prompts that appear"
echo ""
echo "💡 This re-registers the bundle ID fresh, bypassing the cache"
echo ""
read -p "Press ENTER when re-addition is complete: "

echo ""
echo "🎯 STEP 5: Relaunch and Test"
echo "────────────────────────────"

echo "🚀 Launching STT Dictate from Applications folder..."
if [ -f "/Applications/STT Dictate.app/Contents/MacOS/STTDictate" ]; then
    open "/Applications/STT Dictate.app"
    echo "✅ STT Dictate launched"
else
    echo "❌ STT Dictate.app not found in /Applications/"
    echo "   Please build and install the app first with: ./build-app.sh"
    exit 1
fi

echo ""
echo "🔍 TESTING INSTRUCTIONS:"
echo "────────────────────────"
echo "1. Wait for the app to fully load (🎤 icon in menu bar)"
echo "2. Open Console.app and filter for 'STT' or 'STTDictate'"
echo "3. Press Fn key to trigger dictation"
echo "4. Speak some text and press Fn again to stop"
echo ""
echo "✅ SUCCESS INDICATORS:"
echo "   • Logs show: '🔐 Starting comprehensive TCC cache bug detection'"
echo "   • Logs show: '✅ Accessibility granted' (no bug detected)"
echo "   • Logs show: '🆕 ATTEMPTING AXUIElement text insertion method'"
echo "   • Logs show: '✅ Text inserted successfully at cursor position'"
echo "   • Text appears instantly (<50ms, no character-by-character typing)"
echo ""
echo "❌ FAILURE INDICATORS:"
echo "   • Logs show: '🐛 DETECTED: macOS Sequoia TCC caching bug'"
echo "   • Logs show: '❌ ACCESSIBILITY DENIED (cached)'"
echo "   • Logs show: '⚠️ Using fallback CGEvent method'"
echo "   • Text appears character-by-character (slow typing)"
echo ""
echo "🔧 IF STILL FAILING:"
echo "   1. Delete ~/Library/Preferences/com.stt.dictate.plist"
echo "   2. Reboot the system"
echo "   3. Run this script again"
echo "   4. As last resort: Disable SIP temporarily, clear /var/db/tcc/"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Definitive TCC cache fix complete!"
echo "📊 Monitor logs in Console.app to verify fast AXUIElement insertion"
echo "🎯 This should restore <50ms text insertion as in commit 7353cf3"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"