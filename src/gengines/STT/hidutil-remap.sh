#!/bin/bash

echo "🔧 Applying hidutil Fn key remapping (Wispr Flow fallback)"
echo "======================================================="

# Remap Fn key to unused key code, then intercept that
echo "Remapping Fn key to custom code..."
hidutil property --set '{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":0x700000065,"HIDKeyboardModifierMappingDst":0x7000000FF}]}'

echo "✅ Fn key remapped - restart STT Dictate to use new mapping"
echo ""
echo "To undo: hidutil property --set '{\"UserKeyMapping\":[]}'"