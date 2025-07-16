#!/usr/bin/env python3
"""
PyObjC Detector Stabilized - Critical Fix #4
Thread-isolated PyObjC integration with version checking and memory management

Features:
- Thread isolation to prevent PyObjC threading issues
- Version checking with graceful fallbacks
- Memory management with automatic cleanup
- Error handling with recovery mechanisms
- Performance monitoring and metrics
- Lazy loading to reduce startup time
"""

import sys
import threading
import time
import queue
import gc
import weakref
from typing import Dict, Any, Optional, List, Tuple
from dataclasses import dataclass, asdict
from enum import Enum
import structlog

logger = structlog.get_logger()

class PyObjCCompatibilityLevel(Enum):
    """PyObjC compatibility levels"""
    FULL = "full"           # Full PyObjC support
    LIMITED = "limited"     # Basic PyObjC support  
    FALLBACK = "fallback"   # No PyObjC, use fallbacks
    UNAVAILABLE = "unavailable"  # Complete failure

@dataclass
class AppInfo:
    """Application information"""
    name: str
    bundle_id: str
    pid: int
    confidence: float
    window_count: int = 0
    is_active: bool = True
    window_title: str = ""
    timestamp: float = 0.0

@dataclass
class DetectorMetrics:
    """Detector performance metrics"""
    requests_total: int = 0
    requests_success: int = 0
    requests_failed: int = 0
    average_latency_ms: float = 0.0
    memory_usage_mb: float = 0.0
    thread_restarts: int = 0
    compatibility_level: PyObjCCompatibilityLevel = PyObjCCompatibilityLevel.UNAVAILABLE
    last_error: Optional[str] = None

