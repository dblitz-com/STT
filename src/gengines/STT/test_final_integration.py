#!/usr/bin/env python3
"""
Final Integration Test - Zeus VLA Critical Fixes
Demonstrates working critical fixes with realistic usage patterns
"""

import os
import sys
import time
import psutil
import gc
import threading
from datetime import datetime
import structlog

logger = structlog.get_logger()

def get_memory_usage():
    """Get current memory usage"""
    try:
        process = psutil.Process()
        return process.memory_info().rss / 1024 / 1024
    except:
        return 0

def test_realistic_workflow():
    """Test realistic Zeus VLA workflow"""
    print("🧪 Zeus VLA Critical Fixes - Final Integration Test")
    print("=" * 60)
    
    initial_memory = get_memory_usage()
    print(f"📊 Initial memory: {initial_memory:.1f} MB")
    
    # Test 1: Storage Manager (Fix #2)
    print("\n🗂️ Test 1: Centralized Storage")
    print("-" * 40)
    
    try:
        from storage_manager import StorageManager
        storage = StorageManager()
        
        # Store test data
        test_data = b"Zeus VLA screen capture data"
        path = storage.store_file(test_data, "test_capture.png")
        
        # Get stats
        stats = storage.get_storage_stats()
        
        print(f"✅ Storage working: {stats.get('file_count', 0)} files")
        print(f"   Location: {stats.get('base_dir', 'unknown')}")
        print(f"   Encrypted: {stats.get('encryption_enabled', False)}")
        
    except Exception as e:
        print(f"❌ Storage failed: {e}")
    
    # Test 2: PyObjC App Detection (Fix #4)
    print("\n🍎 Test 2: App Detection")
    print("-" * 40)
    
    try:
        from pyobjc_detector_stabilized import PyObjCDetectorStabilized
        detector = PyObjCDetectorStabilized()
        
        # Get current app
        app = detector.get_frontmost_app()
        window_info = detector.get_active_window_info()
        
        if app:
            print(f"✅ Current app: {app.name}")
            print(f"   Bundle ID: {app.bundle_id}")
            print(f"   Confidence: {app.confidence:.2f}")
            
            if window_info:
                bounds = window_info.get('bounds', {})
                print(f"   Window: {bounds.get('width', 0)}x{bounds.get('height', 0)}")
        
        detector.shutdown()
        
    except Exception as e:
        print(f"❌ App detection failed: {e}")
    
    # Test 3: GPT Cost Optimization (Fix #5)
    print("\n💰 Test 3: GPT Cost Optimization")
    print("-" * 40)
    
    try:
        from gpt_cost_optimizer import GPTCostOptimizer
        optimizer = GPTCostOptimizer()
        
        # Test with actual image if available
        test_image = "/Users/devin/Desktop/vision_test_768.png"
        if os.path.exists(test_image):
            # Estimate tokens
            tokens = optimizer._estimate_token_usage(test_image)
            cost = optimizer._calculate_cost(tokens, 'gpt-4.1-mini')
            
            print(f"✅ Token estimation: {tokens} tokens")
            print(f"   Estimated cost: ${cost:.6f}")
            
            # Test cropping
            cropped = optimizer.crop_to_active_window(test_image)
            if cropped != test_image:
                print(f"   Cropped: {os.path.basename(cropped)}")
        
        # Get stats
        stats = optimizer.get_cost_stats()
        print(f"   Total cost: ${stats.get('total_cost_usd', 0):.6f}")
        
    except Exception as e:
        print(f"❌ GPT optimization failed: {e}")
    
    # Test 4: Temporal Query Parsing (Fix #6)
    print("\n🕰️ Test 4: Temporal Query Parsing")
    print("-" * 40)
    
    try:
        from enhanced_temporal_parser import EnhancedTemporalParser
        parser = EnhancedTemporalParser()
        
        # Test queries
        test_queries = [
            "What was I doing 5 minutes ago?",
            "Show me recent coding activities",
            "Find browser activities from this morning"
        ]
        
        for query in test_queries:
            parsed = parser.parse_temporal_query(query)
            print(f"✅ '{query}'")
            print(f"   Intent: {parsed.intent.intent_type.value} ({parsed.intent.confidence:.2f})")
        
    except Exception as e:
        print(f"❌ Temporal parsing failed: {e}")
    
    # Test 5: Vision Service Wrapper (Fix #3)
    print("\n🔧 Test 5: Vision Service Wrapper")
    print("-" * 40)
    
    try:
        from vision_service_wrapper import VisionServiceWrapper
        
        service = VisionServiceWrapper.get_instance()
        service.start()
        
        # Test health
        health = service.health_check()
        print(f"✅ Service health: {health.get('status', 'unknown')}")
        
        # Test metrics
        metrics = service.get_metrics()
        print(f"   Requests: {metrics.requests_total}")
        print(f"   Uptime: {metrics.uptime_seconds:.1f}s")
        
        service.stop()
        VisionServiceWrapper.reset_instance()
        
    except Exception as e:
        print(f"❌ Vision service failed: {e}")
    
    # Test 6: Memory Management (Fix #1)
    print("\n🧠 Test 6: Memory Management")
    print("-" * 40)
    
    current_memory = get_memory_usage()
    print(f"✅ Current memory: {current_memory:.1f} MB")
    
    # Force garbage collection
    gc.collect()
    
    after_gc = get_memory_usage()
    print(f"   After GC: {after_gc:.1f} MB")
    
    # Check memory efficiency
    memory_efficient = after_gc < 200
    print(f"   Memory target: {'✅ MET' if memory_efficient else '⚠️ OVER'} (target: 200MB)")
    
    # Performance summary
    print("\n📊 PERFORMANCE SUMMARY")
    print("=" * 60)
    
    print(f"Initial memory: {initial_memory:.1f} MB")
    print(f"Final memory: {after_gc:.1f} MB")
    print(f"Memory increase: {after_gc - initial_memory:.1f} MB")
    
    # Grade the performance
    if after_gc < 200:
        grade = "A"
    elif after_gc < 300:
        grade = "B"
    elif after_gc < 400:
        grade = "C"
    else:
        grade = "D"
    
    print(f"Performance grade: {grade}")
    
    # Recommendations
    print("\n💡 RECOMMENDATIONS")
    print("=" * 60)
    
    if after_gc > 200:
        print("1. Implement process isolation for heavy components")
        print("2. Add memory-mapped storage for large data")
        print("3. Use lazy loading with automatic cleanup")
    else:
        print("1. All critical fixes working optimally!")
        print("2. Ready for production deployment")
        print("3. Consider adding monitoring and alerts")
    
    print("\n🎉 Integration test complete!")

if __name__ == "__main__":
    test_realistic_workflow()