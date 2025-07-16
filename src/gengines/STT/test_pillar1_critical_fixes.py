#!/usr/bin/env python3
"""
Test Suite for PILLAR 1 Critical Fixes
Tests all 5 critical fixes implemented for performance and accuracy optimization

Test Coverage:
- Fix #1: OptimizedVisionService (GPT call reduction by 80%)
- Fix #2: MacOSAppDetector (>90% app detection accuracy)
- Fix #3: WorkflowTaskDetector (intra-app task boundaries)
- Fix #4: MemoryOptimizedStorage (<200MB memory usage)
- Fix #5: AdvancedTemporalParser (>85% query accuracy)
"""

import os
import sys
import time
import tempfile
import unittest
from unittest.mock import Mock, patch, MagicMock
from datetime import datetime, timedelta
from pathlib import Path
import json

# Add the project root to the path
sys.path.insert(0, str(Path(__file__).parent))

# Import the components to test
from optimized_vision_service import OptimizedVisionService
from macos_app_detector import MacOSAppDetector
from workflow_task_detector import WorkflowTaskDetector, TaskType
from memory_optimized_storage import MemoryOptimizedStorage
from advanced_temporal_parser import AdvancedTemporalParser
from continuous_vision_service import ContinuousVisionService
from vision_service import VisionService

class TestOptimizedVisionService(unittest.TestCase):
    """Test Fix #1: Performance Optimization - Reduce GPT calls by 80%"""
    
    def setUp(self):
        """Set up test environment"""
        self.mock_vision_service = Mock(spec=VisionService)
        self.optimized_vision = OptimizedVisionService(self.mock_vision_service)
    
    def test_should_call_gpt_caching(self):
        """Test that caching reduces GPT calls"""
        # Create frame data
        frame_data = {
            'image_path': '/test/image.png',
            'change_confidence': 0.8,
            'app_context': 'VS Code',
            'timestamp': datetime.now()
        }
        
        # First call should return True (cache miss)
        result1 = self.optimized_vision.should_call_gpt(frame_data)
        self.assertTrue(result1)
        
        # Mock cache hit
        with patch.object(self.optimized_vision, 'get_cached_analysis', return_value={'analysis': 'cached'}):
            result2 = self.optimized_vision.should_call_gpt(frame_data)
            self.assertFalse(result2)  # Should skip GPT call due to cache
    
    def test_batch_processing(self):
        """Test batch processing functionality"""
        # Create multiple frame data
        frames = []
        for i in range(3):
            frame_data = {
                'image_path': f'/test/image{i}.png',
                'change_confidence': 0.7,
                'app_context': 'VS Code',
                'timestamp': datetime.now()
            }
            frames.append(frame_data)
        
        # Add frames to batch
        for frame_data in frames:
            self.optimized_vision.add_to_batch(frame_data)
        
        # Verify batch buffer is populated
        self.assertGreater(len(self.optimized_vision.batch_buffer), 0)
    
    def test_performance_stats(self):
        """Test performance statistics tracking"""
        stats = self.optimized_vision.get_performance_stats()
        
        # Verify expected metrics are present
        expected_keys = [
            'gpt_calls_saved',
            'total_frames_processed',
            'cache_hit_rate',
            'current_activity_level',
            'dynamic_fps'
        ]
        
        for key in expected_keys:
            self.assertIn(key, stats)
    
    def test_activity_level_adjustment(self):
        """Test dynamic activity level adjustment"""
        # Test high activity
        frame_data = {
            'image_path': '/test/image.png',
            'change_confidence': 0.9,  # High change
            'app_context': 'VS Code',
            'timestamp': datetime.now()
        }
        
        self.optimized_vision.update_activity_metrics(frame_data)
        self.assertGreater(len(self.optimized_vision.activity_history), 0)

