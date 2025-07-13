# STT Dictate - Claude Development Notes

## Project Overview
Open-source voice-to-text system for Mac that intercepts the Fn key to toggle dictation, preventing the emoji picker and providing universal text insertion across all applications.

## Key Requirements
- Intercept Fn/Globe key globally across all macOS applications
- Prevent system emoji picker from appearing when Fn is pressed
- Insert transcribed text into any active application
- Run as background service with minimal UI (menu bar icon)

## 🚨 CRITICAL: macOS Sequoia TCC Cache Bug Fix (REQUIRED)

### The Problem
**macOS Sequoia has a confirmed TCC (Transparency, Consent, and Control) caching bug** that affects rebuilt/self-signed apps with `LSUIElement=true`. This causes:

- `AXIsProcessTrusted()` returns `false` despite granted Accessibility permissions
- Runtime cache tied to bundle ID survives resets, reboots, and process kills
- Text insertion fails completely - transcription works but text doesn't appear in apps
- Falls back to slow character-by-character CGEvent typing instead of fast AXUIElement insertion

### The Solution (MANDATORY AFTER EACH BUILD)
**Every time you build the app, you MUST run the definitive TCC cache fix:**

```bash
./definitive-tcc-cache-fix.sh
```

This script performs the **only known working solution** for the Sequoia TCC cache bug:

1. **Kill Processes**: Terminates all STT Dictate instances and system daemons
2. **Reset TCC Database**: Clears cached permission denials for com.stt.dictate
3. **Manual Removal**: Opens System Settings → Accessibility for manual app removal
4. **Manual Re-Addition**: User manually re-adds `/Applications/STT Dictate.app` 
5. **Fresh Registration**: Bypasses cache by registering bundle ID fresh

### Success Indicators
After running the fix, you should see:
- ✅ **Fast Text Insertion**: Text appears instantly (<50ms, no character-by-character typing)
- ✅ **Log Shows**: `🆕 ATTEMPTING AXUIElement text insertion method`
- ✅ **Log Shows**: `✅ Text inserted successfully at cursor position`
- ✅ **No Bug Detection**: `✅ Accessibility granted` (no TCC cache bug detected)

### Failure Indicators (Fix Required)
If you see these, run `./definitive-tcc-cache-fix.sh`:
- ❌ **Slow Typing**: Character-by-character text insertion
- ❌ **Log Shows**: `🐛 DETECTED: macOS Sequoia TCC caching bug`
- ❌ **Log Shows**: `⚠️ Using fallback CGEvent method`
- ❌ **Log Shows**: `❌ ACCESSIBILITY DENIED (cached)`

### Automated Detection
The app now automatically detects this bug on startup with enhanced logging:
```swift
// Sources/VoiceDictationService.swift:initializeAfterLaunch()
checkAccessibilityPermissions() // Runs comprehensive TCC cache bug detection
```

**This TCC cache bug fix is documented as affecting pynput, Input Leap, and other accessibility apps on Sequoia. It's a known system issue, not our bug.**

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

# 🚨 CRITICAL: Run TCC cache fix after EVERY build (Sequoia bug)
./definitive-tcc-cache-fix.sh      # Fix macOS Sequoia TCC caching bug

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
1. **Text doesn't appear in apps**: macOS Sequoia TCC cache bug → Run `./definitive-tcc-cache-fix.sh`
2. **Character-by-character typing**: TCC cache bug causing AXUIElement failure → Run fix script
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