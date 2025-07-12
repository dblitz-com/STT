# STT Quick Start Guide

## 1. Initial Setup (5 minutes)

```bash
# Clone and enter the directory
cd /path/to/STT

# Run the setup script
./setup.sh
```

This will:
- Install required dependencies (Homebrew, Swift tools)
- Clone WhisperKit
- Download the Whisper large-v3-turbo model (~1.5GB)

## 2. Test the Dictation

```bash
# Build and run the dictation service
swift run STTDictate
```

- Press `Fn` key to start/stop dictation
- Speak into your microphone
- Text will appear wherever your cursor is
- Press `Ctrl+C` to quit

## 3. Install as Background Service (Optional)

```bash
# Install as a system service that starts on login
./install-service.sh
```

The service will now run automatically in the background.

## Voice Commands

Say these phrases to insert special characters:
- "new line" → Enter key
- "period" → .
- "comma" → ,
- "question mark" → ?
- "new paragraph" → Double enter

## Troubleshooting

1. **Permission Issues**: Grant microphone and accessibility permissions when prompted
2. **No Audio**: Check System Preferences → Security & Privacy → Microphone
3. **Logs**: Check `/tmp/stt-dictate.log` and `/tmp/stt-dictate.err`

## Uninstall

```bash
launchctl unload ~/Library/LaunchAgents/com.stt.dictate.plist
rm ~/Library/LaunchAgents/com.stt.dictate.plist
```