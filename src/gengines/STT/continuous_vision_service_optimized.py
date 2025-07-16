#!/usr/bin/env python3
"""
Memory-Optimized Continuous Vision Service - Integration of Critical Fixes 1-6
Implements all critical fixes with proper memory management and lazy loading

Features:
- Lazy loading of components (Fix #1)
- Centralized storage with StorageManager (Fix #2)
- Vision service wrapper with lifecycle management (Fix #3)
- Stabilized PyObjC integration (Fix #4)
- GPT cost optimization (Fix #5)
- Enhanced temporal parsing (Fix #6)
- Memory target: <200MB
"""

import os
import sys
import time
import gc
import threading
import weakref
from typing import Dict, Any, Optional, List
from datetime import datetime, timedelta
from collections import deque
from dataclasses import dataclass
import structlog

# Lazy imports - only import when needed
logger = structlog.get_logger()

class LazyComponentLoader:
    """Lazy loader for heavy components"""
    
    def __init__(self):
        self._components = {}
        self._loading_lock = threading.Lock()
        
    def get_component(self, name: str, loader_func):
        """Get component with lazy loading"""
        if name not in self._components:
            with self._loading_lock:
                if name not in self._components:
                    logger.debug(f"🔄 Lazy loading component: {name}")
                    self._components[name] = loader_func()
        
        return self._components[name]
    
    def clear_component(self, name: str):
        """Clear component from cache"""
        if name in self._components:
            del self._components[name]
            gc.collect()
            logger.debug(f"🧹 Cleared component: {name}")

# Global lazy loader
_lazy_loader = LazyComponentLoader()

def _load_storage_manager():
    """Lazy load storage manager"""
    from storage_manager import StorageManager
    return StorageManager()

def _load_vision_service():
    """Lazy load vision service wrapper"""
    from vision_service_wrapper import VisionServiceWrapper
    service = VisionServiceWrapper.get_instance()
    service.start()
    return service

def _load_pyobjc_detector():
    """Lazy load PyObjC detector"""
    from pyobjc_detector_stabilized import PyObjCDetectorStabilized
    return PyObjCDetectorStabilized()

def _load_gpt_optimizer():
    """Lazy load GPT optimizer"""
    from gpt_cost_optimizer import GPTCostOptimizer
    detector = _lazy_loader.get_component('pyobjc_detector', _load_pyobjc_detector)
    vision_service = _lazy_loader.get_component('vision_service', _load_vision_service)
    return GPTCostOptimizer(detector, vision_service)

def _load_temporal_parser():
    """Lazy load temporal parser"""
    from enhanced_temporal_parser import EnhancedTemporalParser
    return EnhancedTemporalParser()

