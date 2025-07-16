# Zeus VLA Technical Architecture

## System Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                        Swift Layer                           │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │   Voice     │  │   Vision     │  │  System Audio    │  │
│  │ Dictation   │  │  Capture     │  │    Capture       │  │
│  │  Service    │  │  Manager     │  │   (TODO)         │  │
│  └──────┬──────┘  └──────┬───────┘  └────────┬─────────┘  │
│         │                 │                    │             │
│  ┌──────┴─────────────────┴───────────────────┴─────────┐  │
│  │              MemoryXPCService (Bridge)                │  │
│  └───────────────────────┬───────────────────────────────┘  │
└─────────────────────────────┼───────────────────────────────┘
                              │ XPC/HTTP
┌─────────────────────────────┼───────────────────────────────┐
│                        Python Layer                          │
│  ┌───────────────────────┴───────────────────────────────┐  │
│  │          memory_xpc_server.py (Port 5002/5003)        │  │
│  └───────────────────────┬───────────────────────────────┘  │
│                          │                                   │
│  ┌─────────────┐  ┌──────┴───────┐  ┌──────────────────┐  │
│  │   Memory    │  │   Vision     │  │  Continuous      │  │
│  │  Service    │  │  Service     │  │    Vision        │  │
│  │   (Mem0)    │  │ (GPT-4.1)    │  │   Service        │  │
│  └─────────────┘  └──────────────┘  └──────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Core Components

### Swift Components
1. **VoiceDictationService.swift**
   - Fn key interception
   - WhisperKit integration
   - Command processing
   - ❌ Missing: processVLACommand()

2. **VisionCaptureManager.swift**
   - ScreenCaptureKit integration
   - Image optimization (384px, 80% JPEG)
   - Test infrastructure

3. **MemoryXPCService.swift**
   - Swift-Python bridge
   - <50ms query latency
   - Codable protocol support

4. **SystemAudioCapture.swift** (TODO)
   - AVAudioEngine integration
   - System audio tap
   - Audio mixing pipeline

### Python Components
1. **memory_xpc_server.py**
   - HTTP REST endpoints (ports 5002/5003)
   - Memory operations
   - Vision operations
   - ❌ Missing: WebSocket support

2. **memory_service.py**
   - Mem0 integration
   - Context resolution
   - Spatial relationships

3. **vision_service.py**
   - GPT-4.1-mini via LiteLLM
   - Spatial command analysis
   - >95% accuracy

4. **continuous_vision_service.py**
   - Always-on monitoring
   - Adaptive FPS (1-2)
   - Mem0 storage

## API Endpoints

### Memory Endpoints (Port 5002)
- `POST /add_memory` - Add memory entry
- `POST /search_memory` - Search memories
- `POST /resolve_context` - Resolve references
- `GET /health` - Service health

### Vision Endpoints (Port 5003)
- `POST /start_continuous_vision` - Start monitoring
- `POST /stop_continuous_vision` - Stop monitoring
- `POST /query_visual_context` - Query context
- `POST /analyze_spatial_command` - Analyze command
- `POST /detect_visual_references` - Detect references
- `GET /vision_health` - Vision health

## Data Flow

### Current Flow (Disconnected)
1. Voice → WhisperKit → Text
2. Vision → ScreenCapture → Analysis
3. Memory → Mem0 → Context

### Target VLA Flow
```
Voice Input + Visual Context → processVLACommand() → Multimodal Understanding → Action
     ↓              ↓                    ↓                    ↓                 ↓
  WhisperKit    Continuous          Swift Bridge        Fusion Logic      CGEvent
              Vision Monitor                                              Execution
```

## Performance Metrics

### Achieved
- Memory Query: <50ms
- Vision Analysis: <305ms
- Voice Recognition: <2s
- Text Insertion: <100ms

### Targets
- VLA Pipeline: <500ms end-to-end
- WebSocket Latency: <100ms
- System Audio: Real-time processing
- Deep Analysis: <10s complete

## Code Patterns

### Swift-Python Bridge Pattern
```swift
// Swift side
func queryMemory(text: String) async throws -> MemoryResponse {
    let request = MemoryRequest(text: text)
    return try await xpcService.query(request)
}
```

```python
# Python side
@app.route('/search_memory', methods=['POST'])
def search_memory():
    data = request.json
    results = memory_service.search(data['query'])
    return jsonify(results)
```

### Vision Analysis Pattern
```python
# Continuous monitoring
async def monitor_loop():
    while running:
        frame = capture_screen()
        if significant_change(frame):
            analysis = await analyze_frame(frame)
            store_context(analysis)
```

### Multimodal Fusion Pattern (TODO)
```python
def processVLACommand(voice_input, visual_context):
    # Fuse modalities
    context = fuse_contexts(voice_input, visual_context)
    
    # Understand intent
    intent = understand_multimodal_intent(context)
    
    # Execute action
    return execute_action(intent)
```

## Security & Privacy

1. **Local Processing**
   - WhisperKit (on-device STT)
   - Option for local VLMs
   - No cloud dependency for core features

2. **Data Storage**
   - Mem0 with 24h retention
   - Encrypted at rest
   - User-controlled deletion

3. **Permissions**
   - Accessibility API
   - Screen Recording
   - Input Monitoring
   - Microphone Access

## Development Workflow

### Building
```bash
./build-dev.sh    # Development build
./build-app.sh    # Production build
```

### Testing
```bash
python test_memory_integration.py
python test_vision_capture.swift
```

### Running Services
```bash
# Start memory/vision server
python memory_xpc_server.py --port 5002

# Start continuous vision
python continuous_vision_service.py
```

## Future Architecture Enhancements

1. **Weaviate Integration**
   - Better vector storage
   - Semantic search
   - Scalability

2. **Real Graphiti**
   - True graph relationships
   - Causal reasoning
   - Complex queries

3. **Edge Deployment**
   - Local-only mode
   - Offline capability
   - Privacy-first