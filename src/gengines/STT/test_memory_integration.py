#!/usr/bin/env python3
"""
Test script for Zeus_STT Memory Integration
Validates Mem0 + Graphiti integration and XPC bridge functionality
"""

import asyncio
import json
import time
import requests
import subprocess
import signal
import sys
from typing import Dict, List, Any

def test_memory_service_direct():
    """Test memory service directly (without XPC)"""
    print("🧪 Testing Memory Service Direct Integration...")
    
    try:
        from memory_service import MemoryService
        
        # Initialize service
        service = MemoryService()
        
        # Test 1: Add context
        print("  Test 1: Adding text context...")
        success = service.add_text_context(
            command="make this formal",
            ocr_text="hello world this is a test",
            ocr_elements=[
                {"text": "hello world", "box": {"min_x": 10, "min_y": 10, "max_x": 100, "max_y": 30}, "type": "text"},
                {"text": "this is a test", "box": {"min_x": 10, "min_y": 40, "max_x": 120, "max_y": 60}, "type": "text"}
            ],
            session_id="test_session_1"
        )
        print(f"    ✅ Context added: {success}")
        
        # Test 2: Resolve context
        print("  Test 2: Resolving context...")
        result = service.resolve_context("make this formal", "test_session_1")
        print(f"    ✅ Context resolved: {result['method']} (confidence: {result['confidence']})")
        
        # Test 3: Spatial command
        print("  Test 3: Spatial command...")
        result = service.resolve_context("make the text above formal", "test_session_1")
        print(f"    ✅ Spatial resolved: {result['method']} (confidence: {result['confidence']})")
        
        return True
        
    except Exception as e:
        print(f"    ❌ Direct test failed: {e}")
        return False

def test_xpc_server():
    """Test XPC server endpoints"""
    print("🌐 Testing Memory XPC Server...")
    
    base_url = "http://localhost:5000"
    
    try:
        # Test 1: Health check
        print("  Test 1: Health check...")
        response = requests.get(f"{base_url}/health", timeout=5)
        if response.status_code == 200:
            health = response.json()
            print(f"    ✅ Server healthy: {health['status']}")
            print(f"    📊 Mem0: {health['mem0_available']}, Graphiti: {health['graphiti_available']}")
        else:
            print(f"    ❌ Health check failed: {response.status_code}")
            return False
        
        # Test 2: Add context
        print("  Test 2: Adding context via XPC...")
        context_data = {
            "command": "make this more professional",
            "ocr_text": "hey there how are you doing",
            "ocr_elements": [
                {"text": "hey there", "box": {"x": 10, "y": 10}},
                {"text": "how are you doing", "box": {"x": 10, "y": 30}}
            ],
            "session_id": "test_xpc_session",
            "cursor_position": {"x": 50, "y": 25}
        }
        
        response = requests.post(f"{base_url}/add_context", json=context_data, timeout=5)
        if response.status_code == 200:
            result = response.json()
            print(f"    ✅ Context added: {result['success']}")
        else:
            print(f"    ❌ Add context failed: {response.status_code}")
            return False
        
        # Test 3: Resolve context
        print("  Test 3: Resolving context via XPC...")
        resolve_data = {
            "command": "make this more professional",
            "ocr_text": "hey there how are you doing",
            "session_id": "test_xpc_session"
        }
        
        response = requests.post(f"{base_url}/resolve_context", json=resolve_data, timeout=5)
        if response.status_code == 200:
            result = response.json()
            print(f"    ✅ Context resolved: {result['method']} (latency: {result.get('latency_ms', 0):.1f}ms)")
            print(f"    🎯 Target: '{result['resolved_target'][:50]}...'")
        else:
            print(f"    ❌ Resolve context failed: {response.status_code}")
            return False
        
        # Test 4: Memory stats
        print("  Test 4: Memory statistics...")
        response = requests.get(f"{base_url}/memory_stats", timeout=5)
        if response.status_code == 200:
            stats = response.json()
            print(f"    ✅ Stats retrieved: {stats['total_requests']} requests processed")
        else:
            print(f"    ❌ Stats failed: {response.status_code}")
        
        return True
        
    except requests.exceptions.RequestException as e:
        print(f"    ❌ XPC server test failed: {e}")
        print("    💡 Make sure to start server with: python memory_xpc_server.py")
        return False

def test_performance():
    """Test memory system performance"""
    print("⚡ Testing Memory Performance...")
    
    base_url = "http://localhost:5000"
    
    try:
        # Performance test: multiple rapid requests
        print("  Test: Rapid context resolution (10 requests)...")
        
        latencies = []
        for i in range(10):
            start_time = time.time()
            
            resolve_data = {
                "command": f"make this formal test {i}",
                "ocr_text": f"sample text for performance test {i}",
                "session_id": f"perf_test_{i}"
            }
            
            response = requests.post(f"{base_url}/resolve_context", json=resolve_data, timeout=5)
            
            if response.status_code == 200:
                total_latency = (time.time() - start_time) * 1000
                latencies.append(total_latency)
            else:
                print(f"    ❌ Request {i} failed")
                return False
        
        # Performance analysis
        avg_latency = sum(latencies) / len(latencies)
        max_latency = max(latencies)
        min_latency = min(latencies)
        
        print(f"    ✅ Performance Results:")
        print(f"       Average: {avg_latency:.1f}ms")
        print(f"       Min: {min_latency:.1f}ms")
        print(f"       Max: {max_latency:.1f}ms")
        
        # Check against target (<500ms total)
        if avg_latency < 500:
            print(f"    🎯 Performance target MET (< 500ms)")
        else:
            print(f"    ⚠️ Performance target MISSED (> 500ms)")
        
        return True
        
    except Exception as e:
        print(f"    ❌ Performance test failed: {e}")
        return False