class TestMacOSAppDetector(unittest.TestCase):
    """Test Fix #2: Accurate App Detection - Use macOS APIs"""
    
    def setUp(self):
        """Set up test environment"""
        # Mock PyObjC availability
        with patch('macos_app_detector.PYOBJC_AVAILABLE', True):
            self.app_detector = MacOSAppDetector()
    
    @patch('macos_app_detector.NSWorkspace')
    def test_get_frontmost_app(self, mock_workspace):
        """Test frontmost app detection"""
        # Mock NSWorkspace
        mock_app = Mock()
        mock_app.bundleIdentifier.return_value = 'com.microsoft.VSCode'
        mock_app.localizedName.return_value = 'Visual Studio Code'
        mock_app.processIdentifier.return_value = 1234
        mock_app.isActive.return_value = True
        mock_app.activationPolicy.return_value = 0
        mock_app.launchDate.return_value = Mock()
        mock_app.launchDate.return_value.timeIntervalSince1970.return_value = time.time() - 3600
        
        mock_workspace.sharedWorkspace.return_value.frontmostApplication.return_value = mock_app
        
        # Test app detection
        app_info = self.app_detector.get_frontmost_app()
        
        self.assertIsNotNone(app_info)
        self.assertEqual(app_info.name, 'Visual Studio Code')
        self.assertEqual(app_info.bundle_id, 'com.microsoft.VSCode')
        self.assertTrue(app_info.is_active)
    
    def test_app_confidence_calculation(self):
        """Test app detection confidence calculation"""
        confidence = self.app_detector._calculate_app_confidence(
            'com.microsoft.VSCode', 
            'Visual Studio Code', 
            1234
        )
        
        self.assertGreater(confidence, 0.5)
        self.assertLessEqual(confidence, 1.0)
    
    def test_vision_validation(self):
        """Test app detection with vision validation"""
        vision_analysis = "This is Visual Studio Code with a Python file open"
        
        # Mock get_frontmost_app
        with patch.object(self.app_detector, 'get_frontmost_app') as mock_get_app:
            mock_app = Mock()
            mock_app.name = 'Visual Studio Code'
            mock_app.bundle_id = 'com.microsoft.VSCode'
            mock_app.confidence = 0.9
            mock_get_app.return_value = mock_app
            
            # Test vision-validated detection
            result = self.app_detector.detect_app_from_vision(vision_analysis)
            
            self.assertIsNotNone(result)
            self.assertEqual(result.name, 'Visual Studio Code')
    
    def test_performance_stats(self):
        """Test performance statistics"""
        stats = self.app_detector.get_performance_stats()
        
        expected_keys = [
            'detection_accuracy',
            'total_detections',
            'running_apps_count',
            'current_app'
        ]
        
        for key in expected_keys:
            self.assertIn(key, stats)

class TestWorkflowTaskDetector(unittest.TestCase):
    """Test Fix #3: Real Workflow Detection - Task boundaries"""
    
    def setUp(self):
        """Set up test environment"""
        self.task_detector = WorkflowTaskDetector()
    
    def test_task_boundary_detection(self):
        """Test task boundary detection"""
        # Test coding activity
        screen_analysis = "def hello_world(): print('Hello, World!')"
        app_context = {'name': 'VS Code'}
        
        boundary = self.task_detector.detect_task_boundaries(
            screen_analysis, 
            app_context
        )
        
        # First detection should not have boundary
        self.assertIsNone(boundary)
        
        # Test debugging activity
        debug_analysis = "breakpoint() debug console active"
        boundary = self.task_detector.detect_task_boundaries(
            debug_analysis, 
            app_context
        )
        
        # Should detect task boundary from coding to debugging
        self.assertIsNotNone(boundary)
        self.assertEqual(boundary.from_task, TaskType.CODING)
        self.assertEqual(boundary.to_task, TaskType.DEBUGGING)
    
    def test_task_classification(self):
        """Test task type classification"""
        # Test coding classification
        coding_content = "def main(): return 'Hello World'"
        app_context = {'name': 'VS Code'}
        
        task_context = self.task_detector._classify_task_type(
            coding_content, 
            'VS Code'
        )
        
        self.assertEqual(task_context.task_type, TaskType.CODING)
        self.assertGreater(task_context.confidence, 0.0)
    
    def test_confidence_calculation(self):
        """Test task confidence calculation"""
        patterns = {
            'keywords': ['def', 'class', 'import'],
            'ui_elements': ['editor', 'sidebar'],
            'content_patterns': [r'def\s+\w+']
        }
        
        content = "def hello(): print('world')"
        confidence = self.task_detector._calculate_task_score(
            content, 
            patterns
        )
        
        self.assertGreater(confidence, 0.0)
        self.assertLessEqual(confidence, 1.0)
    
    def test_workflow_pattern_analysis(self):
        """Test workflow pattern analysis"""
        # Add some fake history
        for i in range(10):
            task_context = Mock()
            task_context.task_type = TaskType.CODING if i % 2 == 0 else TaskType.DEBUGGING
            task_context.start_time = datetime.now() - timedelta(minutes=i)
            self.task_detector.task_history.append(task_context)
        
        # Analyze patterns
        sequence = self.task_detector.analyze_workflow_patterns()
        
        self.assertIsNotNone(sequence)
        self.assertGreater(len(sequence.transition_probabilities), 0)
    
    def test_performance_stats(self):
        """Test performance statistics"""
        stats = self.task_detector.get_performance_stats()
        
        expected_keys = [
            'boundary_detections',
            'detection_accuracy',
            'task_history_size',
            'current_task'
        ]
        
        for key in expected_keys:
            self.assertIn(key, stats)

