#!/bin/bash

# Quick Dev Build - creates "STT Dictate Dev.app" alongside production
echo "🔨 Building dev version..."

./build-app.sh

# Just rename the output
mv "STT Dictate.app" "STT Dictate Dev.app"

# Update bundle ID in Info.plist so both can run together
sed -i '' 's/com.stt.dictate/com.stt.dictate.dev/' "STT Dictate Dev.app/Contents/Info.plist"
sed -i '' 's/<string>STT Dictate<\/string>/<string>STT Dictate Dev<\/string>/' "STT Dictate Dev.app/Contents/Info.plist"

echo "✅ Built: STT Dictate Dev.app"
echo "💡 Install: mv \"STT Dictate Dev.app\" /Applications/"