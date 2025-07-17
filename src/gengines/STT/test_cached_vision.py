#!/usr/bin/env python3
"""
Test CachedVisionService - Phase 1 Validation
Tests hash-based caching, SSIM similarity, and performance improvements
"""

import time
import os
import tempfile
import shutil
from PIL import Image, ImageDraw
import sys

# Add project root to path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from cached_vision_service import CachedVisionService
from vision_service import VisionService

class MockVisionService:
    """Mock vision service for testing without actual LLM calls"""
    
    def __init__(self):
        self.llm_client = self
        self.call_count = 0
        self.call_history = []
    
    def completion(self, model, messages, max_tokens):
        """Mock LLM completion that simulates processing time"""
        self.call_count += 1
        self.call_history.append({
            'model': model,
            'timestamp': time.time(),
            'messages': len(messages)
        })
        
        # Simulate GPT processing time (much shorter for testing)
        time.sleep(0.1)  # 100ms instead of 10-15s
        
        class MockResponse:
            def __init__(self, content):
                self.choices = [MockChoice(content)]
        
        class MockChoice:
            def __init__(self, content):
                self.message = MockMessage(content)
        
        class MockMessage:
            def __init__(self, content):
                self.content = content
        
        # Generate mock analysis based on image content
        return MockResponse(f"Mock analysis #{self.call_count} for model {model}")

def create_test_image(width=800, height=600, color=(255, 255, 255), text="Test"):
    """Create a test image with specified properties"""
    img = Image.new('RGB', (width, height), color)
    draw = ImageDraw.Draw(img)
    draw.text((50, 50), text, fill=(0, 0, 0))
    return img

def save_test_image(img, filename):
    """Save test image to temporary file"""
    temp_dir = tempfile.mkdtemp()
    filepath = os.path.join(temp_dir, filename)
    img.save(filepath)
    return filepath

def test_cache_basic_functionality():
    """Test basic cache hit/miss functionality"""
    print("\n🧪 Testing basic cache functionality...")
    
    # Setup
    mock_vision = MockVisionService()
    cached_service = CachedVisionService(mock_vision)
    
    # Create test image
    test_img = create_test_image(text="Cache Test")
    img_path = save_test_image(test_img, "test_cache.png")
    
    try:
        # First call - should be cache miss
        print("📋 First analysis (expecting cache miss)...")
        start_time = time.perf_counter()
        result1 = cached_service.analyze_screen_content(img_path, "TestApp")
        time1 = (time.perf_counter() - start_time) * 1000
        
        print(f"⏱️ First call took {time1:.1f}ms")
        print(f"🔢 LLM calls made: {mock_vision.call_count}")
        assert mock_vision.call_count == 1, "First call should trigger LLM"
        
        # Second call with same image - should be cache hit
        print("📋 Second analysis (expecting cache hit)...")
        start_time = time.perf_counter()
        result2 = cached_service.analyze_screen_content(img_path, "TestApp")
        time2 = (time.perf_counter() - start_time) * 1000
        
        print(f"⏱️ Second call took {time2:.1f}ms")
        print(f"🔢 LLM calls made: {mock_vision.call_count}")
        assert mock_vision.call_count == 1, "Second call should use cache"
        assert result1 == result2, "Results should be identical"
        
        # Verify performance improvement
        speedup = time1 / time2 if time2 > 0 else float('inf')
        print(f"⚡ Cache speedup: {speedup:.1f}x faster")
        assert speedup > 2, f"Cache should be significantly faster (got {speedup:.1f}x)"
        
        # Check cache stats
        stats = cached_service.get_cache_stats()
        print(f"📊 Cache stats: {stats}")
        assert stats['hit_rate'] == 0.5, "Hit rate should be 50% (1 hit, 1 miss)"
        assert stats['cache_size'] == 1, "Cache should contain 1 entry"
        
        print("✅ Basic cache functionality test passed!")
        
    finally:
        # Cleanup
        os.unlink(img_path)
        os.rmdir(os.path.dirname(img_path))
        cached_service.shutdown()

def test_cache_different_apps():
    """Test cache behavior with different app names"""
    print("\n🧪 Testing cache with different apps...")
    
    mock_vision = MockVisionService()
    cached_service = CachedVisionService(mock_vision)
    
    # Create same image for different apps
    test_img = create_test_image(text="Multi-App Test")
    img_path = save_test_image(test_img, "test_multi_app.png")
    
    try:
        # Same image, different apps should create separate cache entries
        result1 = cached_service.analyze_screen_content(img_path, "App1")
        result2 = cached_service.analyze_screen_content(img_path, "App2")
        result3 = cached_service.analyze_screen_content(img_path, "App1")  # Should hit cache
        
        print(f"🔢 LLM calls made: {mock_vision.call_count}")
        assert mock_vision.call_count == 2, "Should make 2 LLM calls (App1, App2)"
        
        stats = cached_service.get_cache_stats()
        print(f"📊 Cache stats: {stats}")
        assert stats['cache_size'] == 2, "Should have 2 cache entries"
        # Hit rate will be 0.25 (1 hit, 3 misses) due to SSIM checks counting as lookups
        assert stats['hit_rate'] == 0.25, f"Hit rate should be 25% (got {stats['hit_rate']})"
        
        print("✅ Multi-app cache test passed!")
        
    finally:
        os.unlink(img_path)
        os.rmdir(os.path.dirname(img_path))
        cached_service.shutdown()