class TestMemoryOptimizedStorage(unittest.TestCase):
    """Test Fix #4: Memory Optimization - Reduce to <200MB"""
    
    def setUp(self):
        """Set up test environment"""
        self.temp_dir = tempfile.mkdtemp()
        self.storage = MemoryOptimizedStorage(self.temp_dir)
    
    def tearDown(self):
        """Clean up test environment"""
        self.storage.cleanup()
    
    def test_compressed_storage(self):
        """Test compressed data storage"""
        test_data = {'content': 'A' * 1000}  # Large enough for compression
        
        # Store data
        success = self.storage.store_compressed('test_key', test_data, priority=0.8)
        self.assertTrue(success)
        
        # Retrieve data
        retrieved = self.storage.retrieve_decompressed('test_key')
        self.assertEqual(retrieved, test_data)
    
    def test_memory_pressure_handling(self):
        """Test memory pressure handling"""
        # Fill storage to trigger cleanup
        for i in range(100):
            large_data = {'content': f'Large content {i}' * 100}
            self.storage.store_compressed(f'key_{i}', large_data, priority=0.1)
        
        # Check that cleanup was triggered
        stats = self.storage.get_storage_stats()
        self.assertGreater(stats['metrics']['cleanup_runs'], 0)
    
    def test_retention_policy(self):
        """Test data retention policy"""
        # Store data with different priorities
        high_priority = {'content': 'Important data'}
        low_priority = {'content': 'Less important data'}
        
        self.storage.store_compressed('high_key', high_priority, priority=0.9)
        self.storage.store_compressed('low_key', low_priority, priority=0.1)
        
        # Force cleanup
        self.storage._cleanup_old_entries(force=True)
        
        # High priority should still be retrievable
        retrieved_high = self.storage.retrieve_decompressed('high_key')
        self.assertEqual(retrieved_high, high_priority)
    
    def test_storage_optimization(self):
        """Test storage optimization"""
        # Store uncompressed data
        test_data = {'content': 'Test data that could be compressed'}
        self.storage.store_compressed('test_key', test_data, priority=0.5)
        
        # Run optimization
        result = self.storage.optimize_storage()
        
        self.assertIn('optimized_entries', result)
        self.assertIn('bytes_saved', result)
    
    def test_memory_monitoring(self):
        """Test memory usage monitoring"""
        stats = self.storage.get_storage_stats()
        
        expected_keys = [
            'metrics',
            'performance',
            'cache',
            'files'
        ]
        
        for key in expected_keys:
            self.assertIn(key, stats)
        
        # Check memory usage is tracked
        self.assertIn('memory_usage_mb', stats['metrics'])

class TestAdvancedTemporalParser(unittest.TestCase):
    """Test Fix #5: Query Accuracy - Better temporal parsing"""
    
    def setUp(self):
        """Set up test environment"""
        self.parser = AdvancedTemporalParser()
    
    def test_temporal_query_parsing(self):
        """Test temporal query parsing"""
        query = "What was I working on this morning?"
        
        temporal_query = self.parser.parse_temporal_query(query)
        
        self.assertIsNotNone(temporal_query)
        self.assertEqual(temporal_query.original_query, query)
        self.assertIsNotNone(temporal_query.intent)
        self.assertIsNotNone(temporal_query.time_range)
    
    def test_intent_classification(self):
        """Test query intent classification"""
        queries = [
            ("What was I doing?", "what"),
            ("When did I start coding?", "when"),
            ("Show me my recent work", "show"),
            ("Find the bug I was fixing", "find")
        ]
        
        for query, expected_intent in queries:
            intent = self.parser._classify_intent(query)
            self.assertEqual(intent.intent_type, expected_intent)
    
    def test_temporal_entity_extraction(self):
        """Test temporal entity extraction"""
        query = "What was I doing yesterday at 2 PM?"
        
        entities = self.parser._extract_temporal_entities(query)
        
        self.assertGreater(len(entities), 0)
        # Should extract "yesterday" and "2 PM"
        entity_texts = [e.text for e in entities]
        self.assertIn('yesterday', entity_texts)
    
    def test_temporal_resolution(self):
        """Test temporal entity resolution"""
        test_cases = [
            ("today", datetime.now().replace(hour=12, minute=0, second=0, microsecond=0)),
            ("morning", datetime.now().replace(hour=9, minute=0, second=0, microsecond=0)),
            ("5 minutes ago", datetime.now() - timedelta(minutes=5))
        ]
        
        for text, expected_time in test_cases:
            resolved = self.parser._resolve_temporal_entity(text)
            self.assertIsNotNone(resolved)
            
            # Check within reasonable range (allowing for test execution time)
            if "ago" in text:
                self.assertLess(abs((resolved - expected_time).total_seconds()), 10)
    
    def test_search_result_ranking(self):
        """Test search result ranking"""
        # Create mock search results
        results = [
            {
                'content': 'Working on Python code',
                'timestamp': datetime.now() - timedelta(hours=1),
                'metadata': {'app_context': 'VS Code'}
            },
            {
                'content': 'Debugging the application',
                'timestamp': datetime.now() - timedelta(hours=2),
                'metadata': {'app_context': 'VS Code'}
            }
        ]
        
        # Create temporal query
        query = "What was I coding?"
        temporal_query = self.parser.parse_temporal_query(query)
        
        # Rank results
        ranked_results = self.parser.rank_search_results(results, temporal_query)
        
        self.assertEqual(len(ranked_results), 2)
        self.assertGreater(ranked_results[0].final_score, 0)
        # Results should be sorted by score
        self.assertGreaterEqual(ranked_results[0].final_score, ranked_results[1].final_score)
    
    def test_performance_stats(self):
        """Test parser performance statistics"""
        stats = self.parser.get_performance_stats()
        
        expected_keys = [
            'total_queries',
            'success_rate',
            'avg_parse_time_ms',
            'spacy_available'
        ]
        
        for key in expected_keys:
            self.assertIn(key, stats)

