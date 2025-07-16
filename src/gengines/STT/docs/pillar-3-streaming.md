# PILLAR 3: Real-Time WebSocket Streaming (Clueless-style)

## Overview
Replace REST APIs with WebSocket bidirectional streaming for <100ms latency processing.

## What It Does
- Real-time audio/video streaming to AI services
- Bidirectional communication for instant responses
- Eliminates HTTP request overhead
- Enables truly interactive AI experiences

## Current Status: ❌ Not Implemented
- ✅ HTTP REST APIs (current approach)
- ❌ WebSocket server implementation
- ❌ Streaming protocols
- ❌ Real-time bidirectional communication

## Implementation Plan

### 1. WebSocket Server Layer
```python
# websocket_server.py (TODO)
import asyncio
import websockets
import json

class VLAWebSocketServer:
    def __init__(self, port=5004):
        self.port = port
        self.clients = set()
        
    async def handle_client(self, websocket, path):
        """Handle WebSocket client connections"""
        self.clients.add(websocket)
        try:
            async for message in websocket:
                data = json.loads(message)
                await self.process_stream(data, websocket)
        finally:
            self.clients.remove(websocket)
    
    async def process_stream(self, data, websocket):
        """Process streaming data in real-time"""
        if data['type'] == 'audio':
            # Process audio stream
            pass
        elif data['type'] == 'vision':
            # Process vision stream
            pass
```

### 2. Streaming Protocol Design
```python
# Stream Types:
# - Audio chunks (16kHz PCM)
# - Video frames (JPEG compressed)
# - Control messages
# - AI responses

# Message Format:
{
    "type": "audio|vision|control|response",
    "timestamp": 1234567890,
    "data": "base64_encoded_data",
    "metadata": {}
}
```

### 3. Client-Side Streaming (Swift)
```swift
// WebSocketClient.swift (TODO)
import Foundation

class VLAWebSocketClient {
    private var webSocket: URLSessionWebSocketTask?
    
    func connectToServer() {
        let url = URL(string: "ws://localhost:5004")!
        webSocket = URLSession.shared.webSocketTask(with: url)
        webSocket?.resume()
        
        // Start streaming
        streamAudioData()
        streamVideoFrames()
    }
    
    func streamAudioData() {
        // Stream audio chunks as they arrive
    }
    
    func streamVideoFrames() {
        // Stream video frames at target FPS
    }
}
```

## Benefits Over REST
- **Latency**: <100ms vs 300-500ms
- **Efficiency**: No HTTP overhead
- **Real-time**: True streaming, not polling
- **Bidirectional**: Server can push updates

## Use Cases
- Live transcription with instant feedback
- Real-time vision analysis updates
- Continuous AI assistance
- Interactive multimodal experiences

## Integration with Existing Services
- Extend `memory_xpc_server.py` with WebSocket support
- Maintain REST endpoints for compatibility
- Gradual migration to streaming architecture