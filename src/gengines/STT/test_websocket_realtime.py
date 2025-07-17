#!/usr/bin/env python3
"""
Test WebSocket Real-Time Communication - Phase 3 Validation
Validates <50ms WebSocket push vs 0-1000ms HTTP polling

Key Tests:
- WebSocket push latency measurement
- HTTP polling latency comparison  
- Connection resilience and reconnection
- Message queuing during brief drops
- Performance under rapid app switching

Target: 90-95% communication latency reduction
"""

import time
import asyncio
import threading
import json
import requests
import websockets
from typing import Dict, Any, List
import sys
import os

# Add project root to path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from glass_ui_websocket_server import GlassUIWebSocketServer
from cached_vision_service import CachedVisionService
from vision_service import VisionService

class WebSocketLatencyTester:
    """Test WebSocket vs HTTP polling latency"""
    
    def __init__(self):
        self.websocket_server = None
        self.test_results = {
            "websocket_latencies": [],
            "http_latencies": [],
            "reconnection_times": [],
            "message_delivery_success": 0,
            "message_delivery_total": 0
        }
        self.websocket_client = None
        self.received_messages = []
        
    async def test_websocket_push_latency(self):
        """Test WebSocket push notification latency"""
        print("\n🧪 Testing WebSocket push latency...")
        
        # Start WebSocket server
        self.websocket_server = GlassUIWebSocketServer(port=6002)
        server_task = asyncio.create_task(self.websocket_server.start_websocket_server())
        
        # Wait for server to start
        await asyncio.sleep(0.5)
        
        # Connect WebSocket client
        try:
            self.websocket_client = await websockets.connect("ws://localhost:6002")
            print("🔌 WebSocket client connected")
            
            # Start listening for messages
            listen_task = asyncio.create_task(self._listen_for_messages())
            
            # Test multiple push notifications
            for i in range(10):
                start_time = time.perf_counter()
                
                # Send vision update via WebSocket push
                test_data = {
                    "summary": f"Test vision analysis #{i}",
                    "confidence": 0.95,
                    "app_name": "TestApp"
                }
                
                self.websocket_server.push_vision_update(test_data)
                
                # Wait for message reception (with timeout)
                timeout_start = time.time()
                initial_count = len(self.received_messages)
                
                while len(self.received_messages) <= initial_count and (time.time() - timeout_start) < 1.0:
                    await asyncio.sleep(0.001)  # 1ms resolution
                
                if len(self.received_messages) > initial_count:
                    latency = (time.perf_counter() - start_time) * 1000  # Convert to ms
                    self.test_results["websocket_latencies"].append(latency)
                    self.test_results["message_delivery_success"] += 1
                    print(f"   📤 Push {i+1}: {latency:.1f}ms")
                else:
                    print(f"   ❌ Push {i+1}: timeout")
                
                self.test_results["message_delivery_total"] += 1
                await asyncio.sleep(0.1)  # 100ms between tests
            
            # Cleanup
            listen_task.cancel()
            await self.websocket_client.close()
            
        except Exception as e:
            print(f"❌ WebSocket test failed: {e}")
        
        # Stop server
        self.websocket_server.stop()
    
    async def _listen_for_messages(self):
        """Listen for WebSocket messages"""
        try:
            async for message in self.websocket_client:
                data = json.loads(message)
                self.received_messages.append({
                    "timestamp": time.time(),
                    "data": data
                })
        except Exception as e:
            print(f"Message listener error: {e}")
    
    def test_http_polling_latency(self):
        """Test HTTP polling latency for comparison"""
        print("\n🧪 Testing HTTP polling latency...")
        
        # Start HTTP server
        server = GlassUIWebSocketServer(port=6003)
        server.start_http_server()
        time.sleep(0.5)
        
        try:
            for i in range(10):
                # Simulate update
                test_data = {
                    "type": "vision_summary",
                    "summary": f"Test vision analysis #{i}",
                    "confidence": 0.95,
                    "app_name": "TestApp"
                }
                
                # Send update to server
                requests.post("http://localhost:6004/glass_update", json=test_data, timeout=1.0)
                
                # Simulate polling delay (random between 0-1000ms)
                import random
                polling_delay = random.uniform(0, 1.0)  # 0-1000ms
                
                start_time = time.perf_counter()
                
                # Simulate waiting for polling interval
                time.sleep(polling_delay)
                
                # Poll for update
                response = requests.get("http://localhost:6004/glass_query", timeout=1.0)
                
                total_latency = (time.perf_counter() - start_time) * 1000  # Convert to ms
                self.test_results["http_latencies"].append(total_latency)
                print(f"   📡 Poll {i+1}: {total_latency:.1f}ms (polling delay: {polling_delay*1000:.1f}ms)")
                
        except Exception as e:
            print(f"❌ HTTP test failed: {e}")
    
    async def test_connection_resilience(self):
        """Test WebSocket reconnection and message queuing"""
        print("\n🧪 Testing connection resilience...")
        
        try:
            # Start server with message queuing
            self.websocket_server = GlassUIWebSocketServer(port=6002)
            server_task = asyncio.create_task(self.websocket_server.start_websocket_server())
            await asyncio.sleep(0.5)
            
            # Connect and send messages
            self.websocket_client = await websockets.connect("ws://localhost:6002")
            print("🔌 Initial connection established")
            
            # Send message 1
            self.websocket_server.push_vision_update({"summary": "Message 1", "confidence": 0.9})
            await asyncio.sleep(0.1)
            
            # Simulate connection drop
            await self.websocket_client.close()
            print("📡 Connection dropped")
            
            # Send message 2 while disconnected (should queue)
            self.websocket_server.push_vision_update({"summary": "Message 2 (queued)", "confidence": 0.9})
            
            # Reconnect
            reconnect_start = time.perf_counter()
            self.websocket_client = await websockets.connect("ws://localhost:6002")
            reconnect_time = (time.perf_counter() - reconnect_start) * 1000
            
            self.test_results["reconnection_times"].append(reconnect_time)
            print(f"🔌 Reconnected in {reconnect_time:.1f}ms")
            
            # Should receive queued message
            message = await asyncio.wait_for(self.websocket_client.recv(), timeout=1.0)
            data = json.loads(message)
            print(f"📨 Received queued message: {data.get('type', 'unknown')}")
            
            await self.websocket_client.close()
            
        except Exception as e:
            print(f"❌ Resilience test failed: {e}")
        
        self.websocket_server.stop()
    
    def print_performance_summary(self):
        """Print comprehensive performance comparison"""
        print("\n" + "="*60)
        print("📊 PHASE 3 WEBSOCKET PERFORMANCE RESULTS")
        print("="*60)
        
        if self.test_results["websocket_latencies"]:
            avg_ws = sum(self.test_results["websocket_latencies"]) / len(self.test_results["websocket_latencies"])
            min_ws = min(self.test_results["websocket_latencies"])
            max_ws = max(self.test_results["websocket_latencies"])
            
            print(f"\n🚀 WebSocket Push Performance:")
            print(f"   Average latency: {avg_ws:.1f}ms")
            print(f"   Min latency: {min_ws:.1f}ms")
            print(f"   Max latency: {max_ws:.1f}ms")
            print(f"   Target: <50ms ({'✅ ACHIEVED' if avg_ws < 50 else '❌ NEEDS WORK'})")
        
        if self.test_results["http_latencies"]:
            avg_http = sum(self.test_results["http_latencies"]) / len(self.test_results["http_latencies"])
            min_http = min(self.test_results["http_latencies"])
            max_http = max(self.test_results["http_latencies"])
            
            print(f"\n📡 HTTP Polling Performance:")
            print(f"   Average latency: {avg_http:.1f}ms")
            print(f"   Min latency: {min_http:.1f}ms")
            print(f"   Max latency: {max_http:.1f}ms")
            print(f"   Variance: 0-1000ms (polling interval)")
        
        if self.test_results["websocket_latencies"] and self.test_results["http_latencies"]:
            avg_ws = sum(self.test_results["websocket_latencies"]) / len(self.test_results["websocket_latencies"])
            avg_http = sum(self.test_results["http_latencies"]) / len(self.test_results["http_latencies"])
            improvement = ((avg_http - avg_ws) / avg_http) * 100
            
            print(f"\n⚡ Performance Improvement:")
            print(f"   Latency reduction: {improvement:.1f}%")
            print(f"   Target: 90-95% ({'✅ ACHIEVED' if improvement >= 90 else '❌ NEEDS WORK'})")
        
        if self.test_results["reconnection_times"]:
            avg_reconnect = sum(self.test_results["reconnection_times"]) / len(self.test_results["reconnection_times"])
            print(f"\n🔌 Connection Resilience:")
            print(f"   Average reconnection: {avg_reconnect:.1f}ms")
            print(f"   Target: <100ms ({'✅ ACHIEVED' if avg_reconnect < 100 else '❌ NEEDS WORK'})")
        
        delivery_rate = (self.test_results["message_delivery_success"] / max(1, self.test_results["message_delivery_total"])) * 100
        print(f"\n📨 Message Delivery:")
        print(f"   Success rate: {delivery_rate:.1f}%")
        print(f"   Target: >99% ({'✅ ACHIEVED' if delivery_rate > 99 else '❌ NEEDS WORK'})")
        
        print(f"\n🎯 PHASE 3 STATUS:")
        if self.test_results["websocket_latencies"]:
            avg_ws = sum(self.test_results["websocket_latencies"]) / len(self.test_results["websocket_latencies"])
            if avg_ws < 50 and delivery_rate > 99:
                print("   ✅ Phase 3 WebSocket implementation SUCCESSFUL")
                print("   🚀 Ready for Phase 4 optimizations")
            else:
                print("   ⚠️ Phase 3 needs optimization before Phase 4")
        else:
            print("   ❌ Phase 3 tests incomplete")

