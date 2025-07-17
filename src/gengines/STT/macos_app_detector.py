#!/usr/bin/env python3
"""
MacOSAppDetector - Fix #2: Accurate App Detection for PILLAR 1
Uses macOS APIs instead of keyword matching to achieve >90% accuracy

Key Improvements:
- PyObjC integration for native macOS APIs
- Real-time process monitoring with minimal CPU overhead
- Window hierarchy detection for multi-window apps
- App state tracking (active, background, hidden)
- Bundle ID resolution for accurate app identification

Target: Improve from 60% keyword matching to >90% native API accuracy
"""

import time
import threading
from typing import Dict, Any, Optional, List, Tuple
from dataclasses import dataclass
from datetime import datetime, timedelta
from collections import deque
import structlog

# macOS APIs via PyObjC
try:
    from AppKit import (
        NSWorkspace, 
        NSRunningApplication, 
        NSApplicationActivationPolicyRegular
    )
    # These constants might not be available in all PyObjC versions
    try:
        from AppKit import NSApplicationActivationPolicyAccessory
    except ImportError:
        NSApplicationActivationPolicyAccessory = 1
    try:
        from AppKit import NSApplicationActivationPolicyUIElement
    except ImportError:
        NSApplicationActivationPolicyUIElement = 2
    from Cocoa import (
        NSNotificationCenter,
        NSWorkspaceDidActivateApplicationNotification,
        NSWorkspaceDidDeactivateApplicationNotification,
        NSWorkspaceDidLaunchApplicationNotification,
        NSWorkspaceDidTerminateApplicationNotification
    )
    from Quartz import (
        CGWindowListCopyWindowInfo,
        kCGWindowListOptionOnScreenOnly,
        kCGWindowListExcludeDesktopElements,
        kCGNullWindowID
    )
    PYOBJC_AVAILABLE = True
except ImportError:
    PYOBJC_AVAILABLE = False

logger = structlog.get_logger()

@dataclass
class AppInfo:
    """Detected application information"""
    bundle_id: str
    name: str
    pid: int
    is_active: bool
    is_frontmost: bool
    window_count: int
    launch_time: datetime
    activation_policy: str
    confidence: float = 1.0

@dataclass
class WindowInfo:
    """Window information from Quartz"""
    window_id: int
    owner_pid: int
    owner_name: str
    window_name: str
    layer: int
    bounds: Dict[str, float]
    is_onscreen: bool
    confidence: float = 1.0

@dataclass
class AppTransition:
    """Application transition event"""
    timestamp: datetime
    event_type: str  # 'activate', 'deactivate', 'launch', 'terminate'
    from_app: Optional[str]
    to_app: Optional[str]
    bundle_id: str
    confidence: float

