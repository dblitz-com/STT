#!/bin/bash

# Kill any existing STT Dictate instances
echo "🔫 Killing any existing STT Dictate instances..."
pkill -f "STT Dictate" || true
sleep 0.5

# Launch STT Dictate
echo "🚀 Launching STT Dictate..."
open "/Applications/STT Dictate.app"