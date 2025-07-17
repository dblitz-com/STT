# RESEARCH TASK: macOS App Switching Detection Failure Analysis

## Objective
Research and identify the root cause why Zeus VLA's real-time app switching detection fails to detect Chrome when user switches from Cursor to Chrome, and provide implementable solutions for reliable cross-application detection.

## Problem Statement

**Core Issue**: App switching detection works inconsistently. When user switches from Cursor to Chrome, the system continues to report Cursor as the frontmost application, preventing real-time Glass UI updates.

**Expected Behavior**: When user switches apps (⌘+Tab or click), detection should immediately trigger:
```
🔄 APP CHANGE: Cursor → Chrome
📊 Change Details:
   From: Cursor
   To:   Chrome (confidence: 1.00)
```

**Actual Behavior**: Detection remains stuck on original app:
```
📱 Still on: Cursor
📱 Still on: Cursor  
📱 Still on: Cursor
```

## Current Implementation

### 1. App Detection Architecture (`macos_app_detector.py`)

```python
class MacOSAppDetector:
    def __init__(self):
        """Initialize with NSWorkspace and Observer pattern"""
        self.workspace = NSWorkspace.sharedWorkspace()
        self.observers = []  # Observer pattern for real-time callbacks
        
        # Register for NSWorkspace notifications
        nc = NSNotificationCenter.defaultCenter()
        nc.addObserver_selector_name_object_(
            self,
            'handleAppActivation:',
            NSWorkspaceDidActivateApplicationNotification,
            None
        )
        
    def get_frontmost_app(self) -> Optional[DetectedApp]:
        """Get currently frontmost application"""
        try:
            frontmost = self.workspace.frontmostApplication()
            if not frontmost:
                return None
                
            return DetectedApp(
                name=frontmost.localizedName() or 'Unknown',
                bundle_id=frontmost.bundleIdentifier() or 'unknown',
                confidence=1.0,
                detection_method='nsworkspace_frontmost'
            )
        except Exception as e:
            logger.error(f"❌ Error getting frontmost app: {e}")
            return None
    
    def handleAppActivation_(self, notification):
        """NSWorkspace notification handler for app activation"""
        try:
            app = notification.userInfo().get(NSWorkspaceApplicationKey)
            if app:
                new_app = DetectedApp(
                    name=app.localizedName() or 'Unknown',
                    bundle_id=app.bundleIdentifier() or 'unknown', 
                    confidence=1.0,
                    detection_method='nsworkspace_notification'
                )
                
                # Notify observers immediately via Observer pattern
                self._handle_app_transition(None, new_app, 'app_activation')
                
        except Exception as e:
            logger.error(f"❌ App activation handler failed: {e}")
    
    def _handle_app_transition(self, from_app, to_app, event_type):
        """Handle app transition and notify observers"""
        # 🚀 Notify observers for immediate Glass UI updates (Grok's Observer pattern)
        for callback in self.observers:
            try:
                callback(from_app, to_app, event_type)  # Notify service immediately
            except Exception as e:
                logger.error(f"❌ Observer callback failed: {e}")
```

### 2. Continuous Vision Integration (`continuous_vision_service.py`)

```python
class ContinuousVisionService:
    def __init__(self):
        self.app_detector = MacOSAppDetector()
        # 🚀 Register for real-time app transition callbacks (Grok's Observer pattern)
        self.app_detector.register_observer(self._on_app_transition_callback)
        self.current_app_name = None
        
    def _on_app_transition_callback(self, from_app, to_app, event_type):
        """Event-driven callback for immediate Glass UI update (Grok's Observer pattern solution)"""
        try:
            # Get app name for Glass UI update
            app_name = to_app.name if to_app else 'Unknown'
            
            # Create immediate Glass UI update with new app context
            glass_summary = f"📱 {app_name}: Screen monitoring active (app switched)"
            
            # Send immediate update to Glass UI, bypassing visual polling
            self._send_glass_ui_update("vision_summary", {
                "summary": glass_summary,
                "confidence": to_app.confidence if to_app else 0.0
            })
            
            logger.debug(f"🚀 Immediate Glass UI update: {event_type} → {app_name} (<100ms latency)")
        except Exception as e:
            logger.error(f"❌ App transition UI update failed: {e}")
    
    def _check_app_change_and_notify(self):
        """Polling-based fallback when NSWorkspace notifications fail"""
        try:
            # Get current frontmost app
            current_app = self.app_detector.get_frontmost_app()
            if not current_app:
                return
                
            current_app_name = current_app.name
            
            # Check if app changed
            if self.current_app_name != current_app_name:
                # Create mock previous app for callback signature compatibility
                class MockApp:
                    def __init__(self, name):
                        self.name = name
                        self.confidence = 1.0
                
                previous_app = MockApp(self.current_app_name) if self.current_app_name else None
                
                # Trigger immediate Observer pattern callback
                self._on_app_transition_callback(previous_app, current_app, 'polling_detected')
                
                logger.info(f"🔄 App change detected: {self.current_app_name} → {current_app_name}")
                
                # Update stored app name
                self.current_app_name = current_app_name
        except Exception as e:
            logger.debug(f"App change detection failed: {e}")
```

## Technical Analysis & Test Results

### 1. Current System State (Verified Working)

**Test Command**: `python3 test_app_switching.py state`

