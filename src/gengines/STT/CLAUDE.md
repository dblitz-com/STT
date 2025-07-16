# Zeus VLA - Claude Development Notes

## Project Overview  
Open-source Vision Language Action (VLA) system for macOS that maintains **continuous multimodal awareness** - understanding what you see, hear, and do - to enable natural interactions like "what did they say in the meeting?" or "what error was on screen earlier?"

## 🎯 The 4 Pillars of Zeus VLA

### PILLAR 1: Always-On Vision
**Status**: ⚠️ Partially Built | [Details](docs/pillar-1-vision.md)
- ✅ Continuous screen monitoring (1-2 FPS)
- ✅ GPT-4.1-mini analysis via LiteLLM
- ❌ Workflow understanding & pattern detection

### PILLAR 2: System Audio Capture  
**Status**: ❌ Not Implemented | [Details](docs/pillar-2-audio.md)
- ❌ Capture ALL audio (meetings, videos, system sounds)
- ❌ Audio mixing (mic + system)
- ❌ Real-time audio memory

### PILLAR 3: Real-Time Streaming
**Status**: ❌ Not Implemented | [Details](docs/pillar-3-streaming.md)
- ❌ WebSocket bidirectional streaming
- ❌ <100ms latency processing
- ❌ Replace REST with streaming

### PILLAR 4: Deep Analysis
**Status**: ⚠️ Partially Built | [Details](docs/pillar-4-analysis.md)
- ✅ On-demand screen capture
- ❌ Multimodal context aggregation
- ❌ Comprehensive analysis reports

## 🚀 Current Priority: Connect the Pieces!

### What Works (Separately):
- **Vision**: ScreenCaptureKit + continuous monitoring + GPT-4.1-mini
- **Language**: WhisperKit STT + Mem0 memory + command detection
- **Action**: CGEvent text manipulation + universal app support

### What's Missing:
- **processVLACommand()**: The function to unify Vision + Language → Action
- **System Audio**: Only have mic input, need all audio sources
- **WebSockets**: Still using REST APIs (300ms+ latency)
- **Workflow AI**: Vision sees screens but doesn't understand workflows

## 📁 Documentation
- [Competitive Analysis](docs/competitive-analysis.md) - What we learned from Cheating Daddy, Glass, Clueless, Cluely
- [Technical Architecture](docs/technical-architecture.md) - System design, APIs, data flow

## 🛠️ Quick Start

### Build & Run
```bash
# Install dependencies
./setup.sh

# Build development app
./build-dev.sh

# Start services
python memory_xpc_server.py --port 5002
python continuous_vision_service.py
```

### Test Current Features
- **Vision**: Cmd+Shift+V for test capture
- **Memory**: `python test_memory_integration.py`
- **Voice**: Fn key to dictate

## 📊 Implementation Roadmap

### Week 1 (NOW): Foundation
1. Implement `processVLACommand()` in Swift
2. Add system audio capture 
3. Connect vision to workflow understanding

### Week 2: Intelligence
1. WebSocket streaming architecture
2. Multimodal fusion pipeline
3. Activity pattern learning

### Week 3: Experience  
1. Natural temporal queries
2. Proactive assistance
3. <500ms total latency

## 🎯 Success Metrics
- **Latency**: <500ms voice → action (currently unmeasurable - not connected)
- **Accuracy**: >95% vision (✅), >90% context resolution (✅)
- **Privacy**: 100% local option (partial - vision needs cloud)

## 🔗 Key Files
- `Sources/VoiceDictationService.swift` - Main service (needs processVLACommand)
- `continuous_vision_service.py` - Always-on vision
- `memory_xpc_server.py` - Swift-Python bridge
- `vision_service.py` - GPT-4.1-mini integration

---

**Bottom Line**: We have best-in-class components but they're not connected. Once integrated via processVLACommand(), Zeus VLA will be the world's first true multimodal awareness system.