#!/usr/bin/env python3
"""
Test Current Vision System - See What It Actually Does
Shows real-time output of our current continuous vision monitoring
"""

import sys
import os
import time
import threading
from pathlib import Path
from datetime import datetime
import json

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent))

def simple_test():
    """Simple test without imports to see what we can access"""
    print("=== Zeus VLA Current Vision System Test ===")
    print(f"Working Directory: {os.getcwd()}")
    print(f"Python Path: {sys.path[0]}")
    
    # Check if key files exist
    files_to_check = [
        "continuous_vision_service.py",
        "macos_app_detector.py", 
        "optimized_vision_service.py",
        "workflow_task_detector.py",
        "memory_optimized_storage.py",
        "advanced_temporal_parser.py"
    ]
    
    print("\n📁 PILLAR 1 Files:")
    for file in files_to_check:
        if Path(file).exists():
            print(f"  ✅ {file}")
        else:
            print(f"  ❌ {file}")
    
    # Check capture directory
    capture_dir = Path.home() / ".continuous_vision" / "captures"
    print(f"\n📸 Capture Directory: {capture_dir}")
    if capture_dir.exists():
        captures = list(capture_dir.glob("*.png"))
        print(f"  📊 Total captures: {len(captures)}")
        if captures:
            latest = max(captures, key=lambda p: p.stat().st_mtime)
            print(f"  🕐 Latest: {latest.name} ({datetime.fromtimestamp(latest.stat().st_mtime).strftime('%H:%M:%S')})")
    else:
        print("  ❌ No capture directory found")
    
    # Test basic imports
    print("\n🔧 Testing Basic Imports:")
    try:
        from macos_app_detector import MacOSAppDetector
        detector = MacOSAppDetector()
        app_info = detector.get_frontmost_app()
        if app_info:
            print(f"  ✅ App Detection: {app_info.name} ({app_info.bundle_id})")
            print(f"     Confidence: {app_info.confidence:.2%}")
        else:
            print("  ⚠️ No app detected")
    except Exception as e:
        print(f"  ❌ App detection failed: {e}")
    
    try:
        from memory_optimized_storage import MemoryOptimizedStorage
        storage = MemoryOptimizedStorage()
        stats = storage.get_storage_stats()
        print(f"  ✅ Memory Storage: {stats.get('total_entries', 0)} entries")
    except Exception as e:
        print(f"  ❌ Memory storage failed: {e}")
    
    try:
        from advanced_temporal_parser import AdvancedTemporalParser
        parser = AdvancedTemporalParser()
        test_query = "what did I do 5 minutes ago"
        result = parser.parse_temporal_query(test_query)
        print(f"  ✅ Temporal Parser: Parsed '{test_query}' -> {result.intent}")
    except Exception as e:
        print(f"  ❌ Temporal parser failed: {e}")

def test_app_detection():
    """Test current app detection capabilities"""
    print("\n🔍 Testing App Detection:")
    try:
        from macos_app_detector import MacOSAppDetector
        detector = MacOSAppDetector()
        
        # Get current app
        app_info = detector.get_frontmost_app()
        if app_info:
            print(f"Current App: {app_info.name}")
            print(f"Bundle ID: {app_info.bundle_id}")
            print(f"Confidence: {app_info.confidence:.2%}")
            print(f"Windows: {app_info.window_count}")
            print(f"PID: {app_info.pid}")
            
            # Get all running apps
            running_apps = detector.get_running_apps()
            print(f"\nRunning Apps: {len(running_apps)} total")
            for app in running_apps[:5]:  # Show first 5
                print(f"  - {app.name} ({app.bundle_id})")
        
        # Get performance stats
        stats = detector.get_performance_stats()
        print(f"\nDetection Stats:")
        print(f"  Accuracy: {stats['detection_accuracy']:.2%}")
        print(f"  Total Detections: {stats['total_detections']}")
        print(f"  False Positives: {stats['false_positives']}")
        
    except Exception as e:
        print(f"App detection test failed: {e}")