**Output**:
```
================================================================================
📱 CURRENT APP STATE
================================================================================
🎯 Frontmost (Detector):    Cursor (com.todesktop.230313mzl4w4u92)
🎯 Frontmost (NSWorkspace): Cursor (com.todesktop.230313mzl4w4u92)

📋 All Apps (13):
  • Cursor                    com.todesktop.230313mzl4w4u92       PID:74295  [ACTIVE, FRONTMOST]
  • Google Chrome             com.google.Chrome                   PID:638   
  • Terminal                  com.apple.Terminal                  PID:78370 
```

**Analysis**: 
- ✅ NSWorkspace API is functional and correctly reports Cursor as frontmost
- ✅ Chrome is visible in running apps list
- ✅ App detection logic works for current state

### 2. Observer Pattern Implementation (Correctly Implemented)

**Based on Grok's comprehensive analysis**, the Observer pattern was implemented exactly as specified:

```python
# Subject: MacOSAppDetector
class MacOSAppDetector:
    def register_observer(self, callback):
        """Register callback function for real-time app transition events"""
        self.observers.append(callback)
        
# Observer: ContinuousVisionService  
class ContinuousVisionService:
    def __init__(self):
        self.app_detector.register_observer(self._on_app_transition_callback)
```

**Status**: ✅ Observer pattern correctly implemented and functional

### 3. NSWorkspace Notifications (FAILING)

**Issue**: `NSWorkspaceDidActivateApplicationNotification` events are not firing when user switches apps.

**Evidence**: When user switches Cursor→Chrome, `handleAppActivation_` method is never called.

**Potential Causes to Research**:
1. **Threading Issues**: PyObjC NSNotificationCenter registration in wrong thread
2. **Activation Policy**: Chrome may not trigger activation notifications  
3. **Focus vs Activation**: macOS distinguishes between focus and activation
4. **Sandboxing**: Application sandboxing may block cross-app notifications
5. **PyObjC Compatibility**: Version compatibility with macOS Sonoma 14.5.0

### 4. Polling Fallback (FAILING)

**Implementation**: 600ms polling calls `get_frontmost_app()` via `NSWorkspace.frontmostApplication()`

**Issue**: Even with polling, `frontmostApplication()` continues returning Cursor when user is actually in Chrome.

**Evidence**: 
```python
# This call returns Cursor even when Chrome is visually frontmost
frontmost = self.workspace.frontmostApplication() 
```

**Critical Question**: Why does `NSWorkspace.frontmostApplication()` return stale data?

## System Environment

- **macOS**: Darwin 24.5.0 (macOS Sonoma)
- **Python**: 3.12+ with PyObjC
- **Apps**: Cursor (Electron), Chrome (Native)  
- **Architecture**: x86_64/arm64 (need to verify)

## Previous Solutions Attempted

### 1. ✅ Grok's Observer Pattern
- **Status**: Implemented and functional
- **Result**: Observer callbacks work, but underlying detection fails

### 2. ✅ Polling-Based Detection  
- **Status**: Implemented as fallback
- **Result**: Same issue - `frontmostApplication()` returns wrong app

### 3. ❌ NSWorkspace Notifications
- **Status**: Registered but not firing
- **Result**: Events never trigger on app switches

## Research Questions

### Primary Questions
1. **Why does `NSWorkspace.frontmostApplication()` return stale data?**
   - Is this a PyObjC threading issue?
   - Does macOS cache frontmost app state?
   - Are there timing/synchronization issues?

2. **Why don't NSWorkspace notifications fire on app switches?**
   - Threading requirements for NSNotificationCenter?
   - Alternative notification types to register for?
   - PyObjC registration syntax issues?

### Alternative Approaches to Research
1. **CGWindowListCopyWindowInfo**: Direct window-level detection
2. **Accessibility APIs**: AXUIElementCopyElementAtPosition  
3. **Process-based detection**: Activity Monitor approach
4. **Quartz Event Services**: Low-level event monitoring
5. **Swift-based detection**: Replace Python with Swift

## Code Snippets for Testing

### Test Script Structure
```python
# Current test approach - needs automation
python3 test_app_switching.py state    # Show current state
python3 test_app_switching.py monitor  # Real-time monitoring (hangs)
```

### Missing: Automated App Switching
```python
# NEEDED: AppleScript/pyautogui automation to:
# 1. Switch to Chrome programmatically  
# 2. Verify detection response
# 3. Switch back to Cursor
# 4. Measure detection latency
```

## Expected Research Deliverables

### 1. Root Cause Analysis
- Detailed explanation of why `NSWorkspace.frontmostApplication()` fails
- Technical analysis of PyObjC/NSWorkspace interaction
- Identification of macOS API limitations or bugs

### 2. Alternative Detection Methods
- Research into CGWindowListCopyWindowInfo approach
- Analysis of Accessibility API alternatives  
- Evaluation of Swift vs Python implementation

### 3. Implementable Solution
- Working code that reliably detects app switches
- Performance benchmarks (<100ms latency target)
- Compatibility across different app types (Electron, Native, Web)

### 4. Test Automation
- Automated test script that programmatically switches apps
- Verification that detection works reliably across multiple cycles
- Performance metrics and reliability statistics

## Success Criteria

**Primary**: App switching detection works reliably with <100ms latency
**Secondary**: Glass UI updates immediately on app switch  
**Tertiary**: Solution works across all macOS app types

## Technical Context Files

- `macos_app_detector.py` - Core detection logic
- `continuous_vision_service.py` - Integration layer  
- `test_app_switching.py` - Manual testing script
- `zeus_launcher.py` - Service orchestration

## Priority: HIGH
This blocks real-time Glass UI functionality - core Zeus VLA feature.