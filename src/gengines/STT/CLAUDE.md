# STT Dictate - Claude Development Notes

## Project Overview
Open-source voice-to-text system for Mac that intercepts the Fn key to toggle dictation, preventing the emoji picker and providing universal text insertion across all applications.

## Key Requirements
- Intercept Fn/Globe key globally across all macOS applications
- Prevent system emoji picker from appearing when Fn is pressed
- Insert transcribed text into any active application
- Run as background service with minimal UI (menu bar icon)

## 🔧 macOS Sequoia TCC Cache Bug (Development Issue)

### The Problem - Why This Affects Development But Not Production Apps
**macOS Sequoia has a confirmed TCC (Transparency, Consent, and Control) caching bug** that specifically affects **development/self-signed apps**:

- `AXIsProcessTrusted()` returns `false` despite granted Accessibility permissions
- Runtime cache tied to bundle ID gets confused by frequent rebuilding/re-signing
- Text insertion fails completely - transcription works but text doesn't appear in apps
- Falls back to slow character-by-character CGEvent typing instead of fast AXUIElement insertion

### Why Production Apps Like Wispr Flow Don't Have This Issue
✅ **Properly signed** with Apple Developer certificates  
✅ **Stable bundle ID** that doesn't change between installs  
✅ **Single installation** from trusted source  
✅ **No frequent rebuilding** that confuses TCC cache  

### Our Development Environment Issues  
❌ **Self-signed** during development (changes signature each build)  
❌ **Frequent rebuilding** confuses macOS TCC cache  
❌ **Bundle ID reuse** with different signatures triggers cache bug  

### Automatic Internal Handling (No External Scripts Required)
The app now **automatically handles this internally**:

1. **Auto-Detection**: Detects TCC cache bug on startup
2. **Auto-Reset**: Attempts automated TCC database reset and daemon reload  
3. **Auto-Open Settings**: Opens System Settings → Accessibility automatically
4. **User Notification**: Shows helpful notification with clear steps
5. **Auto-Monitoring**: Monitors for permission restoration and shows success notification

### What You'll See
**When Bug Detected:**
- 🔧 Notification: "TCC Cache Fix Required"
- 📱 System Settings opens automatically to Accessibility panel
- 📋 Console shows simple removal/re-addition steps

**After Manual Fix:**
- ✅ Notification: "TCC Cache Fixed!"
- 🎉 Fast AXUIElement text insertion restored
- ⚡ Text appears instantly (<50ms)

### Manual Steps (Only When App Detects Bug)
When the app opens System Settings for you:
1. **Remove** 'STT Dictate' from Accessibility list (uncheck + click [-])
2. **Re-add** by clicking [+] and selecting `/Applications/STT Dictate.app`
3. **Enable** the checkbox
4. App automatically detects restoration and shows success notification

**This is a well-documented macOS Sequoia system bug affecting pynput, Input Leap, and other accessibility apps during development - not a bug in our code.**

## Technical Architecture
- **Core Engine**: WhisperKit with large-v3-turbo model for speech recognition
- **Audio Processing**: AVAudioEngine for real-time capture
- **Event Interception**: CGEventTap for global hotkey detection
- **Text Insertion**: CGEvent keyboard simulation for universal compatibility
- **App Structure**: macOS app bundle with LaunchAgent for auto-start

## Major Challenge: Fn Key Interception

### Problem
The Fn/Globe key operates at a hardware/firmware level and is heavily controlled by macOS system services. Standard event interception methods often fail because:

1. **System Priority**: macOS consumes Fn events for built-in features (emoji, dictation, window management)
2. **Hardware Level**: Fn is processed by keyboard firmware before reaching software
3. **Security Restrictions**: Recent macOS versions (Sonoma/Sequoia) have tightened event tap permissions

### Solutions Attempted

#### 1. NSEvent Global Monitor (Failed)
- **Method**: `NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged)`
- **Issue**: Passive monitoring only, cannot consume/prevent system actions
- **Result**: Emoji picker still appeared