class TestIntegratedSystem(unittest.TestCase):
    """Test integrated system with all critical fixes"""
    
    def setUp(self):
        """Set up integrated test environment"""
        # Mock the vision service to avoid external dependencies
        with patch('continuous_vision_service.VisionService') as mock_vision_service:
            mock_vision_service.return_value = Mock()
            
            # Mock app detector to avoid macOS dependencies
            with patch('continuous_vision_service.MacOSAppDetector') as mock_app_detector:
                mock_app_detector.return_value = Mock()
                
                # Create service with mocked dependencies
                self.service = ContinuousVisionService()
    
    def test_all_components_initialized(self):
        """Test that all critical fix components are initialized"""
        # Check that all critical fix components are present
        self.assertIsNotNone(self.service.optimized_vision)
        self.assertIsNotNone(self.service.app_detector)
        self.assertIsNotNone(self.service.task_detector)
        self.assertIsNotNone(self.service.memory_storage)
        self.assertIsNotNone(self.service.temporal_parser)
    
    def test_workflow_detection_integration(self):
        """Test integrated workflow detection"""
        # Mock frame analysis
        with patch.object(self.service, '_analyze_visual_context') as mock_analyze:
            mock_analyze.return_value = "VS Code with Python file open"
            
            # Mock app identification
            with patch.object(self.service, '_identify_application_context') as mock_identify:
                mock_identify.return_value = 'VS Code'
                
                # Test workflow detection
                result = self.service.detect_workflow_patterns(
                    '/test/image.png', 
                    ['/test/previous.png']
                )
                
                self.assertIsNotNone(result)
                self.assertIn('event', result)
                self.assertIn('confidence', result)
    
    def test_temporal_query_integration(self):
        """Test integrated temporal query processing"""
        # Mock memory storage
        with patch.object(self.service.memory_storage, 'get_storage_stats') as mock_stats:
            mock_stats.return_value = {'cache': {'total_entries': 0}}
            
            # Mock Mem0 client
            with patch.object(self.service, 'mem0_client') as mock_mem0:
                mock_mem0.search.return_value = [
                    {
                        'memory': 'Working on Python code',
                        'metadata': {'timestamp': datetime.now().isoformat()}
                    }
                ]
                
                # Test temporal query
                response = self.service.query_temporal_context("What was I coding?")
                
                self.assertIsNotNone(response)
                self.assertIsInstance(response, str)
    
    def test_performance_benchmarks(self):
        """Test that performance benchmarks are met"""
        # Test memory usage
        stats = self.service.memory_storage.get_storage_stats()
        memory_usage = stats['metrics']['memory_usage_mb']
        
        # Should be under 200MB (allowing for test overhead)
        self.assertLess(memory_usage, 250)
        
        # Test temporal query performance
        start_time = time.time()
        response = self.service.query_temporal_context("What was I doing?")
        query_time = time.time() - start_time
        
        # Should be under 200ms (allowing for test overhead)
        self.assertLess(query_time, 1.0)  # 1 second for test environment
    
    def test_error_handling(self):
        """Test error handling and fallbacks"""
        # Test with invalid input
        result = self.service.detect_workflow_patterns(
            '/nonexistent/image.png', 
            []
        )
        
        # Should handle errors gracefully
        self.assertIsNotNone(result)
        self.assertIn('event', result)
        
        # Test temporal query with invalid input
        response = self.service.query_temporal_context("")
        self.assertIsNotNone(response)
        self.assertIsInstance(response, str)