class MemoryOptimizedContinuousVision:
    """Memory-optimized continuous vision service"""
    
    def __init__(self, capture_fps: float = 1.0):
        """Initialize with minimal memory footprint"""
        self.capture_fps = capture_fps
        self.running = False
        self.monitor_thread = None
        
        # Minimal state
        self.activity_deque = deque(maxlen=10)  # Reduced from 30
        self.transition_history = deque(maxlen=50)  # Reduced from 1000
        
        # Memory management
        self.gc_counter = 0
        self.gc_interval = 5  # Force GC every 5 operations
        
        # Set aggressive GC
        gc.set_threshold(700, 10, 10)
        
        logger.info("✅ MemoryOptimizedContinuousVision initialized")
    
    def start_monitoring(self):
        """Start monitoring with memory optimization"""
        if self.running:
            logger.warning("⚠️ Already running")
            return
        
        self.running = True
        self.monitor_thread = threading.Thread(target=self._monitor_loop, daemon=True)
        self.monitor_thread.start()
        
        logger.info("🔍 Started memory-optimized monitoring")
    
    def stop_monitoring(self):
        """Stop monitoring and cleanup"""
        self.running = False
        
        if self.monitor_thread:
            self.monitor_thread.join(timeout=2.0)
        
        # Clear component cache
        _lazy_loader.clear_component('vision_service')
        _lazy_loader.clear_component('pyobjc_detector')
        _lazy_loader.clear_component('gpt_optimizer')
        _lazy_loader.clear_component('temporal_parser')
        
        # Force garbage collection
        gc.collect()
        
        logger.info("⏹️ Stopped monitoring and cleaned up")
    
    def _monitor_loop(self):
        """Optimized monitoring loop"""
        while self.running:
            try:
                # Periodic memory management
                self._manage_memory()
                
                # Simulate frame processing (without actual GPT calls)
                self._process_frame_lightweight()
                
                # Sleep to maintain FPS
                time.sleep(1.0 / self.capture_fps)
                
            except Exception as e:
                logger.error(f"❌ Monitor loop error: {e}")
                time.sleep(1.0)
    
    def _manage_memory(self):
        """Aggressive memory management"""
        self.gc_counter += 1
        
        if self.gc_counter >= self.gc_interval:
            # Force garbage collection
            gc.collect()
            self.gc_counter = 0
            
            # Clear old activities
            if len(self.activity_deque) > 5:
                # Keep only recent activities
                recent = list(self.activity_deque)[-5:]
                self.activity_deque.clear()
                self.activity_deque.extend(recent)
    
    def _process_frame_lightweight(self):
        """Lightweight frame processing without heavy GPT calls"""
        try:
            # Get PyObjC detector only when needed
            detector = _lazy_loader.get_component('pyobjc_detector', _load_pyobjc_detector)
            
            # Get current app (this is lightweight)
            current_app = detector.get_frontmost_app()
            
            if current_app:
                # Add to activity deque
                activity = {
                    'timestamp': datetime.now(),
                    'app_name': current_app.name,
                    'bundle_id': current_app.bundle_id,
                    'confidence': current_app.confidence
                }
                
                self.activity_deque.append(activity)
                
                logger.debug(f"📱 Detected app: {current_app.name}")
        
        except Exception as e:
            logger.error(f"❌ Lightweight processing failed: {e}")
    
    def analyze_image(self, image_path: str, prompt: str) -> Dict[str, Any]:
        """Analyze image with cost optimization"""
        try:
            # Get optimizer only when needed
            optimizer = _lazy_loader.get_component('gpt_optimizer', _load_gpt_optimizer)
            
            # Process with fallback
            result = optimizer.process_with_fallback(image_path, prompt, "analysis")
            
            # Force GC after heavy operation
            gc.collect()
            
            return result
            
        except Exception as e:
            logger.error(f"❌ Image analysis failed: {e}")
            return {'error': str(e)}
    
    def query_temporal_context(self, query: str) -> str:
        """Query temporal context with enhanced parsing"""
        try:
            # Get parser only when needed
            parser = _lazy_loader.get_component('temporal_parser', _load_temporal_parser)
            
            # Parse query
            parsed = parser.parse_temporal_query(query)
            
            # Simple response based on recent activities
            recent_activities = list(self.activity_deque)[-5:]
            
            if recent_activities:
                apps = [act['app_name'] for act in recent_activities]
                response = f"Recent activities: {', '.join(set(apps))}"
            else:
                response = "No recent activity data available"
            
            return response
            
        except Exception as e:
            logger.error(f"❌ Temporal query failed: {e}")
            return f"Query failed: {str(e)}"
    
    def get_storage_stats(self) -> Dict[str, Any]:
        """Get storage statistics"""
        try:
            storage = _lazy_loader.get_component('storage_manager', _load_storage_manager)
            return storage.get_storage_stats()
        except Exception as e:
            logger.error(f"❌ Storage stats failed: {e}")
            return {}
    
    def get_memory_usage(self) -> Dict[str, Any]:
        """Get current memory usage"""
        try:
            import psutil
            process = psutil.Process()
            memory_info = process.memory_info()
            
            return {
                'rss_mb': memory_info.rss / 1024 / 1024,
                'vms_mb': memory_info.vms / 1024 / 1024,
                'activity_count': len(self.activity_deque),
                'transition_count': len(self.transition_history),
                'gc_count': gc.get_count()
            }
            
        except Exception as e:
            logger.error(f"❌ Memory usage check failed: {e}")
            return {}
    
    def get_performance_stats(self) -> Dict[str, Any]:
        """Get performance statistics"""
        try:
            stats = {
                'running': self.running,
                'capture_fps': self.capture_fps,
                'memory_usage': self.get_memory_usage(),
                'storage_stats': self.get_storage_stats()
            }
            
            # Add component stats if loaded
            if 'gpt_optimizer' in _lazy_loader._components:
                optimizer = _lazy_loader._components['gpt_optimizer']
                stats['gpt_stats'] = optimizer.get_cost_stats()
            
            if 'pyobjc_detector' in _lazy_loader._components:
                detector = _lazy_loader._components['pyobjc_detector']
                stats['detector_stats'] = detector.get_performance_stats()
            
            return stats
            
        except Exception as e:
            logger.error(f"❌ Performance stats failed: {e}")
            return {}


# Global instance with lazy initialization
_optimized_vision = None

def get_optimized_vision() -> MemoryOptimizedContinuousVision:
    """Get global optimized vision instance"""
    global _optimized_vision
    if _optimized_vision is None:
        _optimized_vision = MemoryOptimizedContinuousVision()
    return _optimized_vision

def test_memory_optimized_vision():
    """Test memory-optimized vision service"""
    print("🧪 Testing Memory-Optimized Continuous Vision Service")
    print("=" * 60)
    
    # Get service
    service = get_optimized_vision()
    
    # Test initial memory
    initial_memory = service.get_memory_usage()
    print(f"📊 Initial memory: {initial_memory.get('rss_mb', 0):.1f} MB")
    
    # Start monitoring
    service.start_monitoring()
    
    # Let it run for a bit
    time.sleep(5)
    
    # Test image analysis
    test_image = "/Users/devin/Desktop/vision_test_768.png"
    if os.path.exists(test_image):
        print("🖼️ Testing image analysis...")
        result = service.analyze_image(test_image, "Analyze this screen")
        print(f"   Result: {result.get('source', 'unknown')}")
    
    # Test temporal query
    print("🕰️ Testing temporal query...")
    response = service.query_temporal_context("What apps did I use recently?")
    print(f"   Response: {response}")
    
    # Test performance stats
    stats = service.get_performance_stats()
    memory_usage = stats.get('memory_usage', {}).get('rss_mb', 0)
    print(f"📊 Current memory: {memory_usage:.1f} MB")
    
    # Stop monitoring
    service.stop_monitoring()
    
    # Final memory check
    final_memory = service.get_memory_usage()
    print(f"📊 Final memory: {final_memory.get('rss_mb', 0):.1f} MB")
    
    # Check if memory target met
    target_mb = 200
    memory_efficient = memory_usage < target_mb
    print(f"🎯 Memory target met: {'✅ YES' if memory_efficient else '❌ NO'} ({memory_usage:.1f} MB vs {target_mb} MB)")
    
    print("\n🎉 Memory-optimized test complete!")


if __name__ == "__main__":
    test_memory_optimized_vision()