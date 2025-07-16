# PILLAR 1 Critical Fixes Research Prompt: Performance & Accuracy Optimization

## Mission Statement
Generate extremely detailed technical implementation specifications for critical performance and accuracy fixes to the existing PILLAR 1: Always-On Vision Workflow Understanding system. These fixes must be production-ready and enable zero-shot implementation without additional research.

## Current System Architecture (What We Have)

### Existing Implementation
```python
# continuous_vision_service.py - CURRENT IMPLEMENTATION
class ContinuousVisionService:
    def __init__(self, capture_fps: float = 1.0):
        self.capture_fps = capture_fps
        self.vision_service = VisionService(disable_langfuse=True)  # GPT-4.1-mini
        self.mem0_client = mem0.Memory.from_config(weaviate_config)
        self.activity_deque = deque(maxlen=30)  # 30s sliding window
        self.transition_history = deque(maxlen=1000)
        
    def _monitor_loop(self):
        """Currently calls GPT-4.1-mini on EVERY frame change > 0.2 confidence"""
        
    def _detect_app_context(self):
        """Currently uses basic osascript + keyword matching (~70% accuracy)"""
        
    def detect_workflow_patterns(self):
        """Currently only detects app switches, not task boundaries"""
        
    def query_temporal_context(self):
        """Currently uses basic NLTK parsing (~60-70% accuracy)"""
```

### Current Performance Issues
- **GPT-4.1-mini calls**: ~60-100/hour = $0.30-0.50/hour cost
- **Memory usage**: ~500MB and growing with context storage
- **App detection**: Basic keyword matching = ~70% accuracy
- **Workflow detection**: Only app switching, no task boundaries
- **Query accuracy**: NLTK parsing = ~60-70% temporal accuracy

