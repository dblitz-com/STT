#!/bin/bash

echo "🔧 Fixing Fn key system setting for STT Dictate"
echo "==============================================="

# Check current setting
current=$(defaults read -g AppleFnUsageType 2>/dev/null || echo "1")
echo "Current Fn key setting: $current"
echo "  0 = Do Nothing"
echo "  1 = Show Emoji & Symbols (default)"

if [ "$current" -eq 0 ]; then
    echo "✅ Fn key is already set to 'Do Nothing' - good for STT interception"
else
    echo "⚠️  Fn key is set to 'Show Emoji & Symbols' - this conflicts with STT"
    echo ""
    echo "Fixing this by setting Fn key to 'Do Nothing'..."
    defaults write -g AppleFnUsageType -int 0
    echo "✅ Fixed! Fn key is now set to 'Do Nothing'"
    echo ""
    echo "⚠️  You may need to restart STT Dictate for this to take effect"
    echo "   Run: killall STTDictate && open '/Applications/STT Dictate.app'"
fi

echo ""
echo "To verify this setting in System Settings:"
echo "  Go to: System Settings > Keyboard > Press Fn/Globe Key to: 'Do Nothing'"