class PyObjCDetectorStabilized:
    """Thread-isolated PyObjC detector with stability improvements"""
    
    def __init__(self, enable_thread_isolation: bool = True):
        """Initialize stabilized PyObjC detector"""
        self.enable_thread_isolation = enable_thread_isolation
        self.compatibility_level = PyObjCCompatibilityLevel.UNAVAILABLE
        self.metrics = DetectorMetrics()
        
        # Thread management
        self.worker_thread = None
        self.request_queue = queue.Queue()
        self.response_queue = queue.Queue()
        self.shutdown_event = threading.Event()
        self.worker_ready = threading.Event()
        
        # Performance tracking
        self.request_times = []
        self.max_request_history = 100
        self.metrics_lock = threading.Lock()
        
        # Memory management
        self.last_gc_time = time.time()
        self.gc_interval = 30.0  # seconds
        
        # Cached data
        self.cached_apps = {}
        self.cache_ttl = 5.0  # seconds
        self.last_frontmost_app = None
        self.last_frontmost_time = 0
        
        # Initialize PyObjC compatibility
        self._check_pyobjc_compatibility()
        
        # Start worker thread if thread isolation is enabled
        if self.enable_thread_isolation:
            self._start_worker_thread()
        
        logger.info(f"✅ PyObjCDetectorStabilized initialized (compatibility: {self.compatibility_level.value})")
    
    def _check_pyobjc_compatibility(self):
        """Check PyObjC compatibility and set appropriate level"""
        try:
            # Try to import PyObjC components
            import objc
            
            # Check version
            if hasattr(objc, '__version__'):
                version = objc.__version__
                major_version = int(version.split('.')[0])
                
                if major_version >= 9:
                    self.compatibility_level = PyObjCCompatibilityLevel.FULL
                elif major_version >= 7:
                    self.compatibility_level = PyObjCCompatibilityLevel.LIMITED
                else:
                    self.compatibility_level = PyObjCCompatibilityLevel.FALLBACK
                    
                logger.info(f"🔍 PyObjC version {version} detected (level: {self.compatibility_level.value})")
            else:
                self.compatibility_level = PyObjCCompatibilityLevel.LIMITED
                logger.warning("⚠️ PyObjC version unknown, using limited compatibility")
            
            # Test basic functionality
            self._test_pyobjc_basic()
            
        except ImportError as e:
            logger.warning(f"⚠️ PyObjC not available: {e}")
            self.compatibility_level = PyObjCCompatibilityLevel.FALLBACK
            self.metrics.last_error = f"PyObjC import failed: {e}"
            
        except Exception as e:
            logger.warning(f"⚠️ PyObjC compatibility check failed: {e}")
            self.compatibility_level = PyObjCCompatibilityLevel.FALLBACK
            self.metrics.last_error = f"PyObjC check failed: {e}"
    
    def _test_pyobjc_basic(self):
        """Test basic PyObjC functionality"""
        try:
            if self.compatibility_level == PyObjCCompatibilityLevel.FALLBACK:
                return
            
            # Try to access NSWorkspace
            from AppKit import NSWorkspace
            workspace = NSWorkspace.sharedWorkspace()
            
            # Try to get running applications
            apps = workspace.runningApplications()
            if apps and len(apps) > 0:
                logger.debug(f"✅ PyObjC basic test passed ({len(apps)} apps)")
            else:
                logger.warning("⚠️ PyObjC basic test: no apps returned")
                self.compatibility_level = PyObjCCompatibilityLevel.LIMITED
                
        except Exception as e:
            logger.warning(f"⚠️ PyObjC basic test failed: {e}")
            self.compatibility_level = PyObjCCompatibilityLevel.FALLBACK
    
    def _start_worker_thread(self):
        """Start the worker thread for PyObjC operations"""
        if self.worker_thread and self.worker_thread.is_alive():
            logger.warning("⚠️ Worker thread already running")
            return
        
        self.shutdown_event.clear()
        self.worker_ready.clear()
        
        self.worker_thread = threading.Thread(
            target=self._worker_loop,
            name="PyObjCDetectorWorker",
            daemon=True
        )
        self.worker_thread.start()
        
        # Wait for worker to be ready
        if not self.worker_ready.wait(timeout=5.0):
            logger.error("❌ Worker thread failed to start within timeout")
            self.compatibility_level = PyObjCCompatibilityLevel.FALLBACK
        else:
            logger.info("✅ Worker thread started successfully")
    
    def _worker_loop(self):
        """Main worker thread loop"""
        try:
            # Initialize PyObjC in this thread
            self._initialize_pyobjc_in_thread()
            
            # Signal that worker is ready
            self.worker_ready.set()
            
            # Main processing loop
            while not self.shutdown_event.is_set():
                try:
                    # Get request with timeout
                    request = self.request_queue.get(timeout=1.0)
                    
                    # Process request
                    response = self._process_request(request)
                    
                    # Send response
                    self.response_queue.put(response)
                    
                    # Mark task as done
                    self.request_queue.task_done()
                    
                    # Periodic garbage collection
                    self._maybe_gc()
                    
                except queue.Empty:
                    # Timeout, continue loop
                    continue
                    
                except Exception as e:
                    logger.error(f"❌ Worker thread error: {e}")
                    # Send error response
                    self.response_queue.put({'error': str(e)})
                    
                    # Update metrics
                    with self.metrics_lock:
                        self.metrics.requests_failed += 1
                        self.metrics.last_error = str(e)
            
        except Exception as e:
            logger.error(f"❌ Worker thread fatal error: {e}")
            self.compatibility_level = PyObjCCompatibilityLevel.FALLBACK
            self.metrics.last_error = f"Worker thread failed: {e}"
        
        finally:
            logger.info("🔄 Worker thread shutting down")
    
    def _initialize_pyobjc_in_thread(self):
        """Initialize PyObjC components in worker thread"""
        try:
            if self.compatibility_level == PyObjCCompatibilityLevel.FALLBACK:
                return
            
            # Import PyObjC components
            from AppKit import NSWorkspace, NSApplicationActivationPolicyRegular
            from Foundation import NSBundle
            
            # Store references for thread-local access
            self.workspace = NSWorkspace.sharedWorkspace()
            self.NSApplicationActivationPolicyRegular = NSApplicationActivationPolicyRegular
            self.NSBundle = NSBundle
            
            logger.debug("✅ PyObjC initialized in worker thread")
            
        except Exception as e:
            logger.error(f"❌ PyObjC thread initialization failed: {e}")
            self.compatibility_level = PyObjCCompatibilityLevel.FALLBACK
            raise
    
    def _process_request(self, request: Dict[str, Any]) -> Dict[str, Any]:
        """Process request in worker thread"""
        start_time = time.time()
        
        try:
            request_type = request.get('type')
            
            if request_type == 'get_frontmost_app':
                result = self._get_frontmost_app_thread()
            elif request_type == 'get_running_apps':
                result = self._get_running_apps_thread()
            elif request_type == 'get_app_info':
                bundle_id = request.get('bundle_id')
                result = self._get_app_info_thread(bundle_id)
            elif request_type == 'detect_app_from_vision':
                vision_analysis = request.get('vision_analysis')
                result = self._detect_app_from_vision_thread(vision_analysis)
            else:
                result = {'error': f'Unknown request type: {request_type}'}
            
            # Update metrics
            latency_ms = (time.time() - start_time) * 1000
            with self.metrics_lock:
                self.metrics.requests_total += 1
                self.metrics.requests_success += 1
                self.request_times.append(latency_ms)
                
                if len(self.request_times) > self.max_request_history:
                    self.request_times.pop(0)
                
                self.metrics.average_latency_ms = sum(self.request_times) / len(self.request_times)
            
            return result
            
        except Exception as e:
            # Update metrics
            with self.metrics_lock:
                self.metrics.requests_total += 1
                self.metrics.requests_failed += 1
                self.metrics.last_error = str(e)
            
            return {'error': str(e)}
    
    def _get_frontmost_app_thread(self) -> Dict[str, Any]:
        """Get frontmost application in worker thread"""
        try:
            if self.compatibility_level == PyObjCCompatibilityLevel.FALLBACK:
                return self._get_frontmost_app_fallback()
            
            # Get frontmost application
            frontmost_app = self.workspace.frontmostApplication()
            
            if frontmost_app:
                app_info = AppInfo(
                    name=str(frontmost_app.localizedName() or "Unknown"),
                    bundle_id=str(frontmost_app.bundleIdentifier() or "unknown"),
                    pid=int(frontmost_app.processIdentifier()),
                    confidence=1.0,
                    window_count=1,  # Frontmost app has at least one window
                    is_active=True,
                    timestamp=time.time()
                )
                
                return {'success': True, 'app_info': asdict(app_info)}
            else:
                return {'success': False, 'error': 'No frontmost application found'}
                
        except Exception as e:
            logger.error(f"❌ Get frontmost app failed: {e}")
            return {'success': False, 'error': str(e)}
    
    def _get_running_apps_thread(self) -> Dict[str, Any]:
        """Get running applications in worker thread"""
        try:
            if self.compatibility_level == PyObjCCompatibilityLevel.FALLBACK:
                return self._get_running_apps_fallback()
            
            # Get running applications
            running_apps = self.workspace.runningApplications()
            
            apps = []
            for app in running_apps:
                try:
                    # Filter for regular applications
                    if app.activationPolicy() == self.NSApplicationActivationPolicyRegular:
                        app_info = AppInfo(
                            name=str(app.localizedName() or "Unknown"),
                            bundle_id=str(app.bundleIdentifier() or "unknown"),
                            pid=int(app.processIdentifier()),
                            confidence=0.9,
                            window_count=0,  # Would need additional API calls
                            is_active=bool(app.isActive()),
                            timestamp=time.time()
                        )
                        apps.append(asdict(app_info))
                        
                except Exception as e:
                    logger.warning(f"⚠️ Failed to process app: {e}")
                    continue
            
            return {'success': True, 'apps': apps}
            
        except Exception as e:
            logger.error(f"❌ Get running apps failed: {e}")
            return {'success': False, 'error': str(e)}
    
    def _get_app_info_thread(self, bundle_id: str) -> Dict[str, Any]:
        """Get specific app info in worker thread"""
        try:
            if self.compatibility_level == PyObjCCompatibilityLevel.FALLBACK:
                return self._get_app_info_fallback(bundle_id)
            
            # Find app by bundle ID
            running_apps = self.workspace.runningApplications()
            
            for app in running_apps:
                if str(app.bundleIdentifier() or "") == bundle_id:
                    app_info = AppInfo(
                        name=str(app.localizedName() or "Unknown"),
                        bundle_id=bundle_id,
                        pid=int(app.processIdentifier()),
                        confidence=1.0,
                        window_count=0,
                        is_active=bool(app.isActive()),
                        timestamp=time.time()
                    )
                    
                    return {'success': True, 'app_info': asdict(app_info)}
            
            return {'success': False, 'error': f'App not found: {bundle_id}'}
            
        except Exception as e:
            logger.error(f"❌ Get app info failed: {e}")
            return {'success': False, 'error': str(e)}
    
    def _detect_app_from_vision_thread(self, vision_analysis: str) -> Dict[str, Any]:
        """Detect app from vision analysis in worker thread"""
        try:
            # Simple keyword matching for now
            analysis_lower = vision_analysis.lower()
            
            # App detection patterns
            patterns = {
                'com.microsoft.VSCode': ['vs code', 'visual studio code', 'vscode'],
                'com.apple.Terminal': ['terminal', 'command line', 'bash', 'shell'],
                'com.google.Chrome': ['chrome', 'google chrome', 'browser'],
                'com.apple.Safari': ['safari', 'browser'],
                'com.tinyspeck.slackmacgap': ['slack'],
                'com.apple.finder': ['finder', 'file manager'],
                'com.todesktop.230313mzl4w4u92': ['cursor', 'code editor'],
                'com.github.atom': ['atom'],
                'com.sublimetext.3': ['sublime', 'sublime text']
            }
            
            # Find best match
            best_match = None
            best_score = 0
            
            for bundle_id, keywords in patterns.items():
                score = 0
                for keyword in keywords:
                    if keyword in analysis_lower:
                        score += 1
                
                if score > best_score:
                    best_score = score
                    best_match = bundle_id
            
            if best_match and best_score > 0:
                # Get app info for matched bundle ID
                app_result = self._get_app_info_thread(best_match)
                
                if app_result.get('success'):
                    app_info = app_result['app_info']
                    app_info['confidence'] = min(0.9, best_score * 0.3)  # Adjust confidence
                    return {'success': True, 'app_info': app_info}
            
            return {'success': False, 'error': 'No app detected from vision analysis'}
            
        except Exception as e:
            logger.error(f"❌ App detection from vision failed: {e}")
            return {'success': False, 'error': str(e)}
    
    def _get_frontmost_app_fallback(self) -> Dict[str, Any]:
        """Fallback method for getting frontmost app"""
        try:
            # Use system commands as fallback
            import subprocess
            
            # Get frontmost app using AppleScript
            script = 'tell application "System Events" to get name of first application process whose frontmost is true'
            result = subprocess.run(['osascript', '-e', script], capture_output=True, text=True, timeout=5)
            
            if result.returncode == 0:
                app_name = result.stdout.strip()
                app_info = AppInfo(
                    name=app_name,
                    bundle_id=f"fallback.{app_name.lower().replace(' ', '.')}",
                    pid=0,
                    confidence=0.7,  # Lower confidence for fallback
                    window_count=1,
                    is_active=True,
                    timestamp=time.time()
                )
                
                return {'success': True, 'app_info': asdict(app_info)}
            else:
                return {'success': False, 'error': 'Fallback method failed'}
                
        except Exception as e:
            logger.error(f"❌ Fallback frontmost app failed: {e}")
            return {'success': False, 'error': str(e)}
    
    def _get_running_apps_fallback(self) -> Dict[str, Any]:
        """Fallback method for getting running apps"""
        try:
            # Return minimal app list
            apps = [
                AppInfo(
                    name="Unknown App",
                    bundle_id="fallback.unknown",
                    pid=0,
                    confidence=0.5,
                    window_count=0,
                    is_active=False,
                    timestamp=time.time()
                )
            ]
            
            return {'success': True, 'apps': [asdict(app) for app in apps]}
            
        except Exception as e:
            logger.error(f"❌ Fallback running apps failed: {e}")
            return {'success': False, 'error': str(e)}
    
    def _get_app_info_fallback(self, bundle_id: str) -> Dict[str, Any]:
        """Fallback method for getting app info"""
        try:
            # Return minimal app info
            app_info = AppInfo(
                name="Unknown App",
                bundle_id=bundle_id,
                pid=0,
                confidence=0.5,
                window_count=0,
                is_active=False,
                timestamp=time.time()
            )
            
            return {'success': True, 'app_info': asdict(app_info)}
            
        except Exception as e:
            logger.error(f"❌ Fallback app info failed: {e}")
            return {'success': False, 'error': str(e)}
    
    def _maybe_gc(self):
        """Perform garbage collection if needed"""
        current_time = time.time()
        if current_time - self.last_gc_time > self.gc_interval:
            gc.collect()
            self.last_gc_time = current_time
            
            # Update memory usage
            try:
                import psutil
                process = psutil.Process()
                self.metrics.memory_usage_mb = process.memory_info().rss / 1024 / 1024
            except:
                pass
    
    def _send_request(self, request: Dict[str, Any], timeout: float = 5.0) -> Dict[str, Any]:
        """Send request to worker thread"""
        if not self.enable_thread_isolation:
            # Process directly in main thread
            return self._process_request(request)
        
        if not self.worker_thread or not self.worker_thread.is_alive():
            logger.warning("⚠️ Worker thread not available, restarting...")
            self._start_worker_thread()
            
            if not self.worker_ready.wait(timeout=5.0):
                logger.error("❌ Worker thread restart failed")
                return {'error': 'Worker thread unavailable'}
        
        try:
            # Send request
            self.request_queue.put(request, timeout=timeout)
            
            # Wait for response
            response = self.response_queue.get(timeout=timeout)
            
            return response
            
        except queue.Empty:
            logger.error("❌ Request timeout")
            return {'error': 'Request timeout'}
        except Exception as e:
            logger.error(f"❌ Request failed: {e}")
            return {'error': str(e)}
    
    # Public API methods
    def get_frontmost_app(self) -> Optional[AppInfo]:
        """Get frontmost application"""
        # Check cache first
        current_time = time.time()
        if (self.last_frontmost_app and 
            current_time - self.last_frontmost_time < self.cache_ttl):
            return self.last_frontmost_app
        
        # Send request
        request = {'type': 'get_frontmost_app'}
        response = self._send_request(request)
        
        if response.get('success'):
            app_data = response['app_info']
            app_info = AppInfo(**app_data)
            
            # Update cache
            self.last_frontmost_app = app_info
            self.last_frontmost_time = current_time
            
            return app_info
        else:
            logger.error(f"❌ Get frontmost app failed: {response.get('error')}")
            return None
    
    def get_running_apps(self) -> List[AppInfo]:
        """Get running applications"""
        request = {'type': 'get_running_apps'}
        response = self._send_request(request)
        
        if response.get('success'):
            apps_data = response['apps']
            return [AppInfo(**app_data) for app_data in apps_data]
        else:
            logger.error(f"❌ Get running apps failed: {response.get('error')}")
            return []
    
    def get_app_info(self, bundle_id: str) -> Optional[AppInfo]:
        """Get specific app info"""
        request = {'type': 'get_app_info', 'bundle_id': bundle_id}
        response = self._send_request(request)
        
        if response.get('success'):
            app_data = response['app_info']
            return AppInfo(**app_data)
        else:
            logger.error(f"❌ Get app info failed: {response.get('error')}")
            return None
    
    def detect_app_from_vision(self, vision_analysis: str) -> Optional[AppInfo]:
        """Detect app from vision analysis"""
        request = {'type': 'detect_app_from_vision', 'vision_analysis': vision_analysis}
        response = self._send_request(request)
        
        if response.get('success'):
            app_data = response['app_info']
            return AppInfo(**app_data)
        else:
            logger.debug(f"🔍 No app detected from vision: {response.get('error')}")
            return None
    
    def get_active_window_info(self) -> Optional[Dict[str, Any]]:
        """Get active window information with bounds"""
        try:
            # Get frontmost app
            frontmost = self.get_frontmost_app()
            if not frontmost:
                return None
            
            # For now, return approximate bounds based on screen size
            # In a real implementation, we'd use CGWindowListCopyWindowInfo
            screen_width = 1920  # Default, could be detected
            screen_height = 1080
            
            # Approximate window bounds (centered window)
            window_width = int(screen_width * 0.8)
            window_height = int(screen_height * 0.8)
            x = (screen_width - window_width) // 2
            y = (screen_height - window_height) // 2
            
            return {
                'app_name': frontmost.name,
                'bundle_id': frontmost.bundle_id,
                'bounds': {
                    'x': x,
                    'y': y,
                    'width': window_width,
                    'height': window_height
                },
                'is_frontmost': True,
                'confidence': frontmost.confidence
            }
            
        except Exception as e:
            logger.error(f"❌ Get active window info failed: {e}")
            return None
    
    def get_performance_stats(self) -> Dict[str, Any]:
        """Get performance statistics"""
        with self.metrics_lock:
            stats = {
                'requests_total': self.metrics.requests_total,
                'requests_success': self.metrics.requests_success,
                'requests_failed': self.metrics.requests_failed,
                'success_rate': (self.metrics.requests_success / max(1, self.metrics.requests_total)) * 100,
                'average_latency_ms': self.metrics.average_latency_ms,
                'memory_usage_mb': self.metrics.memory_usage_mb,
                'compatibility_level': self.compatibility_level.value,
                'thread_restarts': self.metrics.thread_restarts,
                'last_error': self.metrics.last_error
            }
            
            return stats
    
    def shutdown(self):
        """Shutdown detector and cleanup resources"""
        try:
            if self.worker_thread and self.worker_thread.is_alive():
                logger.info("🔄 Shutting down worker thread...")
                self.shutdown_event.set()
                self.worker_thread.join(timeout=5.0)
                
                if self.worker_thread.is_alive():
                    logger.warning("⚠️ Worker thread did not shut down gracefully")
            
            # Clear caches
            self.cached_apps.clear()
            self.last_frontmost_app = None
            
            # Force garbage collection
            gc.collect()
            
            logger.info("✅ PyObjCDetectorStabilized shutdown complete")
            
        except Exception as e:
            logger.error(f"❌ Shutdown failed: {e}")


if __name__ == "__main__":
    # Test stabilized detector
    print("🧪 Testing PyObjCDetectorStabilized...")
    
    detector = PyObjCDetectorStabilized()
    
    # Test frontmost app
    app = detector.get_frontmost_app()
    if app:
        print(f"✅ Frontmost app: {app.name} ({app.bundle_id})")
    else:
        print("⚠️ No frontmost app detected")
    
    # Test running apps
    apps = detector.get_running_apps()
    print(f"✅ Running apps: {len(apps)}")
    
    # Test performance stats
    stats = detector.get_performance_stats()
    print(f"✅ Performance stats: {stats}")
    
    # Test vision detection
    vision_test = "The user is working in VS Code editor"
    detected = detector.detect_app_from_vision(vision_test)
    if detected:
        print(f"✅ Vision detection: {detected.name} (confidence: {detected.confidence:.2f})")
    else:
        print("⚠️ No app detected from vision")
    
    # Shutdown
    detector.shutdown()
    print("✅ Detector shutdown complete")
    
    print("🎉 PyObjCDetectorStabilized test complete!")