### Technology Stack
- **Language**: Python 3.11+ with asyncio
- **Vision**: GPT-4.1-mini via LiteLLM (keep this - it's cheaper)
- **Storage**: Mem0 + Weaviate + Neo4j
- **Platform**: macOS with ScreenCaptureKit
- **Existing dependencies**: opencv-python, scikit-image, nltk, dateutil

## Critical Fix #1: Performance Optimization - Reduce GPT Calls by 80%

### Problem Statement
Currently calling GPT-4.1-mini on every frame change >0.2 confidence. Need to reduce calls by 80% while maintaining accuracy.

### Technical Requirements

#### Intelligent GPT Call Batching
- **Batch Size Algorithm**: How to determine optimal batch size for screen changes
- **Frame Aggregation**: Method to combine multiple frames into single GPT call
- **Change Significance**: Algorithm to identify truly significant changes vs noise
- **Temporal Batching**: How to batch changes over time windows

#### Smart Caching System
- **Cache Key Generation**: How to create effective cache keys for similar screens
- **Cache Invalidation**: When to invalidate cached analysis results
- **Similarity Matching**: Algorithm to match new screens with cached results
- **Cache Size Management**: Optimal cache size and eviction policies

#### Adaptive Processing
- **Activity Level Detection**: How to detect user activity level and adjust processing
- **Quiet Period Optimization**: Reduce processing during inactive periods
- **Burst Processing**: Handle high-activity periods efficiently
- **Dynamic FPS Adjustment**: Algorithm to adjust capture rate based on activity

### Implementation Requirements
```python
# NEED DETAILED IMPLEMENTATION FOR:
class OptimizedVisionService:
    def __init__(self):
        self.gpt_call_cache = {}  # How to structure this?
        self.batch_buffer = []   # How to batch frames?
        self.activity_detector = None  # How to detect activity?
    
    def should_call_gpt(self, frame_change_data) -> bool:
        """Algorithm to decide when GPT call is necessary"""
        pass
    
    def batch_process_frames(self, frames_batch) -> Dict:
        """Process multiple frames in single GPT call"""
        pass
    
    def get_cached_analysis(self, frame_key) -> Optional[Dict]:
        """Retrieve cached analysis for similar frames"""
        pass
```

## Critical Fix #2: Accurate App Detection - Use macOS APIs

### Problem Statement
Current keyword matching from osascript achieves ~70% accuracy. Need >90% accuracy using native macOS APIs.

### Technical Requirements

#### Native macOS Window Detection
- **Accessibility API**: How to use macOS Accessibility API for window detection
- **Core Graphics**: Window information extraction using Core Graphics
- **Application Services**: Process and application identification
- **Window Hierarchy**: Understanding window relationships and focus

#### Advanced App Context Extraction
- **Process Information**: Extract detailed process metadata
- **Window Titles**: Parse window titles for context clues
- **File Paths**: Extract current file/document paths when available
- **URL Detection**: Detect current URLs in browsers
- **Project Context**: Identify project/workspace from window information

#### Integration with Python
- **PyObjC Integration**: How to call macOS APIs from Python
- **Swift Bridge**: Alternative Swift-based detection with XPC calls
- **Performance Optimization**: Efficient API calls without blocking
- **Error Handling**: Robust handling of API failures

### Implementation Requirements
```python
# NEED DETAILED IMPLEMENTATION FOR:
class MacOSAppDetector:
    def __init__(self):
        # How to initialize macOS APIs?
        pass
    
    def get_active_window_info(self) -> Dict:
        """Get detailed active window information"""
        pass
    
    def get_application_context(self, window_info) -> Dict:
        """Extract application context from window info"""
        pass
    
    def detect_file_context(self, app_info) -> Optional[str]:
        """Detect current file/document being worked on"""
        pass
    
    def classify_activity_type(self, app_info, window_info) -> str:
        """Classify type of activity within application"""
        pass
```

## Critical Fix #3: Real Workflow Detection - Task Boundaries

### Problem Statement
Currently only detects app switches. Need to detect task boundaries within applications (coding → debugging → testing).

### Technical Requirements

#### Intra-Application Task Detection
- **Code Editor States**: Detect editing vs debugging vs testing in IDEs
- **Browser Context**: Detect research vs development vs communication
- **Terminal Activities**: Detect different command types and purposes
- **Document States**: Detect writing vs reviewing vs formatting

#### Context-Aware Analysis
- **File Type Detection**: Understand file extensions and content types
- **Code Analysis**: Basic code context understanding from screen content
- **UI State Recognition**: Detect IDE panels, browser tabs, terminal states
- **Action Sequence Analysis**: Pattern recognition for task sequences

#### Task Boundary Algorithms
- **Transition Detection**: Algorithm to identify meaningful task transitions
- **Context Switching**: Detect when user switches between different types of work
- **Focus Duration**: Track how long user stays in specific task contexts
- **Task Completion**: Identify when tasks are completed vs interrupted

### Implementation Requirements
```python
# NEED DETAILED IMPLEMENTATION FOR:
class WorkflowTaskDetector:
    def __init__(self):
        self.task_patterns = {}  # How to define task patterns?
        self.context_analyzer = None  # How to analyze context?
    
    def detect_task_boundaries(self, screen_analysis, app_context) -> Dict:
        """Detect when user switches between different tasks"""
        pass
    
    def classify_task_type(self, app_context, screen_content) -> str:
        """Classify specific type of task being performed"""
        pass
    
    def analyze_code_context(self, screen_content) -> Dict:
        """Extract code context from screen content"""
        pass
    
    def detect_focus_patterns(self, activity_history) -> Dict:
        """Identify patterns in user focus and task switching"""
        pass
```

## Critical Fix #4: Memory Optimization - Reduce to <200MB

### Problem Statement
Current system uses ~500MB and growing. Need to reduce to <200MB sustained usage.

### Technical Requirements

#### Efficient Data Structures
- **Compressed Storage**: How to compress visual context data
- **Memory-Mapped Storage**: Use memory-mapped files for large datasets
- **Lazy Loading**: Load data on-demand rather than keeping in memory
- **Circular Buffers**: Efficient circular buffer implementations

#### Smart Data Retention
- **Retention Policies**: Algorithm to determine what data to keep vs discard
- **Data Compression**: Techniques to compress stored contexts
- **Incremental Updates**: Store only changes rather than full contexts
- **Background Cleanup**: Automatic cleanup of old/unused data

#### Resource Management
- **Memory Monitoring**: Track memory usage in real-time
- **Garbage Collection**: Optimize Python GC for large datasets
- **Resource Limits**: Implement hard limits on memory usage
- **Graceful Degradation**: Behavior when approaching memory limits

### Implementation Requirements
```python
# NEED DETAILED IMPLEMENTATION FOR:
class MemoryOptimizedStorage:
    def __init__(self, max_memory_mb: int = 200):
        self.memory_limit = max_memory_mb * 1024 * 1024
        self.storage_manager = None  # How to manage storage?
    
    def store_context_compressed(self, context_data) -> str:
        """Store context data with compression"""
        pass
    
    def implement_retention_policy(self) -> None:
        """Apply retention policy to stored data"""
        pass
    
    def monitor_memory_usage(self) -> Dict:
        """Monitor current memory usage"""
        pass
    
    def cleanup_old_data(self) -> None:
        """Clean up old/unused data"""
        pass
```

## Critical Fix #5: Query Accuracy - Better Temporal Parsing

### Problem Statement
Current NLTK parsing achieves ~60-70% accuracy for temporal queries. Need >85% accuracy.

### Technical Requirements

#### Advanced Time Parsing
- **Relative Time**: Better parsing of "5 minutes ago", "before lunch", "this morning"
- **Contextual Time**: Understand time relative to work patterns
- **Ambiguous Time**: Handle ambiguous time references
- **Time Range Detection**: Detect time ranges vs specific moments

#### Enhanced Query Understanding
- **Intent Classification**: Classify query intent (when, what, where, why)
- **Entity Extraction**: Extract entities from queries (apps, files, activities)
- **Context Awareness**: Use current time/context to disambiguate queries
- **Multi-Modal Queries**: Handle queries combining time and content

#### Improved Search Ranking
- **Temporal Relevance**: Weight results by temporal relevance
- **Content Relevance**: Combine temporal and content matching
- **User Behavior**: Learn from user query patterns
- **Result Fusion**: Combine multiple search approaches

### Implementation Requirements
```python
# NEED DETAILED IMPLEMENTATION FOR:
class AdvancedTemporalParser:
    def __init__(self):
        self.time_patterns = {}  # How to define time patterns?
        self.context_analyzer = None  # How to use context?
    
    def parse_temporal_query(self, query: str, current_context: Dict) -> Dict:
        """Parse temporal query with high accuracy"""
        pass
    
    def resolve_relative_time(self, time_expr: str, context: Dict) -> datetime:
        """Resolve relative time expressions"""
        pass
    
    def extract_query_entities(self, query: str) -> Dict:
        """Extract entities from natural language query"""
        pass
    
    def rank_search_results(self, results: List, query_context: Dict) -> List:
        """Rank search results by relevance"""
        pass
```

## Integration Requirements

### Existing System Integration
- **Backward Compatibility**: Maintain existing XPC API endpoints
- **Gradual Migration**: How to migrate existing data and functionality
- **Testing Strategy**: How to test improvements without breaking existing system
- **Performance Monitoring**: How to monitor improvement effectiveness

### Error Handling and Fallbacks
- **Graceful Degradation**: Fallback to current system if optimizations fail
- **Error Recovery**: Robust error handling for new components
- **Monitoring**: Real-time monitoring of system performance
- **Alerting**: Alert when performance degrades below thresholds

## Expected Deliverables

### Performance Targets
- **GPT Call Reduction**: 80% reduction in GPT-4.1-mini calls
- **Memory Usage**: <200MB sustained usage
- **App Detection**: >90% accuracy
- **Query Accuracy**: >85% temporal parsing accuracy
- **Response Time**: <500ms for all operations

### Code Deliverables
1. **Complete Algorithm Implementations**: Full working code for each fix
2. **Integration Code**: How to integrate with existing system
3. **Testing Code**: Comprehensive test suite for each improvement
4. **Performance Monitoring**: Code to monitor and measure improvements
5. **Migration Scripts**: Scripts to migrate existing data/functionality

### Documentation
- **Implementation Guide**: Step-by-step implementation instructions
- **Performance Benchmarks**: Expected performance improvements
- **API Changes**: Any changes to existing APIs
- **Deployment Strategy**: How to deploy improvements to production

## Success Criteria

The research deliverable should enable:
1. **Zero-shot Implementation**: Implement all fixes without additional research
2. **Performance Targets**: Meet all specified performance improvements
3. **Backward Compatibility**: Maintain existing functionality
4. **Production Readiness**: Code ready for production deployment
5. **Monitoring**: Ability to verify improvements in production

## Context Files to Reference
- `continuous_vision_service.py`: Current implementation
- `memory_xpc_server.py`: XPC endpoint implementations
- `vision_service.py`: GPT-4.1-mini integration
- `docs/pillar-1-implementation-prompt.md`: Original implementation details

## Research Agent Instructions

Provide extremely detailed technical specifications that include:
- **Complete algorithm implementations** with mathematical formulations
- **Production-ready code examples** with comprehensive error handling
- **Performance optimization techniques** with specific benchmarks
- **Integration patterns** with existing codebase
- **Testing strategies** with specific test cases
- **Deployment guidelines** with step-by-step instructions

The deliverable should be comprehensive enough to implement all critical fixes immediately without requiring additional research or architectural decisions.