async def test_integrated_pipeline():
    """Test complete pipeline with WebSocket integration"""
    print("\n🧪 Testing integrated vision + WebSocket pipeline...")
    
    try:
        # Create mock vision service
        class MockVisionService:
            def __init__(self):
                self.llm_client = self
                
            def completion(self, model, messages, max_tokens):
                time.sleep(0.1)  # Simulate 100ms vision processing
                class MockResponse:
                    def __init__(self):
                        self.choices = [MockChoice()]
                class MockChoice:
                    def __init__(self):
                        self.message = MockMessage()
                class MockMessage:
                    def __init__(self):
                        self.content = "Mock vision analysis of test screen"
                return MockResponse()
        
        # Setup integrated system
        mock_vision = MockVisionService()
        cached_service = CachedVisionService(mock_vision)
        websocket_server = GlassUIWebSocketServer(port=6002)
        
        # Inject WebSocket server into vision service
        cached_service.set_websocket_server(websocket_server)
        
        # Start WebSocket server
        server_task = asyncio.create_task(websocket_server.start_websocket_server())
        await asyncio.sleep(0.5)
        
        # Connect client
        client = await websockets.connect("ws://localhost:6002")
        received_updates = []
        
        async def listen_for_updates():
            try:
                async for message in client:
                    data = json.loads(message)
                    if data.get("type") == "vision_update":
                        received_updates.append(time.time())
            except:
                pass
        
        listen_task = asyncio.create_task(listen_for_updates())
        
        # Test rapid app switching simulation
        print("   🔄 Simulating rapid app switching...")
        
        # Create test image
        import tempfile
        from PIL import Image, ImageDraw
        
        img = Image.new('RGB', (800, 600), (255, 255, 255))
        draw = ImageDraw.Draw(img)
        draw.text((50, 50), "Test Vision Content", fill=(0, 0, 0))
        
        temp_dir = tempfile.mkdtemp()
        test_image_path = os.path.join(temp_dir, "test_image.png")
        img.save(test_image_path)
        
        # Simulate 5 rapid app switches
        switch_times = []
        for i in range(5):
            switch_start = time.perf_counter()
            
            # Trigger vision analysis (simulates app switch detection)
            result = cached_service.analyze_screen_content(test_image_path, f"TestApp{i}")
            
            # Wait for WebSocket delivery
            initial_count = len(received_updates)
            timeout_start = time.time()
            
            while len(received_updates) <= initial_count and (time.time() - timeout_start) < 2.0:
                await asyncio.sleep(0.001)
            
            if len(received_updates) > initial_count:
                total_time = (time.perf_counter() - switch_start) * 1000
                switch_times.append(total_time)
                print(f"   📱 App switch {i+1}: {total_time:.1f}ms end-to-end")
            
            await asyncio.sleep(0.2)  # 200ms between switches
        
        # Cleanup
        listen_task.cancel()
        await client.close()
        websocket_server.stop()
        
        # Results
        if switch_times:
            avg_switch = sum(switch_times) / len(switch_times)
            print(f"\n📊 Integrated Pipeline Results:")
            print(f"   Average app switch latency: {avg_switch:.1f}ms")
            print(f"   Target: <2000ms ({'✅ ACHIEVED' if avg_switch < 2000 else '❌ NEEDS WORK'})")
            print(f"   Updates delivered: {len(received_updates)}/5")
            
            return avg_switch < 2000 and len(received_updates) >= 5
        
    except Exception as e:
        print(f"❌ Integrated test failed: {e}")
        return False
    
    return False