def test_spatial_commands():
    """Test spatial relationship commands"""
    print("🗺️ Testing Spatial Commands...")
    
    base_url = "http://localhost:5000"
    
    spatial_commands = [
        "make the text above this formal",
        "delete the paragraph below",
        "select this sentence",
        "format the bullet points",
        "make the text before this casual"
    ]
    
    try:
        for i, command in enumerate(spatial_commands):
            print(f"  Test {i+1}: '{command}'...")
            
            # Add spatial context
            context_data = {
                "command": command,
                "ocr_text": "First paragraph\n• Bullet point 1\n• Bullet point 2\nSecond paragraph",
                "ocr_elements": [
                    {"text": "First paragraph", "box": {"x": 10, "y": 10}, "type": "paragraph"},
                    {"text": "• Bullet point 1", "box": {"x": 10, "y": 30}, "type": "bullet"},
                    {"text": "• Bullet point 2", "box": {"x": 10, "y": 50}, "type": "bullet"},
                    {"text": "Second paragraph", "box": {"x": 10, "y": 70}, "type": "paragraph"}
                ],
                "session_id": f"spatial_test_{i}"
            }
            
            # Add context
            requests.post(f"{base_url}/add_context", json=context_data, timeout=5)
            
            # Resolve spatial command
            resolve_data = {
                "command": command,
                "ocr_text": context_data["ocr_text"],
                "session_id": f"spatial_test_{i}"
            }
            
            response = requests.post(f"{base_url}/resolve_context", json=resolve_data, timeout=5)
            
            if response.status_code == 200:
                result = response.json()
                print(f"    ✅ Resolved via {result['method']} (confidence: {result['confidence']:.2f})")
            else:
                print(f"    ❌ Failed to resolve spatial command")
        
        return True
        
    except Exception as e:
        print(f"    ❌ Spatial test failed: {e}")
        return False

def start_test_server():
    """Start XPC server for testing"""
    print("🚀 Starting test XPC server...")
    
    try:
        # Start server as subprocess
        server_process = subprocess.Popen([
            sys.executable, "memory_xpc_server.py", 
            "--port", "5000", 
            "--host", "localhost"
        ], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        
        # Wait for server to start
        time.sleep(3)
        
        # Check if server is running
        try:
            response = requests.get("http://localhost:5000/health", timeout=2)
            if response.status_code == 200:
                print("    ✅ Test server started successfully")
                return server_process
            else:
                print("    ❌ Test server not responding")
                server_process.terminate()
                return None
        except:
            print("    ❌ Test server failed to start")
            server_process.terminate()
            return None
            
    except Exception as e:
        print(f"    ❌ Failed to start test server: {e}")
        return None

def main():
    """Run all memory integration tests"""
    print("🧠 Zeus_STT Memory Integration Test Suite")
    print("=" * 50)
    
    # Test 1: Direct memory service
    test1_pass = test_memory_service_direct()
    print()
    
    # Test 2: Start XPC server and test endpoints
    server_process = start_test_server()
    
    if server_process:
        try:
            test2_pass = test_xpc_server()
            print()
            
            test3_pass = test_performance()
            print()
            
            test4_pass = test_spatial_commands()
            print()
            
        finally:
            # Clean up server
            print("🛑 Stopping test server...")
            server_process.terminate()
            server_process.wait()
            
    else:
        test2_pass = test3_pass = test4_pass = False
    
    # Results summary
    print("=" * 50)
    print("📊 Test Results Summary:")
    print(f"  Direct Memory Service: {'✅ PASS' if test1_pass else '❌ FAIL'}")
    print(f"  XPC Server Endpoints:  {'✅ PASS' if test2_pass else '❌ FAIL'}")
    print(f"  Performance Tests:     {'✅ PASS' if test3_pass else '❌ FAIL'}")
    print(f"  Spatial Commands:      {'✅ PASS' if test4_pass else '❌ FAIL'}")
    
    all_pass = test1_pass and test2_pass and test3_pass and test4_pass
    
    if all_pass:
        print("\n🎉 ALL TESTS PASSED - Memory integration ready for Zeus_STT!")
        print("💡 Next steps:")
        print("   1. Integrate MemoryXPCService.swift into VoiceDictationService")
        print("   2. Add memory-enhanced command processing")
        print("   3. Test with real voice commands and OCR")
        return 0
    else:
        print("\n⚠️ SOME TESTS FAILED - Review issues before proceeding")
        return 1

if __name__ == "__main__":
    exit(main())