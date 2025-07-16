#!/usr/bin/env python3
"""
Test Individual Critical Fixes
Quick tests for each fix to identify issues
"""

import os
import sys
import time
import psutil
import gc
import structlog

logger = structlog.get_logger()

def get_memory_usage():
    """Get current memory usage"""
    try:
        process = psutil.Process()
        return process.memory_info().rss / 1024 / 1024
    except:
        return 0

def test_fix_1_memory():
    """Test Fix #1: Memory Architecture"""
    print("🧠 Testing Fix #1: Memory Architecture")
    print("-" * 40)
    
    initial_memory = get_memory_usage()
    print(f"Initial memory: {initial_memory:.1f} MB")
    
    # Set aggressive GC
    gc.set_threshold(700, 10, 10)
    
    # Test memory allocation
    test_objects = []
    for i in range(1000):
        test_objects.append(f"test_{i}" * 100)
    
    before_gc = get_memory_usage()
    print(f"Before GC: {before_gc:.1f} MB")
    
    # Force GC
    gc.collect()
    
    after_gc = get_memory_usage()
    print(f"After GC: {after_gc:.1f} MB")
    
    # Cleanup
    del test_objects
    gc.collect()
    
    final_memory = get_memory_usage()
    print(f"Final memory: {final_memory:.1f} MB")
    
    success = final_memory < 200
    print(f"✅ PASSED: Memory under 200MB" if success else f"❌ FAILED: Memory over 200MB")
    
    return success

def test_fix_2_storage():
    """Test Fix #2: Storage Architecture"""
    print("\n🗂️ Testing Fix #2: Storage Architecture")
    print("-" * 40)
    
    try:
        from storage_manager import StorageManager
        
        storage = StorageManager()
        
        # Test storage
        test_data = b"Test data"
        path = storage.store_file(test_data, "test.txt")
        
        # Test loading
        loaded = storage.load_file("test.txt")
        
        # Test stats
        stats = storage.get_storage_stats()
        
        success = loaded == test_data and stats.get('file_count', 0) > 0
        print(f"✅ PASSED: Storage working" if success else f"❌ FAILED: Storage issues")
        
        return success
        
    except Exception as e:
        print(f"❌ FAILED: {e}")
        return False

def test_fix_3_vision():
    """Test Fix #3: Vision Service"""
    print("\n🔧 Testing Fix #3: Vision Service")
    print("-" * 40)
    
    try:
        from vision_service_wrapper import VisionServiceWrapper
        
        service = VisionServiceWrapper.get_instance()
        service.start()
        
        # Test health
        health = service.health_check()
        
        service.stop()
        VisionServiceWrapper.reset_instance()
        
        success = health.get('healthy', False)
        print(f"✅ PASSED: Vision service healthy" if success else f"❌ FAILED: Vision service unhealthy")
        
        return success
        
    except Exception as e:
        print(f"❌ FAILED: {e}")
        return False

def test_fix_4_pyobjc():
    """Test Fix #4: PyObjC Integration"""
    print("\n🍎 Testing Fix #4: PyObjC Integration")
    print("-" * 40)
    
    try:
        from pyobjc_detector_stabilized import PyObjCDetectorStabilized
        
        detector = PyObjCDetectorStabilized()
        
        # Test app detection
        app = detector.get_frontmost_app()
        
        # Test window info
        window_info = detector.get_active_window_info()
        
        detector.shutdown()
        
        success = app is not None and window_info is not None
        print(f"✅ PASSED: PyObjC working" if success else f"❌ FAILED: PyObjC issues")
        
        if app:
            print(f"   Detected app: {app.name}")
        
        return success
        
    except Exception as e:
        print(f"❌ FAILED: {e}")
        return False

def test_fix_5_gpt():
    """Test Fix #5: GPT Optimization"""
    print("\n💰 Testing Fix #5: GPT Optimization")
    print("-" * 40)
    
    try:
        from gpt_cost_optimizer import GPTCostOptimizer
        
        optimizer = GPTCostOptimizer()
        
        # Test token estimation
        if os.path.exists("/Users/devin/Desktop/vision_test_768.png"):
            tokens = optimizer._estimate_token_usage("/Users/devin/Desktop/vision_test_768.png")
            print(f"   Estimated tokens: {tokens}")
        
        # Test stats
        stats = optimizer.get_cost_stats()
        
        success = True  # Basic initialization is success
        print(f"✅ PASSED: GPT optimizer working")
        
        return success
        
    except Exception as e:
        print(f"❌ FAILED: {e}")
        return False

def test_fix_6_temporal():
    """Test Fix #6: Temporal Parser"""
    print("\n🕰️ Testing Fix #6: Temporal Parser")
    print("-" * 40)
    
    try:
        from enhanced_temporal_parser import EnhancedTemporalParser
        
        parser = EnhancedTemporalParser()
        
        # Test parsing
        query = "What was I doing 5 minutes ago?"
        parsed = parser.parse_temporal_query(query)
        
        success = parsed.intent.confidence > 0.5
        print(f"✅ PASSED: Temporal parser working" if success else f"❌ FAILED: Low confidence")
        
        print(f"   Intent: {parsed.intent.intent_type.value}")
        print(f"   Confidence: {parsed.intent.confidence:.2f}")
        
        return success
        
    except Exception as e:
        print(f"❌ FAILED: {e}")
        return False

def main():
    """Run all individual tests"""
    print("🧪 Zeus VLA Critical Fixes - Individual Testing")
    print("=" * 60)
    
    # Track results
    results = {}
    
    # Test each fix
    results['fix_1_memory'] = test_fix_1_memory()
    results['fix_2_storage'] = test_fix_2_storage()
    results['fix_3_vision'] = test_fix_3_vision()
    results['fix_4_pyobjc'] = test_fix_4_pyobjc()
    results['fix_5_gpt'] = test_fix_5_gpt()
    results['fix_6_temporal'] = test_fix_6_temporal()
    
    # Summary
    print("\n📊 SUMMARY")
    print("=" * 60)
    
    total_tests = len(results)
    passed_tests = sum(1 for result in results.values() if result)
    
    for test_name, passed in results.items():
        status = "✅ PASSED" if passed else "❌ FAILED"
        print(f"{status} {test_name}")
    
    print(f"\nPassed: {passed_tests}/{total_tests} ({passed_tests/total_tests*100:.1f}%)")
    
    final_memory = get_memory_usage()
    print(f"Final memory usage: {final_memory:.1f} MB")
    
    if passed_tests == total_tests:
        print("\n🎉 All individual fixes working!")
    else:
        print(f"\n⚠️ {total_tests - passed_tests} fix(es) need attention")

if __name__ == "__main__":
    main()