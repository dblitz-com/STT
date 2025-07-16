# PILLAR 1 Research Agent Problem Statement: Always-On Vision Workflow Understanding

## Mission Statement
Create a comprehensive Product Requirements Document (PRD) for implementing **Always-On Vision Workflow Understanding** in Zeus VLA - a system that continuously monitors user screen activity to understand workflow patterns, detect task changes, and build intelligent context for natural language queries about past activities.

## Current Technical Foundation (What We Already Have)

### Existing Architecture
- **Language**: Python 3.11+ with asyncio support
- **Vision Processing**: GPT-4.1-mini via LiteLLM factory (>95% accuracy)
- **Screen Capture**: Native macOS ScreenCaptureKit via Swift bridge
- **Memory Storage**: Mem0 with Qdrant vector database
- **XPC Bridge**: Swift-Python communication via HTTP REST APIs (ports 5002/5003)
- **Image Processing**: 384px height, 80% JPEG quality optimization (Glass-style)
- **Monitoring Service**: `continuous_vision_service.py` with adaptive 1-2 FPS capture

### What Currently Works
```python
# continuous_vision_service.py - EXISTING
class ContinuousVisionService:
    def __init__(self, capture_fps: float = 1.0):
        self.capture_fps = capture_fps
        self.vision_service = VisionService(disable_langfuse=True)
        self.mem0_client = mem0.Memory()
    
    def start_monitoring(self):
        """✅ WORKING: Starts continuous screen capture"""
        
    def _detect_content_change(self, image_path):
        """✅ WORKING: Basic content diffing with confidence scores"""
        
    def _analyze_visual_context(self, image_path):
        """✅ WORKING: GPT-4.1-mini analysis via LiteLLM"""
```

### Integration Points
- **Swift Layer**: `VisionCaptureManager.swift` with ScreenCaptureKit
- **XPC Endpoints**: `/start_continuous_vision`, `/query_visual_context`, `/analyze_spatial_command`
- **Memory Layer**: Mem0 storage with 24h retention policy
- **Voice Integration**: `VoiceDictationService.swift` (awaiting connection)

## The Problem We Need to Solve

### Current Limitations
1. **No Workflow Understanding**: Vision captures screens but doesn't understand user activities
2. **No Pattern Detection**: Can't identify app switches, task changes, or work patterns
3. **No Activity Timeline**: No structured history of what user was doing when
4. **No Learning**: Doesn't learn from user behavior patterns
5. **No Temporal Queries**: Can't answer "what was I working on before lunch?"

### Target Capabilities (Cluely.com-style)
- **Workflow Pattern Detection**: Understand when user switches between tasks
- **Activity Summarization**: Generate 30s activity summaries for context
- **Behavior Learning**: Learn user patterns and predict next actions
- **Temporal Queries**: Answer natural language questions about past activities
- **Proactive Assistance**: Detect frustration patterns and suggest help

## Technical Requirements for PRD

### Core Technology Stack
- **Python 3.11+**: Asyncio, threading, multiprocessing
- **LiteLLM**: GPT-4.1-mini for vision analysis (existing integration)
- **Mem0**: Vector storage with Qdrant backend (existing)
- **ScreenCaptureKit**: macOS native capture (existing Swift bridge)
- **Swift Integration**: XPC HTTP bridge on ports 5002/5003
- **OpenAI API**: For vision analysis (existing account/credits)

### Performance Constraints
- **Latency**: <300ms for workflow detection
- **CPU Usage**: <10% sustained load
- **Memory**: <500MB total footprint
- **Storage**: Efficient context storage with 24h retention
- **FPS**: Adaptive 1-2 FPS based on activity level

### Integration Requirements
- **Existing Services**: Must integrate with `continuous_vision_service.py`
- **XPC Bridge**: Use existing HTTP endpoints, extend as needed
- **Memory Layer**: Store in Mem0 with proper indexing
- **Swift Integration**: Callable from `VoiceDictationService.swift`

## Competitive Analysis Context