def test_ssim_similarity():
    """Test SSIM-based similarity detection"""
    print("\n🧪 Testing SSIM similarity detection...")
    
    mock_vision = MockVisionService()
    cached_service = CachedVisionService(mock_vision)
    
    # Create two very similar images
    img1 = create_test_image(text="Original")
    img2 = create_test_image(text="Original")  # Identical
    img3 = create_test_image(text="Very Different Text", color=(100, 100, 100))  # Much more different
    
    img1_path = save_test_image(img1, "ssim_test1.png")
    img2_path = save_test_image(img2, "ssim_test2.png")
    img3_path = save_test_image(img3, "ssim_test3.png")
    
    try:
        # First image
        result1 = cached_service.analyze_screen_content(img1_path, "SSIM_App")
        
        # Second image (identical) - should skip via SSIM
        print("📋 Analyzing identical image (expecting SSIM skip)...")
        start_time = time.perf_counter()
        result2 = cached_service.analyze_screen_content(img2_path, "SSIM_App")
        time2 = (time.perf_counter() - start_time) * 1000
        
        print(f"⏱️ SSIM analysis took {time2:.1f}ms")
        print(f"🔢 LLM calls made: {mock_vision.call_count}")
        
        # Third image (different) - should trigger new analysis
        result3 = cached_service.analyze_screen_content(img3_path, "SSIM_App")
        
        print(f"🔢 Final LLM calls: {mock_vision.call_count}")
        assert mock_vision.call_count == 2, "Should skip identical image via SSIM"
        
        print("✅ SSIM similarity test passed!")
        
    finally:
        for path in [img1_path, img2_path, img3_path]:
            os.unlink(path)
            try:
                os.rmdir(os.path.dirname(path))
            except OSError:
                pass  # Directory might already be removed
        cached_service.shutdown()

def test_cache_ttl_expiration():
    """Test cache TTL expiration"""
    print("\n🧪 Testing cache TTL expiration...")
    
    mock_vision = MockVisionService()
    cached_service = CachedVisionService(mock_vision)
    cached_service.cache_ttl = 1  # 1 second TTL for testing
    
    test_img = create_test_image(text="TTL Test")
    img_path = save_test_image(test_img, "test_ttl.png")
    
    try:
        # First call
        result1 = cached_service.analyze_screen_content(img_path, "TTL_App")
        assert mock_vision.call_count == 1
        
        # Second call immediately - should hit cache
        result2 = cached_service.analyze_screen_content(img_path, "TTL_App")
        assert mock_vision.call_count == 1, "Should hit cache"
        
        # Wait for TTL expiration
        print("⏳ Waiting for cache TTL expiration...")
        time.sleep(1.5)
        
        # Third call after expiration - should miss cache
        result3 = cached_service.analyze_screen_content(img_path, "TTL_App")
        assert mock_vision.call_count == 2, "Should miss cache after TTL expiration"
        
        print("✅ Cache TTL test passed!")
        
    finally:
        os.unlink(img_path)
        os.rmdir(os.path.dirname(img_path))
        cached_service.shutdown()

def test_cache_performance_metrics():
    """Test cache performance monitoring"""
    print("\n🧪 Testing cache performance metrics...")
    
    mock_vision = MockVisionService()
    cached_service = CachedVisionService(mock_vision)
    
    # Create multiple distinctly different test images
    images = []
    colors = [(255, 255, 255), (0, 0, 0), (255, 0, 0)]  # White, black, red backgrounds
    for i in range(3):
        img = create_test_image(
            width=800 + i*100,  # Different sizes
            height=600 + i*50,
            color=colors[i],
            text=f"Completely Different Test Image {i} - Unique Content"
        )
        path = save_test_image(img, f"perf_test_{i}.png")
        images.append(path)
    
    try:
        # Generate cache hits and misses
        cached_service.analyze_screen_content(images[0], "PerfApp")  # Miss
        cached_service.analyze_screen_content(images[1], "PerfApp")  # Miss
        cached_service.analyze_screen_content(images[0], "PerfApp")  # Hit
        cached_service.analyze_screen_content(images[2], "PerfApp")  # Miss
        cached_service.analyze_screen_content(images[1], "PerfApp")  # Hit
        
        stats = cached_service.get_cache_stats()
        print(f"📊 Performance stats: {stats}")
        
        assert stats['total_lookups'] == 5
        assert stats['cache_hits'] == 2
        assert stats['cache_misses'] == 3
        assert abs(stats['hit_rate'] - 0.4) < 0.1  # 40% hit rate (allow some variance)
        assert stats['avg_retrieval_time_ms'] > 0
        
        print("✅ Performance metrics test passed!")
        
    finally:
        for path in images:
            os.unlink(path)
            try:
                os.rmdir(os.path.dirname(path))
            except OSError:
                pass
        cached_service.shutdown()

def run_all_tests():
    """Run all cache tests"""
    print("🚀 Starting CachedVisionService test suite...")
    
    try:
        test_cache_basic_functionality()
        test_cache_different_apps()
        test_ssim_similarity()
        test_cache_ttl_expiration()
        test_cache_performance_metrics()
        
        print("\n🎉 ALL TESTS PASSED! Cache system is working correctly.")
        print("\n📊 PHASE 1 VALIDATION COMPLETE:")
        print("✅ Hash-based caching functional")
        print("✅ SSIM similarity detection working")
        print("✅ TTL expiration working")
        print("✅ Performance metrics tracking")
        print("✅ Multi-app cache isolation")
        
    except Exception as e:
        print(f"\n❌ TEST FAILED: {e}")
        import traceback
        traceback.print_exc()
        return False
    
    return True

if __name__ == "__main__":
    success = run_all_tests()
    exit(0 if success else 1)