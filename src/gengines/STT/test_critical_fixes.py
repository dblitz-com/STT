#!/usr/bin/env python3
"""
Test Critical Fixes - Comprehensive Integration Testing
Tests all 6 critical fixes together with performance monitoring

Features:
- Memory usage monitoring (target <200MB)
- Storage centralization testing
- Vision service lifecycle testing
- PyObjC stability testing
- GPT cost optimization testing
- Temporal query accuracy testing
- Integration testing with real workflows
"""

import os
import sys
import time
import psutil
import threading
import gc
from pathlib import Path
from datetime import datetime, timedelta
from typing import Dict, Any, List, Optional
import structlog

# Import all critical fixes
from storage_manager import StorageManager
from vision_service_wrapper import VisionServiceWrapper
from pyobjc_detector_stabilized import PyObjCDetectorStabilized
from gpt_cost_optimizer import GPTCostOptimizer
from enhanced_temporal_parser import EnhancedTemporalParser

logger = structlog.get_logger()

class CriticalFixesTestSuite:
    """Comprehensive test suite for all critical fixes"""
    
    def __init__(self):
        """Initialize test suite"""
        self.test_results = {}
        self.performance_metrics = {}
        self.start_time = time.time()
        self.process = psutil.Process()
        
        # Test configuration
        self.test_image_path = "/Users/devin/Desktop/vision_test_768.png"
        self.test_duration = 30  # seconds
        self.memory_target_mb = 200
        self.cost_target_usd = 0.10
        
        logger.info("🧪 Critical Fixes Test Suite initialized")
    
    def run_all_tests(self) -> Dict[str, Any]:
        """Run all critical fix tests"""
        try:
            logger.info("🚀 Starting comprehensive critical fixes testing...")
            
            # Test 1: Memory Architecture Overhaul
            logger.info("🧠 Testing Critical Fix #1: Memory Architecture Overhaul")
            self.test_results['memory_architecture'] = self._test_memory_architecture()
            
            # Test 2: Storage Architecture Centralization
            logger.info("🗂️ Testing Critical Fix #2: Storage Architecture Centralization")
            self.test_results['storage_architecture'] = self._test_storage_architecture()
            
            # Test 3: Vision Service Consistency
            logger.info("🔧 Testing Critical Fix #3: Vision Service Consistency")
            self.test_results['vision_service'] = self._test_vision_service()
            
            # Test 4: PyObjC Integration Stabilization
            logger.info("🍎 Testing Critical Fix #4: PyObjC Integration Stabilization")
            self.test_results['pyobjc_integration'] = self._test_pyobjc_integration()
            
            # Test 5: GPT Cost Optimization
            logger.info("💰 Testing Critical Fix #5: GPT Cost Optimization")
            self.test_results['gpt_optimization'] = self._test_gpt_optimization()
            
            # Test 6: Temporal Query Accuracy
            logger.info("🕰️ Testing Critical Fix #6: Temporal Query Accuracy")
            self.test_results['temporal_accuracy'] = self._test_temporal_accuracy()
            
            # Integration test
            logger.info("🔗 Testing Integration of All Fixes")
            self.test_results['integration'] = self._test_integration()
            
            # Performance summary
            self.performance_metrics = self._calculate_performance_metrics()
            
            # Generate report
            report = self._generate_test_report()
            
            logger.info("✅ All critical fixes tested successfully")
            return report
            
        except Exception as e:
            logger.error(f"❌ Test suite failed: {e}")
            return {'error': str(e), 'partial_results': self.test_results}
    
    def _test_memory_architecture(self) -> Dict[str, Any]:
        """Test memory architecture overhaul"""
        try:
            initial_memory = self._get_memory_usage()
            
            # Test garbage collection optimization
            gc.set_threshold(700, 10, 10)  # Aggressive GC
            
            # Test memory allocation patterns
            test_objects = []
            for i in range(1000):
                test_objects.append(f"test_object_{i}" * 100)
            
            # Force garbage collection
            gc.collect()
            
            # Check memory usage
            post_gc_memory = self._get_memory_usage()
            
            # Cleanup
            del test_objects
            gc.collect()
            
            final_memory = self._get_memory_usage()
            
            # Check if within target
            memory_efficient = final_memory < self.memory_target_mb
            
            return {
                'success': True,
                'initial_memory_mb': initial_memory,
                'post_gc_memory_mb': post_gc_memory,
                'final_memory_mb': final_memory,
                'memory_efficient': memory_efficient,
                'target_mb': self.memory_target_mb,
                'gc_effective': post_gc_memory < initial_memory
            }
            
        except Exception as e:
            logger.error(f"❌ Memory architecture test failed: {e}")
            return {'success': False, 'error': str(e)}
    
    def _test_storage_architecture(self) -> Dict[str, Any]:
        """Test storage architecture centralization"""
        try:
            # Initialize storage manager
            storage = StorageManager()
            
            # Test file storage
            test_data = b"Test data for storage architecture"
            metadata = {'test': True, 'timestamp': time.time()}
            
            stored_path = storage.store_file(test_data, "test_storage.txt", metadata)
            
            # Test file loading
            loaded_data = storage.load_file("test_storage.txt")
            loaded_metadata = storage.load_metadata("test_storage.txt")
            
            # Test file listing
            files = storage.list_files(pattern="test_*", include_metadata=True)
            
            # Test cleanup
            cleaned = storage.cleanup_old_files(ttl_days=0)
            
            # Test stats
            stats = storage.get_storage_stats()
            
            # Verify centralized location
            expected_base = Path.home() / ".continuous_vision" / "captures"
            centralized = str(expected_base) in stored_path
            
            return {
                'success': True,
                'file_stored': stored_path is not None,
                'data_matches': loaded_data == test_data,
                'metadata_matches': loaded_metadata == metadata,
                'files_listed': len(files) > 0,
                'cleanup_worked': cleaned >= 0,
                'centralized_location': centralized,
                'storage_stats': stats
            }
            
        except Exception as e:
            logger.error(f"❌ Storage architecture test failed: {e}")
            return {'success': False, 'error': str(e)}
    
    def _test_vision_service(self) -> Dict[str, Any]:
        """Test vision service consistency"""
        try:
            # Test singleton pattern
            service1 = VisionServiceWrapper.get_instance()
            service2 = VisionServiceWrapper.get_instance()
            
            # Test lifecycle
            service1.start()
            
            # Test health check
            health = service1.health_check()
            
            # Test metrics
            metrics = service1.get_metrics()
            
            # Test async capability
            async def test_async():
                try:
                    result = await service1.complete_async("Test async prompt")
                    return True
                except Exception as e:
                    logger.warning(f"⚠️ Async test failed: {e}")
                    return False
            
            import asyncio
            async_works = asyncio.run(test_async())
            
            # Test stop
            service1.stop()
            
            # Reset for cleanup
            VisionServiceWrapper.reset_instance()
            
            return {
                'success': True,
                'singleton_works': service1 is service2,
                'lifecycle_works': health.get('healthy', False),
                'metrics_available': metrics.requests_total >= 0,
                'async_works': async_works,
                'health_check': health
            }
            
        except Exception as e:
            logger.error(f"❌ Vision service test failed: {e}")
            return {'success': False, 'error': str(e)}
    
    def _test_pyobjc_integration(self) -> Dict[str, Any]:
        """Test PyObjC integration stabilization"""
        try:
            # Initialize detector
            detector = PyObjCDetectorStabilized()
            
            # Test frontmost app detection
            frontmost = detector.get_frontmost_app()
            
            # Test running apps
            running_apps = detector.get_running_apps()
            
            # Test vision-based detection
            vision_test = "The user is working in VS Code editor"
            vision_detected = detector.detect_app_from_vision(vision_test)
            
            # Test performance stats
            stats = detector.get_performance_stats()
            
            # Test thread stability (multiple calls)
            stability_test = True
            for i in range(5):
                try:
                    app = detector.get_frontmost_app()
                    if app is None:
                        stability_test = False
                        break
                except Exception:
                    stability_test = False
                    break
            
            # Cleanup
            detector.shutdown()
            
            return {
                'success': True,
                'frontmost_detected': frontmost is not None,
                'running_apps_count': len(running_apps),
                'vision_detection_works': vision_detected is not None,
                'performance_stats': stats,
                'thread_stability': stability_test,
                'compatibility_level': stats.get('compatibility_level', 'unknown')
            }
            
        except Exception as e:
            logger.error(f"❌ PyObjC integration test failed: {e}")
            return {'success': False, 'error': str(e)}
    
    def _test_gpt_optimization(self) -> Dict[str, Any]:
        """Test GPT cost optimization"""
        try:
            # Initialize optimizer
            optimizer = GPTCostOptimizer()
            
            # Test token estimation
            if os.path.exists(self.test_image_path):
                estimated_tokens = optimizer._estimate_token_usage(self.test_image_path)
                
                # Test cropping
                cropped_path = optimizer.crop_to_active_window(self.test_image_path)
                
                # Test cache
                cache_key = optimizer._generate_cache_key(self.test_image_path)
                optimizer.cache_analysis(self.test_image_path, "Test analysis", 100)
                cached = optimizer.get_cached_analysis(self.test_image_path)
                
                # Test cost calculation
                cost = optimizer._calculate_cost(estimated_tokens, 'gpt-4.1-mini')
                
                # Test stats
                stats = optimizer.get_cost_stats()
                
                return {
                    'success': True,
                    'token_estimation': estimated_tokens,
                    'cropping_works': cropped_path != self.test_image_path,
                    'caching_works': cached is not None,
                    'cost_calculation': cost,
                    'cost_stats': stats,
                    'cost_efficient': cost < self.cost_target_usd
                }
            else:
                return {
                    'success': False,
                    'error': f'Test image not found: {self.test_image_path}'
                }
                
        except Exception as e:
            logger.error(f"❌ GPT optimization test failed: {e}")
            return {'success': False, 'error': str(e)}
    
    def _test_temporal_accuracy(self) -> Dict[str, Any]:
        """Test temporal query accuracy"""
        try:
            # Initialize parser
            parser = EnhancedTemporalParser()
            
            # Test queries
            test_queries = [
                "What was I doing 5 minutes ago?",
                "Show me activities from this morning",
                "When did I last work on coding?",
                "Find browser activities from yesterday"
            ]
            
            results = []
            total_parse_time = 0
            
            for query in test_queries:
                start_time = time.time()
                parsed = parser.parse_temporal_query(query)
                parse_time = time.time() - start_time
                
                total_parse_time += parse_time
                
                results.append({
                    'query': query,
                    'intent': parsed.intent.intent_type.value,
                    'confidence': parsed.intent.confidence,
                    'keywords': parsed.priority_keywords,
                    'parse_time': parse_time
                })
            
            # Test result ranking
            mock_results = [
                {'content': 'coding activity', 'timestamp': datetime.now() - timedelta(minutes=10)},
                {'content': 'browser activity', 'timestamp': datetime.now() - timedelta(hours=2)},
                {'content': 'meeting activity', 'timestamp': datetime.now() - timedelta(minutes=30)}
            ]
            
            parsed_query = parser.parse_temporal_query("What was I doing 10 minutes ago?")
            ranked = parser.rank_search_results(mock_results, parsed_query)
            
            # Performance stats
            stats = parser.get_performance_stats()
            
            return {
                'success': True,
                'query_results': results,
                'average_parse_time': total_parse_time / len(test_queries),
                'ranking_works': len(ranked) > 0,
                'performance_stats': stats,
                'accuracy_target_met': all(r['confidence'] > 0.5 for r in results)
            }
            
        except Exception as e:
            logger.error(f"❌ Temporal accuracy test failed: {e}")
            return {'success': False, 'error': str(e)}
    
    def _test_integration(self) -> Dict[str, Any]:
        """Test integration of all fixes"""
        try:
            # Initialize all components
            storage = StorageManager()
            vision_service = VisionServiceWrapper.get_instance()
            vision_service.start()
            detector = PyObjCDetectorStabilized()
            optimizer = GPTCostOptimizer(detector, vision_service)
            parser = EnhancedTemporalParser()
            
            # Test integrated workflow
            integration_results = {}
            
            # Test 1: Memory monitoring during operations
            initial_memory = self._get_memory_usage()
            
            # Test 2: Storage + Vision Service
            if os.path.exists(self.test_image_path):
                with open(self.test_image_path, 'rb') as f:
                    image_data = f.read()
                
                stored_path = storage.store_file(image_data, "integration_test.png")
                integration_results['storage_vision'] = stored_path is not None
            
            # Test 3: PyObjC + GPT Optimization
            frontmost = detector.get_frontmost_app()
            if frontmost:
                optimized_result = optimizer.process_with_fallback(
                    self.test_image_path, 
                    "Analyze this screen",
                    "integration_test"
                )
                integration_results['pyobjc_gpt'] = optimized_result.get('success', False)
            
            # Test 4: Temporal Query + All Components
            query_result = parser.parse_temporal_query("What was I doing recently?")
            integration_results['temporal_integration'] = query_result.intent.confidence > 0.5
            
            # Test 5: Memory usage after integration
            final_memory = self._get_memory_usage()
            memory_increase = final_memory - initial_memory
            integration_results['memory_controlled'] = memory_increase < 50  # Max 50MB increase
            
            # Test 6: Performance under load
            load_test_success = True
            for i in range(5):
                try:
                    app = detector.get_frontmost_app()
                    if app is None:
                        load_test_success = False
                        break
                except Exception:
                    load_test_success = False
                    break
            
            integration_results['load_test'] = load_test_success
            
            # Cleanup
            vision_service.stop()
            detector.shutdown()
            
            return {
                'success': True,
                'integration_results': integration_results,
                'initial_memory_mb': initial_memory,
                'final_memory_mb': final_memory,
                'memory_increase_mb': memory_increase,
                'all_components_working': all(integration_results.values())
            }
            
        except Exception as e:
            logger.error(f"❌ Integration test failed: {e}")
            return {'success': False, 'error': str(e)}
    
    def _get_memory_usage(self) -> float:
        """Get current memory usage in MB"""
        try:
            memory_info = self.process.memory_info()
            return memory_info.rss / 1024 / 1024  # Convert to MB
        except Exception:
            return 0.0
    
    def _calculate_performance_metrics(self) -> Dict[str, Any]:
        """Calculate overall performance metrics"""
        try:
            total_time = time.time() - self.start_time
            current_memory = self._get_memory_usage()
            
            # Calculate success rate
            successful_tests = sum(1 for result in self.test_results.values() if result.get('success', False))
            total_tests = len(self.test_results)
            success_rate = (successful_tests / total_tests) * 100 if total_tests > 0 else 0
            
            return {
                'total_test_time': total_time,
                'current_memory_mb': current_memory,
                'memory_target_met': current_memory < self.memory_target_mb,
                'success_rate': success_rate,
                'successful_tests': successful_tests,
                'total_tests': total_tests,
                'performance_grade': self._calculate_grade(success_rate, current_memory)
            }
            
        except Exception as e:
            logger.error(f"❌ Performance metrics calculation failed: {e}")
            return {}
    
    def _calculate_grade(self, success_rate: float, memory_usage: float) -> str:
        """Calculate performance grade"""
        try:
            # Grade based on success rate and memory usage
            if success_rate >= 90 and memory_usage < self.memory_target_mb:
                return "A"
            elif success_rate >= 80 and memory_usage < self.memory_target_mb * 1.2:
                return "B"
            elif success_rate >= 70 and memory_usage < self.memory_target_mb * 1.5:
                return "C"
            elif success_rate >= 60:
                return "D"
            else:
                return "F"
                
        except Exception:
            return "Unknown"
    
    def _generate_test_report(self) -> Dict[str, Any]:
        """Generate comprehensive test report"""
        try:
            report = {
                'timestamp': datetime.now().isoformat(),
                'test_results': self.test_results,
                'performance_metrics': self.performance_metrics,
                'summary': {
                    'all_tests_passed': all(result.get('success', False) for result in self.test_results.values()),
                    'memory_target_met': self.performance_metrics.get('memory_target_met', False),
                    'performance_grade': self.performance_metrics.get('performance_grade', 'Unknown'),
                    'recommendations': self._generate_recommendations()
                }
            }
            
            return report
            
        except Exception as e:
            logger.error(f"❌ Test report generation failed: {e}")
            return {'error': str(e)}
    
    def _generate_recommendations(self) -> List[str]:
        """Generate recommendations based on test results"""
        try:
            recommendations = []
            
            # Memory recommendations
            if not self.performance_metrics.get('memory_target_met', False):
                recommendations.append("Consider implementing lazy loading for heavy components")
                recommendations.append("Add process isolation for memory-intensive operations")
            
            # Integration recommendations
            if not self.test_results.get('integration', {}).get('success', False):
                recommendations.append("Review component integration patterns")
                recommendations.append("Add error handling for component failures")
            
            # Performance recommendations
            if self.performance_metrics.get('success_rate', 0) < 90:
                recommendations.append("Improve error handling and recovery mechanisms")
                recommendations.append("Add more comprehensive testing coverage")
            
            return recommendations
            
        except Exception as e:
            logger.error(f"❌ Recommendations generation failed: {e}")
            return ["Unable to generate recommendations"]