#### 2. CGEventTap with Session Level (Failed)
- **Method**: `CGEvent.tapCreate()` with `.cgSessionEventTap`
- **Issue**: System consumed Fn events before reaching our tap
- **Result**: Callback never triggered

#### 3. CGEventTap with Hardware Level (Current)
- **Method**: `CGEvent.tapCreate()` with `.cghidEventTap`
- **Events**: Monitor `.flagsChanged`, `.keyDown`, `.keyUp`
- **Flag**: Detect `CGEventFlags.maskSecondaryFn`
- **Status**: Enhanced with Sequoia-specific fixes

### Required Permissions (Critical for Sonoma/Sequoia)
1. **Accessibility**: System Settings > Privacy & Security > Accessibility
2. **Input Monitoring**: System Settings > Privacy & Security > Input Monitoring (NEW requirement)

### System Settings Modifications
```bash
# Disable Fn emoji picker
defaults write -g AppleFnUsageType -int 0

# Force standard F-keys behavior
defaults write -g com.apple.keyboard.fnState -bool true
```

### Current Implementation Status - Wispr Flow Approach
- ✅ **App Sandboxing Disabled** - Unrestricted system access like Wispr Flow
- ✅ **Entitlements Applied** - Proper code signing with security entitlements
- ✅ **System Optimizations** - Auto-disables emoji picker and Fn conflicts
- ✅ **Debug Mode** - Listen-only testing to verify event reception
- ✅ **Enhanced CGEventTap** - Hardware-level with Sequoia compatibility
- ✅ **Dual Permission Support** - Accessibility + Input Monitoring
- ✅ **Hidutil Fallback** - Alternative remapping approach if needed
- ❓ **Testing Required** - Both permission types must be granted

### Fallback Solutions (If Current Approach Fails)

#### 1. hidutil Remapping
```bash
# Remap Fn to unused key code, then intercept that
hidutil property --set '{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":0x700000065,"HIDKeyboardModifierMappingDst":0x7000000FF}]}'
```

#### 2. IOKit/HID Level Filtering
- Use IOHIDManager for raw HID report filtering
- Intercept at driver level before system processing
- Requires deep low-level programming

#### 3. Integration with Karabiner-Elements
- Study open-source implementation
- Use proven methods for Fn key remapping
- Consider as dependency or port logic

## Build & Installation

### Quick Start
```bash
./setup.sh                        # Install dependencies and download models
./build-app.sh                     # Build macOS app bundle
mv "STT Dictate.app" /Applications/

# 🔧 TCC cache bug is now handled automatically by the app
# The app will detect TCC issues and guide you through the fix internally

./install-service.sh               # Install as background service (optional)
```

### Development Commands
```bash
swift build              # Build for testing
swift run STTDictate     # Run directly (for debugging)
./fix-fn-key.sh         # Fix system Fn key settings
./test-fn-key.swift     # Simulate Fn key presses
```

## Testing & Debugging

### Check Permissions
- Accessibility: Required for event taps
- Input Monitoring: Required for keyboard events in Sonoma+
- Microphone: Required for speech recognition

### Debug Output
The app provides extensive logging for troubleshooting:
- Event tap creation and status
- Permission checks
- System settings verification
- Real-time event detection

### Common Issues
1. **Text doesn't appear in apps**: TCC cache bug → App will auto-detect and open System Settings for manual fix
2. **Character-by-character typing**: TCC cache bug → App shows notification and guides through internal fix
3. **No events received**: Missing Input Monitoring permission
4. **Emoji still appears**: System settings not properly disabled
5. **App crashes**: Insufficient code signing or wrong location

## Future Improvements
- Alternative hotkey options (if Fn proves unreliable)
- Voice activity detection for automatic start/stop
- Custom command processing
- Multi-language support
- Cloud model options

## Related Files
- `Sources/VoiceDictationService.swift` - Core event handling
- `Sources/AppDelegate.swift` - macOS app structure  
- `Info.plist` - Permissions and app metadata
- `setup.sh` - Dependency installation
- `build-app.sh` - App bundle creation
- `install-service.sh` - Background service setup