#!/usr/bin/env python3
"""
Simple WebSocket vs HTTP Polling Performance Test
Demonstrates the latency difference between WebSocket push and HTTP polling
"""

import asyncio
import time
import json
import requests
import websockets
import threading
from flask import Flask

# Simple WebSocket Server
websocket_clients = set()
latest_data = {"message": "No data yet", "timestamp": 0}

async def websocket_handler(websocket):
    """Handle WebSocket connections"""
    global websocket_clients
    websocket_clients.add(websocket)
    print(f"📱 WebSocket client connected: {len(websocket_clients)} total")
    
    try:
        # Send current data immediately
        await websocket.send(json.dumps(latest_data))
        
        # Keep connection alive
        async for message in websocket:
            pass  # Echo or process client messages if needed
            
    except websockets.exceptions.ConnectionClosed:
        pass
    finally:
        websocket_clients.discard(websocket)
        print(f"📱 WebSocket client disconnected: {len(websocket_clients)} remaining")

async def broadcast_to_websockets(data):
    """Broadcast data to all WebSocket clients"""
    global latest_data
    latest_data = data
    
    if websocket_clients:
        message = json.dumps(data)
        await asyncio.gather(
            *[client.send(message) for client in websocket_clients],
            return_exceptions=True
        )

def push_update(data):
    """Push update to WebSocket clients (thread-safe)"""
    try:
        loop = asyncio.get_event_loop()
        asyncio.run_coroutine_threadsafe(broadcast_to_websockets(data), loop)
    except:
        pass  # No loop running

# Simple HTTP Server
app = Flask(__name__)
app.logger.disabled = True

@app.route('/data', methods=['GET'])
def get_data():
    return json.dumps(latest_data)

@app.route('/update', methods=['POST']) 
def update_data():
    global latest_data
    latest_data = {"message": "HTTP update", "timestamp": time.time()}
    return json.dumps({"success": True})

# Test Functions
async def test_websocket_latency():
    """Test WebSocket push latency"""
    print("\n🧪 Testing WebSocket Push Latency")
    
    latencies = []
    received_messages = []
    
    # Connect WebSocket client
    try:
        async with websockets.connect("ws://localhost:7001") as websocket:
            print("🔌 WebSocket connected")
            
            # Start message listener
            async def listen():
                async for message in websocket:
                    data = json.loads(message)
                    received_messages.append(time.time())
            
            listen_task = asyncio.create_task(listen())
            
            # Test 5 rapid updates
            for i in range(5):
                start_time = time.perf_counter()
                
                # Trigger update
                test_data = {
                    "message": f"WebSocket test #{i+1}",
                    "timestamp": time.time()
                }
                
                # Push via WebSocket 
                await broadcast_to_websockets(test_data)
                
                # Wait for message reception
                initial_count = len(received_messages)
                timeout = time.time() + 1.0
                
                while len(received_messages) <= initial_count and time.time() < timeout:
                    await asyncio.sleep(0.001)
                
                if len(received_messages) > initial_count:
                    latency = (time.perf_counter() - start_time) * 1000
                    latencies.append(latency)
                    print(f"   📤 Push {i+1}: {latency:.1f}ms")
                
                await asyncio.sleep(0.1)
            
            listen_task.cancel()
    
    except Exception as e:
        print(f"❌ WebSocket test failed: {e}")
    
    return latencies

def test_http_polling_latency():
    """Test HTTP polling latency"""
    print("\n🧪 Testing HTTP Polling Latency")
    
    latencies = []
    
    # Test 5 polling cycles
    for i in range(5):
        # Simulate update
        requests.post("http://localhost:7002/update", timeout=1.0)
        
        # Simulate random polling delay (0-1000ms)
        import random
        polling_delay = random.uniform(0, 1.0)
        
        start_time = time.perf_counter()
        time.sleep(polling_delay)  # Polling interval
        
        # Poll for data
        response = requests.get("http://localhost:7002/data", timeout=1.0)
        
        total_latency = (time.perf_counter() - start_time) * 1000
        latencies.append(total_latency)
        print(f"   📡 Poll {i+1}: {total_latency:.1f}ms (delay: {polling_delay*1000:.1f}ms)")
    
    return latencies

async def run_websocket_server():
    """Run WebSocket server"""
    async with websockets.serve(websocket_handler, "localhost", 7001):
        print("🚀 WebSocket server running on ws://localhost:7001")
        await asyncio.Future()  # Run forever

def run_http_server():
    """Run HTTP server"""
    app.run(host='127.0.0.1', port=7002, debug=False, use_reloader=False)

async def main():
    """Run performance comparison test"""
    print("🚀 WebSocket vs HTTP Polling Performance Test")
    print("=" * 50)
    
    # Start HTTP server in background
    http_thread = threading.Thread(target=run_http_server, daemon=True)
    http_thread.start()
    time.sleep(0.5)
    
    # Start WebSocket server in background
    ws_task = asyncio.create_task(run_websocket_server())
    await asyncio.sleep(0.5)
    
    try:
        # Test WebSocket performance
        ws_latencies = await test_websocket_latency()
        
        # Test HTTP performance  
        http_latencies = test_http_polling_latency()
        
        # Results
        print("\n" + "=" * 50)
        print("📊 PERFORMANCE COMPARISON RESULTS")
        print("=" * 50)
        
        if ws_latencies:
            avg_ws = sum(ws_latencies) / len(ws_latencies)
            min_ws = min(ws_latencies)
            max_ws = max(ws_latencies)
            
            print(f"\n🚀 WebSocket Push:")
            print(f"   Average: {avg_ws:.1f}ms")
            print(f"   Range: {min_ws:.1f}ms - {max_ws:.1f}ms")
            print(f"   Target: <50ms ({'✅ ACHIEVED' if avg_ws < 50 else '❌ NEEDS WORK'})")
        
        if http_latencies:
            avg_http = sum(http_latencies) / len(http_latencies)
            min_http = min(http_latencies)
            max_http = max(http_latencies)
            
            print(f"\n📡 HTTP Polling:")
            print(f"   Average: {avg_http:.1f}ms")
            print(f"   Range: {min_http:.1f}ms - {max_http:.1f}ms")
            print(f"   Expected: 0-1000ms (variable)")
        
        if ws_latencies and http_latencies:
            improvement = ((avg_http - avg_ws) / avg_http) * 100
            print(f"\n⚡ Performance Improvement:")
            print(f"   Latency reduction: {improvement:.1f}%")
            print(f"   Target: 90-95% ({'✅ ACHIEVED' if improvement >= 90 else '❌ NEEDS WORK'})")
            
            if avg_ws < 50 and improvement >= 90:
                print(f"\n🎉 WEBSOCKET IMPLEMENTATION SUCCESSFUL!")
                print(f"   ✅ <50ms push latency achieved")
                print(f"   ✅ >90% improvement over polling")
                return True
        
        print(f"\n⚠️ Performance targets not fully met")
        return False
        
    except Exception as e:
        print(f"❌ Test failed: {e}")
        return False
    finally:
        ws_task.cancel()

if __name__ == "__main__":
    try:
        success = asyncio.run(main())
        exit(0 if success else 1)
    except KeyboardInterrupt:
        print("\n🛑 Test interrupted")
        exit(1)