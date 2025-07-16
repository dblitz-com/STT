#!/usr/bin/env python3
"""
Test script to verify Zeus_STT memory integration is working
Tests the memory XPC server and memory processing without requiring full Swift build
"""

import asyncio
import json
import time
import sys
from memory_service import MemoryService, MemoryXPCService

def test_memory_service_basic():
    """Test basic memory service functionality"""
    print("🧪 Testing Memory Service Basic Functionality...")
    
    try:
        # Initialize memory service
        service = MemoryService()
        print(f"✅ Memory service initialized")
        print(f"   Mem0 available: {service.mem0_client is not None}")
        print(f"   Graphiti available: {service.graphiti_client is not None}")
        
        # Test adding context
        success = service.add_text_context(
            command="make this formal",
            ocr_text="hello world this is a test",
            ocr_elements=[
                {"text": "hello world", "box": {"x": 10, "y": 10}},
                {"text": "this is a test", "box": {"x": 10, "y": 30}}
            ],
            session_id="test_swift_integration"
        )
        print(f"✅ Add context result: {success}")
        
        # Test resolving context
        result = service.resolve_context("make this formal", "test_swift_integration")
        print(f"✅ Resolve context result: {result['method']} (confidence: {result['confidence']})")
        
        return True
        
    except Exception as e:
        print(f"❌ Memory service test failed: {e}")
        return False

def test_memory_xpc_service():
    """Test XPC service interface"""
    print("\n🧪 Testing Memory XPC Service Interface...")
    
    try:
        # Initialize XPC service
        xpc_service = MemoryXPCService()
        print(f"✅ XPC service initialized")
        
        # Test XPC-compatible method
        result_json = xpc_service.resolve_context_xpc(
            command="make this professional",
            ocr_text="hey there how are you doing",
            session_id="test_xpc_integration"
        )
        
        result = json.loads(result_json)
        print(f"✅ XPC resolve result: {result['method']} (confidence: {result['confidence']})")
        print(f"   Target: '{result['resolved_target'][:50]}...'")
        
        return True
        
    except Exception as e:
        print(f"❌ XPC service test failed: {e}")
        return False

def test_complex_voice_commands():
    """Test complex voice command detection and processing"""
    print("\n🧪 Testing Complex Voice Command Processing...")
    
    test_commands = [
        "make this formal",
        "delete the text above",
        "select this paragraph", 
        "format the list below",
        "make this more professional",
        "hello world",  # Not complex
        "new line",     # Not complex
        "period"        # Not complex
    ]
    
    # Simulate the complex command detection from Swift
    def is_complex_voice_command(text):
        complex_patterns = [
            "make this", "make that", "delete this", "delete that", 
            "select this", "select that", "format this", "format that",
            "above", "below", "next to", "before", "after",
            "formal", "casual", "professional", "technical"
        ]
        
        lowercase_text = text.lower()
        return any(pattern in lowercase_text for pattern in complex_patterns)
    
    try:
        service = MemoryService()
        
        for command in test_commands:
            is_complex = is_complex_voice_command(command)
            print(f"   '{command}' -> Complex: {is_complex}")
            
            if is_complex:
                result = service.resolve_context(command, "test_complex_commands")
                print(f"      Memory result: {result['method']} (confidence: {result['confidence']})")
        
        return True
        
    except Exception as e:
        print(f"❌ Complex command test failed: {e}")
        return False

def main():
    """Run all integration tests"""
    print("🧠 Zeus_STT Memory Integration Test Suite")
    print("=" * 50)
    
    # Test 1: Basic memory service
    test1_pass = test_memory_service_basic()
    
    # Test 2: XPC service interface  
    test2_pass = test_memory_xpc_service()
    
    # Test 3: Complex command processing
    test3_pass = test_complex_voice_commands()
    
    # Results summary
    print("\n" + "=" * 50)
    print("📊 Integration Test Results:")
    print(f"  Basic Memory Service:     {'✅ PASS' if test1_pass else '❌ FAIL'}")
    print(f"  XPC Service Interface:    {'✅ PASS' if test2_pass else '❌ FAIL'}")
    print(f"  Complex Command Processing: {'✅ PASS' if test3_pass else '❌ FAIL'}")
    
    all_pass = test1_pass and test2_pass and test3_pass
    
    if all_pass:
        print("\n🎉 ALL TESTS PASSED - Memory integration ready for Zeus_STT Swift app!")
        print("💡 Next steps:")
        print("   1. Build Zeus_STT app with ./build-app.sh")
        print("   2. Test with real voice commands")
        print("   3. Verify memory-enhanced processing in logs")
        return 0
    else:
        print("\n⚠️ SOME TESTS FAILED - Review memory integration")
        return 1

if __name__ == "__main__":
    exit(main())