class MacOSAppDetector:
    """
    High-accuracy macOS app detection using native APIs
    
    Features:
    1. Real-time app monitoring via NSWorkspace notifications
    2. Window hierarchy detection with Quartz APIs
    3. Bundle ID resolution for accurate identification
    4. Process state tracking with minimal overhead
    5. App transition event detection
    """
    
    def __init__(self):
        if not PYOBJC_AVAILABLE:
            raise ImportError("PyObjC not available - install with: pip install pyobjc")
        
        self.workspace = NSWorkspace.sharedWorkspace()
        self.notification_center = NSNotificationCenter.defaultCenter()
        
        # App tracking state
        self.current_app = None
        self.app_history = deque(maxlen=100)
        self.running_apps = {}  # pid -> AppInfo
        self.window_cache = {}  # window_id -> WindowInfo
        self.transition_history = deque(maxlen=50)
        
        # Performance monitoring
        self.detection_accuracy = 0.0
        self.false_positives = 0
        self.total_detections = 0
        self.last_update = time.time()
        
        # Background monitoring
        self.monitoring_thread = None
        self.is_monitoring = False
        
        # 🚀 CGWindowList polling thread for real-time detection (Grok's solution)
        self.polling_thread = None
        self.is_polling = False
        self.poll_interval = 0.05  # 50ms = <100ms latency target
        
        # 🚀 Observer pattern for real-time app transition callbacks (Grok's solution)
        self.observers = []  # List of callback functions for immediate Glass UI updates
        
        # Register for app notifications
        self._register_notifications()
        
        # Initialize with current state
        self._refresh_running_apps()
        
        # 🚀 Start CGWindowList polling for real-time detection (Grok's solution)
        self.start_polling()
        
        logger.info("✅ MacOSAppDetector initialized with CGWindowList polling + Observer pattern")
    
    def register_observer(self, callback):
        """Register callback function for real-time app transition events (Grok's Observer pattern)"""
        self.observers.append(callback)
        logger.debug(f"🔄 Registered observer callback: {callback.__name__ if hasattr(callback, '__name__') else 'anonymous'}")
    
    def _register_notifications(self):
        """Register for NSWorkspace notifications"""
        try:
            # App activation/deactivation
            self.notification_center.addObserver_selector_name_object_(
                self, 
                "handleAppActivation:", 
                NSWorkspaceDidActivateApplicationNotification, 
                None
            )
            
            self.notification_center.addObserver_selector_name_object_(
                self, 
                "handleAppDeactivation:", 
                NSWorkspaceDidDeactivateApplicationNotification, 
                None
            )
            
            # App launch/termination
            self.notification_center.addObserver_selector_name_object_(
                self, 
                "handleAppLaunch:", 
                NSWorkspaceDidLaunchApplicationNotification, 
                None
            )
            
            self.notification_center.addObserver_selector_name_object_(
                self, 
                "handleAppTermination:", 
                NSWorkspaceDidTerminateApplicationNotification, 
                None
            )
            
            logger.info("✅ Registered for NSWorkspace notifications")
            
        except Exception as e:
            logger.error(f"❌ Notification registration failed: {e}")
    
    def get_frontmost_app(self) -> Optional[AppInfo]:
        """Get currently frontmost application using CGWindowList (Grok's solution)"""
        try:
            # 🚀 Use CGWindowListCopyWindowInfo instead of NSWorkspace (fixes stale data issue)
            windows = CGWindowListCopyWindowInfo(
                kCGWindowListOptionOnScreenOnly, 
                kCGNullWindowID
            )
            
            if not windows:
                return None
            
            # Find frontmost window (layer 0, on screen)
            frontmost_window = None
            for window in windows:
                layer = window.get('kCGWindowLayer', 1)
                is_onscreen = window.get('kCGWindowIsOnscreen', False)
                
                if layer == 0 and is_onscreen:
                    frontmost_window = window
                    break
            
            if not frontmost_window:
                return None
            
            # Get app from frontmost window's owner PID
            owner_pid = frontmost_window.get('kCGWindowOwnerPID', 0)
            if not owner_pid:
                return None
            
            # Convert PID to NSRunningApplication
            frontmost_app = NSRunningApplication.runningApplicationWithProcessIdentifier_(owner_pid)
            if not frontmost_app:
                return None
            
            # Get detailed app info  
            app_info = self._extract_app_info(frontmost_app)
            
            # Update current app tracking
            if not self.current_app or self.current_app.bundle_id != app_info.bundle_id:
                self._handle_app_transition(self.current_app, app_info, 'cgwindow_frontmost')
                self.current_app = app_info
            
            # Update detection accuracy
            self.total_detections += 1
            self._update_accuracy_metrics(app_info)
            
            return app_info
            
        except Exception as e:
            logger.error(f"❌ Frontmost app detection failed: {e}")
            return None
    
    def start_polling(self):
        """Start CGWindowList polling thread for real-time app detection (Grok's solution)"""
        if self.is_polling:
            return
            
        self.is_polling = True
        self.polling_thread = threading.Thread(target=self._poll_frontmost, daemon=True)
        self.polling_thread.start()
        logger.info("🚀 Started CGWindowList polling for real-time app detection")
    
    def stop_polling(self):
        """Stop polling thread"""
        self.is_polling = False
        if self.polling_thread:
            self.polling_thread.join(timeout=1.0)
        logger.info("🛑 Stopped CGWindowList polling")
    
    def _poll_frontmost(self):
        """Poll frontmost app using CGWindowList (Grok's solution - 50ms interval)"""
        while self.is_polling:
            try:
                # Use the new CGWindowList-based detection
                current_app = self.get_frontmost_app()
                
                # Observer pattern will handle notifications in get_frontmost_app
                # No additional processing needed here
                
            except Exception as e:
                logger.debug(f"Poll error: {e}")
            
            time.sleep(self.poll_interval)  # 50ms polling = <100ms latency
    
    def _extract_app_info(self, ns_app: NSRunningApplication) -> AppInfo:
        """Extract detailed app information from NSRunningApplication"""
        try:
            bundle_id = ns_app.bundleIdentifier() or "unknown"
            name = ns_app.localizedName() or ns_app.bundleIdentifier() or "Unknown"
            pid = ns_app.processIdentifier()
            is_active = ns_app.isActive()
            is_frontmost = ns_app.isActive()  # Frontmost apps are always active
            
            # Get activation policy
            policy = ns_app.activationPolicy()
            policy_name = self._get_policy_name(policy)
            
            # Get window count
            window_count = self._get_window_count(pid)
            
            # Get launch time (if available)
            launch_date = ns_app.launchDate()
            if launch_date:
                launch_time = datetime.now() - timedelta(seconds=time.time() - launch_date.timeIntervalSince1970())
            else:
                launch_time = datetime.now()  # Default to now if not available
            
            return AppInfo(
                bundle_id=bundle_id,
                name=name,
                pid=pid,
                is_active=is_active,
                is_frontmost=is_frontmost,
                window_count=window_count,
                launch_time=launch_time,
                activation_policy=policy_name,
                confidence=self._calculate_app_confidence(bundle_id, name, pid)
            )
            
        except Exception as e:
            logger.error(f"❌ App info extraction failed: {e}")
            return AppInfo(
                bundle_id="unknown",
                name="Unknown",
                pid=0,
                is_active=False,
                is_frontmost=False,
                window_count=0,
                launch_time=datetime.now(),
                activation_policy="unknown",
                confidence=0.0
            )
    
    def _get_policy_name(self, policy: int) -> str:
        """Convert activation policy to readable name"""
        policy_map = {
            NSApplicationActivationPolicyRegular: "regular",
            NSApplicationActivationPolicyAccessory: "accessory", 
            NSApplicationActivationPolicyUIElement: "ui_element"
        }
        return policy_map.get(policy, "unknown")
    
    def _get_window_count(self, pid: int) -> int:
        """Get window count for application using Quartz APIs"""
        try:
            # Get window list
            window_list = CGWindowListCopyWindowInfo(
                kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements,
                kCGNullWindowID
            )
            
            if not window_list:
                return 0
            
            # Count windows for this PID
            window_count = 0
            for window in window_list:
                if window.get('kCGWindowOwnerPID') == pid:
                    window_count += 1
            
            return window_count
            
        except Exception as e:
            logger.error(f"❌ Window count detection failed: {e}")
            return 0
    
    def _calculate_app_confidence(self, bundle_id: str, name: str, pid: int) -> float:
        """Calculate confidence score for app detection"""
        try:
            confidence = 0.5  # Base confidence
            
            # Bundle ID presence increases confidence
            if bundle_id and bundle_id != "unknown":
                confidence += 0.3
            
            # Valid PID increases confidence
            if pid > 0:
                confidence += 0.2
            
            # Name presence increases confidence
            if name and name != "Unknown":
                confidence += 0.1
            
            # Known app patterns increase confidence
            if self._is_known_app(bundle_id, name):
                confidence += 0.1
            
            return min(1.0, confidence)
            
        except Exception as e:
            logger.error(f"❌ Confidence calculation failed: {e}")
            return 0.5
    
    def _is_known_app(self, bundle_id: str, name: str) -> bool:
        """Check if app is in known applications database"""
        known_bundles = {
            'com.apple.finder': 'Finder',
            'com.apple.Terminal': 'Terminal',
            'com.microsoft.VSCode': 'Visual Studio Code',
            'com.google.Chrome': 'Google Chrome',
            'com.apple.Safari': 'Safari',
            'com.tinyspeck.slackmacgap': 'Slack',
            'us.zoom.xos': 'Zoom',
            'com.apple.mail': 'Mail',
            'com.apple.dt.Xcode': 'Xcode'
        }
        
        return bundle_id in known_bundles or name in known_bundles.values()
    
    def get_running_apps(self) -> List[AppInfo]:
        """Get all running applications"""
        try:
            running_apps = self.workspace.runningApplications()
            app_list = []
            
            for ns_app in running_apps:
                app_info = self._extract_app_info(ns_app)
                app_list.append(app_info)
                
                # Update cache
                self.running_apps[app_info.pid] = app_info
            
            return app_list
            
        except Exception as e:
            logger.error(f"❌ Running apps detection failed: {e}")
            return []
    
    def get_window_hierarchy(self, pid: Optional[int] = None) -> List[WindowInfo]:
        """Get window hierarchy for specific app or all apps"""
        try:
            window_list = CGWindowListCopyWindowInfo(
                kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements,
                kCGNullWindowID
            )
            
            if not window_list:
                return []
            
            windows = []
            for window in window_list:
                owner_pid = window.get('kCGWindowOwnerPID', 0)
                
                # Filter by PID if specified
                if pid and owner_pid != pid:
                    continue
                
                window_info = WindowInfo(
                    window_id=window.get('kCGWindowNumber', 0),
                    owner_pid=owner_pid,
                    owner_name=window.get('kCGWindowOwnerName', ''),
                    window_name=window.get('kCGWindowName', ''),
                    layer=window.get('kCGWindowLayer', 0),
                    bounds=window.get('kCGWindowBounds', {}),
                    is_onscreen=window.get('kCGWindowIsOnscreen', False),
                    confidence=self._calculate_window_confidence(window)
                )
                
                windows.append(window_info)
                
                # Update cache
                self.window_cache[window_info.window_id] = window_info
            
            return windows
            
        except Exception as e:
            logger.error(f"❌ Window hierarchy detection failed: {e}")
            return []
    
    def _calculate_window_confidence(self, window: Dict) -> float:
        """Calculate confidence for window detection"""
        try:
            confidence = 0.5
            
            # Has window name
            if window.get('kCGWindowName'):
                confidence += 0.2
            
            # Has owner name
            if window.get('kCGWindowOwnerName'):
                confidence += 0.2
            
            # Is on screen
            if window.get('kCGWindowIsOnscreen'):
                confidence += 0.1
            
            # Has reasonable bounds
            bounds = window.get('kCGWindowBounds', {})
            if bounds.get('Width', 0) > 0 and bounds.get('Height', 0) > 0:
                confidence += 0.1
            
            return min(1.0, confidence)
            
        except Exception as e:
            logger.error(f"❌ Window confidence calculation failed: {e}")
            return 0.5
    
    def detect_app_from_vision(self, vision_analysis: str) -> Optional[AppInfo]:
        """Detect app from vision analysis with API validation"""
        try:
            # Get current frontmost app for validation
            api_app = self.get_frontmost_app()
            if not api_app:
                return None
            
            # Validate vision analysis against API result
            vision_keywords = self._extract_app_keywords(vision_analysis)
            api_confidence = self._validate_with_api(vision_keywords, api_app)
            
            if api_confidence > 0.7:
                # High confidence - use API result
                api_app.confidence = api_confidence
                return api_app
            else:
                # Low confidence - try to resolve discrepancy
                return self._resolve_detection_conflict(vision_keywords, api_app)
            
        except Exception as e:
            logger.error(f"❌ Vision-API app detection failed: {e}")
            return None
    
    def _extract_app_keywords(self, vision_analysis: str) -> List[str]:
        """Extract app-related keywords from vision analysis"""
        try:
            analysis_lower = vision_analysis.lower()
            
            # Common app indicators
            app_keywords = []
            
            # Browser indicators
            if any(term in analysis_lower for term in ['browser', 'chrome', 'safari', 'firefox', 'address bar', 'url']):
                app_keywords.append('browser')
            
            # Code editor indicators
            if any(term in analysis_lower for term in ['vs code', 'visual studio', 'code editor', 'syntax highlighting']):
                app_keywords.append('code_editor')
            
            # Terminal indicators
            if any(term in analysis_lower for term in ['terminal', 'command line', 'bash', 'zsh', 'prompt']):
                app_keywords.append('terminal')
            
            # Communication indicators
            if any(term in analysis_lower for term in ['slack', 'zoom', 'teams', 'message', 'meeting']):
                app_keywords.append('communication')
            
            # System indicators
            if any(term in analysis_lower for term in ['finder', 'file manager', 'folder', 'desktop']):
                app_keywords.append('system')
            
            return app_keywords
            
        except Exception as e:
            logger.error(f"❌ Keyword extraction failed: {e}")
            return []
    
    def _validate_with_api(self, vision_keywords: List[str], api_app: AppInfo) -> float:
        """Validate vision keywords against API app detection"""
        try:
            bundle_id = api_app.bundle_id.lower()
            app_name = api_app.name.lower()
            
            confidence = 0.5  # Base confidence
            
            # Check keyword matches
            for keyword in vision_keywords:
                if keyword == 'browser' and any(term in bundle_id for term in ['chrome', 'safari', 'firefox']):
                    confidence += 0.3
                elif keyword == 'code_editor' and any(term in bundle_id for term in ['vscode', 'xcode', 'sublime']):
                    confidence += 0.3
                elif keyword == 'terminal' and 'terminal' in bundle_id:
                    confidence += 0.3
                elif keyword == 'communication' and any(term in bundle_id for term in ['slack', 'zoom', 'teams']):
                    confidence += 0.3
                elif keyword == 'system' and any(term in bundle_id for term in ['finder', 'system']):
                    confidence += 0.3
            
            # Name matching
            if any(keyword in app_name for keyword in vision_keywords):
                confidence += 0.2
            
            return min(1.0, confidence)
            
        except Exception as e:
            logger.error(f"❌ API validation failed: {e}")
            return 0.5
    
    def _resolve_detection_conflict(self, vision_keywords: List[str], api_app: AppInfo) -> AppInfo:
        """Resolve conflicts between vision and API detection"""
        try:
            # For now, trust the API more than vision
            # In production, would use more sophisticated resolution
            api_app.confidence = 0.6  # Moderate confidence due to conflict
            
            logger.warning(f"⚠️ Detection conflict: vision={vision_keywords}, api={api_app.name}")
            
            return api_app
            
        except Exception as e:
            logger.error(f"❌ Conflict resolution failed: {e}")
            return api_app
    
    def _refresh_running_apps(self):
        """Refresh running apps cache"""
        try:
            running_apps = self.get_running_apps()
            self.running_apps = {app.pid: app for app in running_apps}
            
            # Update current frontmost app
            self.current_app = self.get_frontmost_app()
            
        except Exception as e:
            logger.error(f"❌ App refresh failed: {e}")
    
    def _handle_app_transition(self, from_app: Optional[AppInfo], to_app: AppInfo, event_type: str):
        """Handle application transition events"""
        try:
            transition = AppTransition(
                timestamp=datetime.now(),
                event_type=event_type,
                from_app=from_app.bundle_id if from_app else None,
                to_app=to_app.bundle_id,
                bundle_id=to_app.bundle_id,
                confidence=to_app.confidence
            )
            
            self.transition_history.append(transition)
            
            logger.debug(f"🔄 App transition: {event_type} → {to_app.name} (confidence: {to_app.confidence:.2f})")
            
            # 🚀 Notify observers for immediate Glass UI updates (Grok's solution)
            for callback in self.observers:
                try:
                    callback(from_app, to_app, event_type)  # Notify service immediately
                except Exception as e:
                    logger.error(f"❌ Observer callback failed: {e}")
            
        except Exception as e:
            logger.error(f"❌ Transition handling failed: {e}")
    
    def _update_accuracy_metrics(self, app_info: AppInfo):
        """Update detection accuracy metrics"""
        try:
            # Simple accuracy tracking based on confidence
            if app_info.confidence > 0.9:
                self.detection_accuracy = (self.detection_accuracy * 0.9) + (1.0 * 0.1)
            elif app_info.confidence < 0.5:
                self.false_positives += 1
                self.detection_accuracy = (self.detection_accuracy * 0.9) + (0.0 * 0.1)
            else:
                self.detection_accuracy = (self.detection_accuracy * 0.9) + (app_info.confidence * 0.1)
            
        except Exception as e:
            logger.error(f"❌ Accuracy update failed: {e}")
    
    def get_performance_stats(self) -> Dict[str, Any]:
        """Get performance statistics"""
        try:
            return {
                "detection_accuracy": self.detection_accuracy,
                "false_positives": self.false_positives,
                "total_detections": self.total_detections,
                "running_apps_count": len(self.running_apps),
                "transition_count": len(self.transition_history),
                "current_app": self.current_app.name if self.current_app else None,
                "cache_size": len(self.window_cache)
            }
            
        except Exception as e:
            logger.error(f"❌ Performance stats failed: {e}")
            return {"error": str(e)}
    
    def start_monitoring(self):
        """Start background app monitoring"""
        try:
            if self.is_monitoring:
                return
            
            self.is_monitoring = True
            self.monitoring_thread = threading.Thread(target=self._monitoring_loop, daemon=True)
            self.monitoring_thread.start()
            
            logger.info("✅ Started background app monitoring")
            
        except Exception as e:
            logger.error(f"❌ Monitoring start failed: {e}")
    
    def _monitoring_loop(self):
        """Background monitoring loop"""
        while self.is_monitoring:
            try:
                # Refresh every 5 seconds
                time.sleep(5.0)
                
                # Update running apps
                self._refresh_running_apps()
                
                # Clean old cache entries
                self._cleanup_old_cache()
                
            except Exception as e:
                logger.error(f"❌ Monitoring loop error: {e}")
                time.sleep(1.0)
    
    def _cleanup_old_cache(self):
        """Clean up old cache entries"""
        try:
            # Remove old window cache entries (keep last 100)
            if len(self.window_cache) > 100:
                # Remove 20 oldest entries
                sorted_items = sorted(self.window_cache.items(), key=lambda x: x[1].window_id)
                for i in range(20):
                    del self.window_cache[sorted_items[i][0]]
            
        except Exception as e:
            logger.error(f"❌ Cache cleanup failed: {e}")
    
    def stop_monitoring(self):
        """Stop background monitoring"""
        try:
            self.is_monitoring = False
            if self.monitoring_thread:
                self.monitoring_thread.join(timeout=2.0)
            
            logger.info("✅ Stopped background app monitoring")
            
        except Exception as e:
            logger.error(f"❌ Monitoring stop failed: {e}")
    
    def cleanup(self):
        """Clean up resources"""
        try:
            self.stop_monitoring()
            
            # Unregister notifications
            self.notification_center.removeObserver_(self)
            
            logger.info("✅ MacOSAppDetector cleanup completed")
            
        except Exception as e:
            logger.error(f"❌ Cleanup failed: {e}")
    
    def __del__(self):
        """Destructor"""
        self.cleanup()
    
    # Notification handlers
    def handleAppActivation_(self, notification):
        """Handle app activation notification"""
        try:
            app = notification.userInfo().get('NSWorkspaceApplicationKey')
            if app:
                app_info = self._extract_app_info(app)
                self._handle_app_transition(self.current_app, app_info, 'activate')
                self.current_app = app_info
                
        except Exception as e:
            logger.error(f"❌ App activation handler failed: {e}")
    
    def handleAppDeactivation_(self, notification):
        """Handle app deactivation notification"""
        try:
            app = notification.userInfo().get('NSWorkspaceApplicationKey')
            if app:
                app_info = self._extract_app_info(app)
                self._handle_app_transition(app_info, None, 'deactivate')
                
        except Exception as e:
            logger.error(f"❌ App deactivation handler failed: {e}")
    
    def handleAppLaunch_(self, notification):
        """Handle app launch notification"""
        try:
            app = notification.userInfo().get('NSWorkspaceApplicationKey')
            if app:
                app_info = self._extract_app_info(app)
                self._handle_app_transition(None, app_info, 'launch')
                
        except Exception as e:
            logger.error(f"❌ App launch handler failed: {e}")
    
    def handleAppTermination_(self, notification):
        """Handle app termination notification"""
        try:
            app = notification.userInfo().get('NSWorkspaceApplicationKey')
            if app:
                app_info = self._extract_app_info(app)
                self._handle_app_transition(app_info, None, 'terminate')
                
                # Remove from running apps
                if app_info.pid in self.running_apps:
                    del self.running_apps[app_info.pid]
                
        except Exception as e:
            logger.error(f"❌ App termination handler failed: {e}")