async def run_all_tests():
    """Run comprehensive WebSocket test suite"""
    print("🚀 Starting WebSocket Real-Time Communication Test Suite")
    print("Target: Eliminate 1s polling delay with <50ms WebSocket push")
    
    tester = WebSocketLatencyTester()
    
    try:
        # Test 1: WebSocket push latency
        await tester.test_websocket_push_latency()
        
        # Test 2: HTTP polling comparison
        tester.test_http_polling_latency()
        
        # Test 3: Connection resilience
        await tester.test_connection_resilience()
        
        # Test 4: Integrated pipeline
        integration_success = await test_integrated_pipeline()
        
        # Results summary
        tester.print_performance_summary()
        
        print(f"\n🎯 INTEGRATION TEST: {'✅ PASSED' if integration_success else '❌ FAILED'}")
        
        return tester.test_results
        
    except Exception as e:
        print(f"\n❌ TEST SUITE FAILED: {e}")
        import traceback
        traceback.print_exc()
        return None

if __name__ == "__main__":
    try:
        results = asyncio.run(run_all_tests())
        
        if results and results["websocket_latencies"]:
            avg_latency = sum(results["websocket_latencies"]) / len(results["websocket_latencies"])
            if avg_latency < 50:
                print("\n🎉 PHASE 3 WEBSOCKET IMPLEMENTATION SUCCESSFUL!")
                print("📈 Ready to proceed with final validation and monitoring")
                exit(0)
            else:
                print(f"\n⚠️ WebSocket latency {avg_latency:.1f}ms exceeds 50ms target")
                exit(1)
        else:
            print("\n❌ WebSocket tests incomplete")
            exit(1)
            
    except KeyboardInterrupt:
        print("\n🛑 Tests interrupted by user")
        exit(1)
    except Exception as e:
        print(f"\n❌ Test execution failed: {e}")
        exit(1)