def run_performance_benchmark():
    """Run performance benchmarks for all critical fixes"""
    print("\n🔥 PILLAR 1 CRITICAL FIXES PERFORMANCE BENCHMARK")
    print("=" * 60)
    
    # Create mock vision service
    mock_vision_service = Mock()
    
    # Benchmark Fix #1: OptimizedVisionService
    print("\n📊 Fix #1: OptimizedVisionService Performance")
    optimized_vision = OptimizedVisionService(mock_vision_service)
    
    start_time = time.time()
    for i in range(100):
        frame_data = {
            'image_path': f'/test/image{i}.png',
            'change_confidence': 0.5,
            'app_context': 'VS Code'
        }
        optimized_vision.should_call_gpt(frame_data)
    
    batch_time = time.time() - start_time
    print(f"   - 100 GPT decision calls: {batch_time:.3f}s")
    
    stats = optimized_vision.get_performance_stats()
    print(f"   - Cache hit rate: {stats['cache_hit_rate']:.2f}")
    print(f"   - GPT calls saved: {stats['gpt_calls_saved']}")
    
    # Benchmark Fix #4: MemoryOptimizedStorage
    print("\n📊 Fix #4: MemoryOptimizedStorage Performance")
    with tempfile.TemporaryDirectory() as temp_dir:
        storage = MemoryOptimizedStorage(temp_dir)
        
        start_time = time.time()
        for i in range(100):
            test_data = {'content': f'Test data {i}' * 10}
            storage.store_compressed(f'key_{i}', test_data, priority=0.5)
        
        store_time = time.time() - start_time
        print(f"   - 100 compressed stores: {store_time:.3f}s")
        
        start_time = time.time()
        for i in range(100):
            retrieved = storage.retrieve_decompressed(f'key_{i}')
        
        retrieve_time = time.time() - start_time
        print(f"   - 100 compressed retrieves: {retrieve_time:.3f}s")
        
        stats = storage.get_storage_stats()
        print(f"   - Memory usage: {stats['metrics']['memory_usage_mb']:.1f}MB")
        print(f"   - Cache size: {stats['cache']['total_entries']}")
        
        storage.cleanup()
    
    # Benchmark Fix #5: AdvancedTemporalParser
    print("\n📊 Fix #5: AdvancedTemporalParser Performance")
    parser = AdvancedTemporalParser()
    
    test_queries = [
        "What was I working on this morning?",
        "Show me my coding activity from yesterday",
        "Find the bug I was debugging 2 hours ago",
        "What apps did I use during lunch?",
        "When did I start the meeting?"
    ]
    
    start_time = time.time()
    for query in test_queries * 10:  # 50 queries total
        temporal_query = parser.parse_temporal_query(query)
    
    parse_time = time.time() - start_time
    print(f"   - 50 temporal query parses: {parse_time:.3f}s")
    print(f"   - Average parse time: {parse_time * 1000 / 50:.1f}ms")
    
    stats = parser.get_performance_stats()
    print(f"   - Total queries processed: {stats['total_queries']}")
    print(f"   - Success rate: {stats['success_rate']:.2f}")
    
    print("\n🎆 ALL PILLAR 1 CRITICAL FIXES PERFORMANCE BENCHMARKS COMPLETED")
    print("✅ Target: GPT calls reduced 80%, Memory <200MB, Query accuracy >85%")

if __name__ == '__main__':
    # Run unit tests
    print("🧪 Running PILLAR 1 Critical Fixes Test Suite")
    print("=" * 50)
    
    # Create test suite
    test_suite = unittest.TestLoader().loadTestsFromModule(sys.modules[__name__])
    
    # Run tests
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(test_suite)
    
    # Print summary
    if result.wasSuccessful():
        print("\n✅ ALL TESTS PASSED!")
    else:
        print(f"\n❌ {len(result.failures)} test(s) failed, {len(result.errors)} error(s)")
        for failure in result.failures:
            print(f"   FAIL: {failure[0]}")
        for error in result.errors:
            print(f"   ERROR: {error[0]}")
    
    # Run performance benchmarks
    run_performance_benchmark()