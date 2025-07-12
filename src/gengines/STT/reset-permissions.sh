#!/bin/bash

echo "🔄 Resetting TCC Permissions (Research Agent Fix)"
echo "==============================================="

# Get the bundle ID
BUNDLE_ID="com.stt.dictate"

echo "Resetting permissions for bundle ID: $BUNDLE_ID"

# Reset Accessibility permissions
echo "🔄 Resetting Accessibility permissions..."
tccutil reset Accessibility $BUNDLE_ID 2>/dev/null || echo "   (May have already been reset)"

# Reset Input Monitoring permissions  
echo "🔄 Resetting Input Monitoring permissions..."
tccutil reset InputMonitoring $BUNDLE_ID 2>/dev/null || echo "   (May have already been reset)"

echo ""
echo "✅ Permissions reset complete!"
echo ""
echo "Next steps:"
echo "1. Rebuild and reinstall the app: ./build-app.sh"
echo "2. Re-grant permissions in System Settings:"
echo "   - Privacy & Security > Accessibility > Enable STT Dictate"
echo "   - Privacy & Security > Input Monitoring > Add STTDictate executable"
echo "3. Test with fresh permissions"