### What We Learned from Competitors
- **Cluely.com**: Continuous screen understanding with workflow detection
- **Glass**: On-demand analysis with sophisticated fallbacks
- **Cheating Daddy**: Simple but effective real-time processing
- **Clueless**: Professional UI but no vision capabilities

### Our Differentiators
- **Privacy-First**: Local processing with cloud fallback
- **Persistent Memory**: 24h+ context retention vs session-only
- **Multimodal Integration**: Vision + Audio + Voice unified
- **Direct Action**: CGEvent manipulation vs overlay suggestions

## PRD Requirements Specification

### 1. Technical Architecture
- **System Design**: How workflow detection integrates with existing services
- **API Specifications**: New endpoints needed for workflow queries
- **Data Models**: How to store and query workflow patterns
- **Performance Optimization**: Caching, batching, smart processing

### 2. Core Features
- **Workflow Detection**: Algorithm for identifying task boundaries
- **Activity Summarization**: 30s window summarization logic
- **Pattern Learning**: User behavior learning and prediction
- **Temporal Queries**: Natural language interface for history

### 3. Implementation Plan
- **Phase 1**: Basic workflow detection and storage
- **Phase 2**: Pattern learning and summarization
- **Phase 3**: Natural language query interface
- **Phase 4**: Proactive assistance features

### 4. Success Metrics
- **Accuracy**: >90% workflow boundary detection
- **Latency**: <300ms processing time
- **Memory**: <500MB footprint
- **Query Response**: <200ms for temporal queries

### 5. User Experience
- **Query Examples**: "What was I working on before lunch?"
- **Workflow Understanding**: Detect VS Code → Terminal → Browser patterns
- **Activity Timeline**: Visual representation of user activities
- **Proactive Suggestions**: "You've been stuck on this for 15 minutes, need help?"

## Code Integration Requirements

### Existing Code to Extend
```python
# continuous_vision_service.py - NEEDS THESE ADDITIONS
def detect_workflow_patterns(self, current_frame, previous_frames):
    """TODO: Implement workflow pattern detection"""
    
def summarize_activity(self, time_window=30):
    """TODO: Generate activity summaries"""
    
def learn_user_patterns(self):
    """TODO: Learn and store user behavior patterns"""
    
def query_temporal_context(self, query):
    """TODO: Answer natural language queries about past activities"""
```

### New Files to Create
- `workflow_detector.py`: Core workflow detection logic
- `activity_summarizer.py`: Activity summarization service
- `pattern_learner.py`: User behavior learning
- `temporal_query_engine.py`: Natural language query processing

## Research Agent Instructions

### PRD Scope
Create a comprehensive PRD that includes:
1. **Technical Specifications**: Detailed architecture and integration points
2. **Feature Requirements**: Complete feature breakdown with acceptance criteria
3. **Implementation Roadmap**: Week-by-week development plan
4. **API Design**: Detailed endpoint specifications
5. **Data Models**: Database schema and data flow
6. **Performance Requirements**: Specific metrics and optimization strategies
7. **Testing Strategy**: Unit tests, integration tests, performance tests
8. **User Experience**: Query examples and interaction patterns

### Technical Depth Required
- **Code Examples**: Specific Python implementations
- **Integration Points**: How to connect with existing services
- **Performance Analysis**: Optimization strategies and bottlenecks
- **Error Handling**: Robust error handling and fallback strategies
- **Security**: Privacy considerations and data protection

### Success Criteria
The PRD should enable a developer to:
1. **Zero-shot Implementation**: Build the feature without additional research
2. **Technical Clarity**: Understand all integration points and dependencies
3. **Performance Targets**: Know exact metrics to achieve
4. **Testing Coverage**: Implement comprehensive testing strategy

## Context Files to Reference
- `continuous_vision_service.py`: Current implementation
- `vision_service.py`: GPT-4.1-mini integration
- `memory_service.py`: Mem0 integration patterns
- `docs/pillar-1-vision.md`: Current status and requirements
- `docs/competitive-analysis.md`: Competitor feature analysis
- `docs/technical-architecture.md`: System architecture overview

## Expected Deliverable
A comprehensive PRD document that can be used to implement PILLAR 1: Always-On Vision Workflow Understanding with zero additional research required.