def test_workflow_detection():
    """Test workflow detection"""
    print("\n🔄 Testing Workflow Detection:")
    try:
        from workflow_task_detector import WorkflowTaskDetector
        detector = WorkflowTaskDetector()
        
        # Test task boundary detection
        screen_analysis = "User is coding in VS Code with terminal open"
        app_context = {"name": "Visual Studio Code", "bundle_id": "com.microsoft.VSCode"}
        
        boundary = detector.detect_task_boundaries(screen_analysis, app_context)
        if boundary:
            print(f"Task Boundary: {boundary.task_type}")
            print(f"Confidence: {boundary.confidence:.2%}")
            print(f"Context: {boundary.context}")
        else:
            print("No task boundary detected")
            
        # Test workflow patterns
        detector.analyze_workflow_patterns()
        print("Workflow pattern analysis completed")
        
    except Exception as e:
        print(f"Workflow detection test failed: {e}")

def test_current_captures():
    """Show what the current system has captured"""
    print("\n📸 Current Captures:")
    capture_dir = Path.home() / ".continuous_vision" / "captures"
    
    if not capture_dir.exists():
        print("No captures directory found")
        return
    
    captures = list(capture_dir.glob("*.png"))
    if not captures:
        print("No captures found")
        return
    
    # Sort by modification time
    captures.sort(key=lambda p: p.stat().st_mtime, reverse=True)
    
    print(f"Found {len(captures)} captures:")
    for i, capture in enumerate(captures[:10]):  # Show last 10
        mtime = datetime.fromtimestamp(capture.stat().st_mtime)
        size = capture.stat().st_size / 1024  # KB
        print(f"  {i+1}. {capture.name}")
        print(f"     Time: {mtime.strftime('%H:%M:%S')}")
        print(f"     Size: {size:.1f} KB")
        
        # Try to get image dimensions
        try:
            from PIL import Image
            img = Image.open(capture)
            print(f"     Dimensions: {img.size[0]}x{img.size[1]}")
        except:
            print(f"     Dimensions: Unknown")
        print()

def monitor_live_for_30_seconds():
    """Monitor the system live for 30 seconds"""
    print("\n🔴 Live Monitoring (30 seconds):")
    print("Watching for app changes and activity...")
    
    try:
        from macos_app_detector import MacOSAppDetector
        detector = MacOSAppDetector()
        
        start_time = time.time()
        last_app = None
        activity_count = 0
        
        while time.time() - start_time < 30:
            current_app = detector.get_frontmost_app()
            
            if current_app and (not last_app or current_app.bundle_id != last_app.bundle_id):
                print(f"[{datetime.now().strftime('%H:%M:%S')}] App Switch: {current_app.name}")
                last_app = current_app
                activity_count += 1
            
            time.sleep(1)
            
        print(f"\nMonitoring complete. Detected {activity_count} app changes in 30 seconds.")
        
    except Exception as e:
        print(f"Live monitoring failed: {e}")

def show_memory_usage():
    """Show current memory usage"""
    print("\n💾 Memory Usage:")
    try:
        import psutil
        process = psutil.Process()
        memory_info = process.memory_info()
        
        print(f"RSS Memory: {memory_info.rss / 1024 / 1024:.1f} MB")
        print(f"VMS Memory: {memory_info.vms / 1024 / 1024:.1f} MB")
        
        # System memory
        vm = psutil.virtual_memory()
        print(f"System Memory: {vm.percent}% used")
        print(f"Available: {vm.available / 1024 / 1024 / 1024:.1f} GB")
        
    except Exception as e:
        print(f"Memory check failed: {e}")

def main():
    """Run all tests"""
    print("🚀 Zeus VLA Current Vision System Analysis")
    print("=" * 50)
    
    # Basic system check
    simple_test()
    
    # Test individual components
    test_app_detection()
    test_workflow_detection()
    
    # Show current state
    test_current_captures()
    show_memory_usage()
    
    # Ask if user wants live monitoring
    print("\n" + "=" * 50)
    response = input("🔴 Run live monitoring for 30 seconds? (y/n): ").lower()
    if response == 'y':
        monitor_live_for_30_seconds()
    
    print("\n✅ Analysis complete!")
    print("\nNext steps:")
    print("1. Review current captures in ~/.continuous_vision/captures/")
    print("2. Check memory usage vs 200MB target")
    print("3. Test temporal queries with real data")
    print("4. Decide on UI approach (Glass/Clueless/Cheating Daddy style)")

if __name__ == "__main__":
    main()