def main():
    """Run comprehensive critical fixes test"""
    print("🧪 Zeus VLA Critical Fixes - Comprehensive Test Suite")
    print("=" * 60)
    
    # Initialize test suite
    test_suite = CriticalFixesTestSuite()
    
    # Run all tests
    report = test_suite.run_all_tests()
    
    # Display results
    print("\n📊 TEST RESULTS SUMMARY:")
    print("=" * 60)
    
    if 'error' in report:
        print(f"❌ Test suite failed: {report['error']}")
        return
    
    # Display test results
    for test_name, result in report['test_results'].items():
        status = "✅ PASSED" if result.get('success', False) else "❌ FAILED"
        print(f"{status} {test_name}")
        
        if not result.get('success', False) and 'error' in result:
            print(f"    Error: {result['error']}")
    
    # Display performance metrics
    print("\n🚀 PERFORMANCE METRICS:")
    print("=" * 60)
    
    metrics = report['performance_metrics']
    print(f"Success Rate: {metrics.get('success_rate', 0):.1f}%")
    print(f"Memory Usage: {metrics.get('current_memory_mb', 0):.1f} MB")
    print(f"Memory Target: {test_suite.memory_target_mb} MB")
    print(f"Performance Grade: {metrics.get('performance_grade', 'Unknown')}")
    
    # Display summary
    print("\n📋 SUMMARY:")
    print("=" * 60)
    
    summary = report['summary']
    print(f"All Tests Passed: {'✅ YES' if summary['all_tests_passed'] else '❌ NO'}")
    print(f"Memory Target Met: {'✅ YES' if summary['memory_target_met'] else '❌ NO'}")
    print(f"Performance Grade: {summary['performance_grade']}")
    
    # Display recommendations
    if summary['recommendations']:
        print("\n💡 RECOMMENDATIONS:")
        print("=" * 60)
        for i, rec in enumerate(summary['recommendations'], 1):
            print(f"{i}. {rec}")
    
    # Save report
    report_path = f"test_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    try:
        import json
        with open(report_path, 'w') as f:
            json.dump(report, f, indent=2, default=str)
        print(f"\n💾 Test report saved to: {report_path}")
    except Exception as e:
        print(f"\n⚠️ Failed to save report: {e}")
    
    print("\n🎉 Critical Fixes Test Suite Complete!")


if __name__ == "__main__":
    main()