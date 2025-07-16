# PILLAR 1: Always-On Vision (Cluely-style)

## Overview
Continuous screen monitoring to understand user workflow and activities in real-time.

## What It Does
- Monitors screen continuously (1-2 FPS adaptive)
- Understands user workflow patterns
- Builds activity timeline with context
- Enables temporal queries about past activities

## Current Status: ⚠️ Partially Built
- ✅ ScreenCaptureKit integration (`VisionCaptureManager.swift`)
- ✅ Continuous monitoring service (`continuous_vision_service.py`)
- ✅ GPT-4.1-mini vision analysis
- ✅ Mem0 storage for visual contexts
- ❌ Workflow pattern detection
- ❌ Activity summarization
- ❌ User behavior learning

## Implementation Details

### Current Implementation
```python
# continuous_vision_service.py
class ContinuousVisionService:
    def __init__(self, capture_fps: float = 1.0):
        self.capture_fps = capture_fps
        self.vision_service = VisionService(disable_langfuse=True)
        self.mem0_client = mem0.Memory()
```

### What Needs to Be Added

1. **Workflow Pattern Detection**
```python
def detect_workflow_patterns(self, current_frame, previous_frames):
    """Detect app switches, task changes, user patterns"""
    # TODO: Implement
    # - App switch detection
    # - Task boundary detection
    # - Repetitive action detection
```

2. **Activity Summarization**
```python
def summarize_activity(self, time_window=30):
    """Create high-level summary of user activity"""
    # TODO: Implement
    # - Query recent visual contexts from Mem0
    # - Generate activity summary
    # - Store in activity timeline
```

3. **User Pattern Learning**
```python
def learn_user_patterns(self):
    """Learn and remember user behavior patterns"""
    # TODO: Implement
    # - Common workflows
    # - Time-based patterns
    # - Application usage patterns
```

## Queries This Enables
- "What was I working on before lunch?"
- "Show me all the errors I saw today"
- "When did I last use Excel?"
- "What websites did I visit this morning?"

## Technical Requirements
- Efficient content diffing to detect changes
- Smart caching to avoid redundant processing
- Activity timeline storage in Mem0
- Pattern recognition algorithms

## Performance Targets
- <100ms to detect significant screen changes
- <300ms to analyze and store context
- Minimal CPU/memory overhead
- 24-hour context retention minimum