#!/usr/bin/env python3
"""
🤖 Automated App Switching Test - Grok's Solution
Tests real-time app detection with programmatic app switching and performance metrics
"""

import subprocess
import time
import sys
import statistics
from datetime import datetime
from typing import List, Dict, Tuple
from dataclasses import dataclass

# Add current directory to path
sys.path.append('/Users/devin/dblitz/engine/src/gengines/STT')

try:
    from macos_app_detector import MacOSAppDetector
except ImportError as e:
    print(f"❌ Import error: {e}")
    sys.exit(1)

@dataclass
class TestResult:
    app_name: str
    expected: str
    detected: str
    latency_ms: float
    success: bool
    timestamp: datetime

class AutomatedAppSwitchTester:
    def __init__(self):
        self.detector = MacOSAppDetector()
        self.test_results = []
        
    def switch_app(self, app_name: str) -> bool:
        """Switch to application using AppleScript"""
        try:
            script = f'''
            tell application "{app_name}"
                activate
            end tell
            '''
            result = subprocess.run(
                ['osascript', '-e', script],
                capture_output=True,
                text=True,
                timeout=5
            )
            return result.returncode == 0
        except Exception as e:
            print(f"❌ Failed to switch to {app_name}: {e}")
            return False
    
    def wait_for_detection(self, expected_app: str, timeout: float = 2.0) -> Tuple[bool, float, str]:
        """Wait for app detection with latency measurement"""
        start_time = time.time()
        
        while time.time() - start_time < timeout:
            current_app = self.detector.get_frontmost_app()
            if current_app:
                detected_name = current_app.name
                if expected_app.lower() in detected_name.lower():
                    latency = (time.time() - start_time) * 1000  # Convert to ms
                    return True, latency, detected_name
            
            time.sleep(0.01)  # 10ms polling for precise measurement
        
        # Timeout - get final detection
        final_app = self.detector.get_frontmost_app()
        final_name = final_app.name if final_app else "Unknown"
        latency = timeout * 1000
        
        return False, latency, final_name
    
    def test_single_switch(self, app_name: str) -> TestResult:
        """Test switching to a single app"""
        print(f"🔄 Testing switch to {app_name}...")
        
        # Record start time
        start_time = time.time()
        
        # Switch to app
        switch_success = self.switch_app(app_name)
        if not switch_success:
            return TestResult(
                app_name=app_name,
                expected=app_name,
                detected="SWITCH_FAILED",
                latency_ms=0.0,
                success=False,
                timestamp=datetime.now()
            )
        
        # Wait for detection
        detected, latency_ms, detected_name = self.wait_for_detection(app_name)
        
        result = TestResult(
            app_name=app_name,
            expected=app_name,
            detected=detected_name,
            latency_ms=latency_ms,
            success=detected,
            timestamp=datetime.now()
        )
        
        self.test_results.append(result)
        
        status = "✅" if detected else "❌"
        print(f"  {status} {app_name}: {detected_name} ({latency_ms:.1f}ms)")
        
        return result
    
    def test_app_sequence(self, apps: List[str], cycles: int = 5) -> Dict:
        """Test switching between apps in sequence"""
        print(f"🧪 Testing {len(apps)} apps for {cycles} cycles...")
        print("="*60)
        
        all_results = []
        
        for cycle in range(cycles):
            print(f"\n🔄 Cycle {cycle + 1}/{cycles}")
            
            for app in apps:
                result = self.test_single_switch(app)
                all_results.append(result)
                
                # Brief pause between switches
                time.sleep(0.5)
        
        return self.analyze_results(all_results)
    
    def test_cursor_chrome_rapid(self, switches: int = 20) -> Dict:
        """Rapid switching test between Cursor and Chrome"""
        print(f"⚡ Rapid switching test: {switches} switches")
        print("="*50)
        
        apps = ["Cursor", "Google Chrome"]
        results = []
        
        for i in range(switches):
            app = apps[i % 2]
            print(f"Switch {i+1}/{switches}: {app}")
            
            result = self.test_single_switch(app)
            results.append(result)
            
            # Very brief pause for rapid testing
            time.sleep(0.1)
        
        return self.analyze_results(results)
    
    def analyze_results(self, results: List[TestResult]) -> Dict:
        """Analyze test results and generate metrics"""
        if not results:
            return {}
        
        successful = [r for r in results if r.success]
        failed = [r for r in results if not r.success]
        
        latencies = [r.latency_ms for r in successful]
        
        analysis = {
            'total_tests': len(results),
            'successful': len(successful),
            'failed': len(failed),
            'success_rate': len(successful) / len(results) * 100,
            'latency_stats': {
                'mean': statistics.mean(latencies) if latencies else 0,
                'median': statistics.median(latencies) if latencies else 0,
                'min': min(latencies) if latencies else 0,
                'max': max(latencies) if latencies else 0,
                'std_dev': statistics.stdev(latencies) if len(latencies) > 1 else 0
            },
            'target_metrics': {
                'latency_under_100ms': len([l for l in latencies if l < 100]),
                'accuracy_over_95': len(successful) / len(results) > 0.95
            }
        }
        
        return analysis
    
    def print_analysis(self, analysis: Dict):
        """Print detailed analysis"""
        print("\n" + "="*60)
        print("📊 TEST ANALYSIS")
        print("="*60)
        
        print(f"Total Tests: {analysis['total_tests']}")
        print(f"Successful: {analysis['successful']}")
        print(f"Failed: {analysis['failed']}")
        print(f"Success Rate: {analysis['success_rate']:.1f}%")
        
        latency = analysis['latency_stats']
        print(f"\n⏱️  LATENCY METRICS:")
        print(f"  Mean: {latency['mean']:.1f}ms")
        print(f"  Median: {latency['median']:.1f}ms")
        print(f"  Min: {latency['min']:.1f}ms")
        print(f"  Max: {latency['max']:.1f}ms")
        print(f"  Std Dev: {latency['std_dev']:.1f}ms")
        
        targets = analysis['target_metrics']
        print(f"\n🎯 TARGET METRICS:")
        print(f"  Under 100ms: {targets['latency_under_100ms']}/{analysis['successful']}")
        print(f"  >95% Accuracy: {'✅' if targets['accuracy_over_95'] else '❌'}")
        
        # Grok's success criteria
        print(f"\n🚀 GROK'S SUCCESS CRITERIA:")
        print(f"  <100ms Latency: {'✅' if latency['mean'] < 100 else '❌'} ({latency['mean']:.1f}ms)")
        print(f"  >95% Accuracy: {'✅' if analysis['success_rate'] > 95 else '❌'} ({analysis['success_rate']:.1f}%)")
    
    def run_comprehensive_test(self):
        """Run comprehensive test suite"""
        print("🚀 Zeus VLA App Switching - Automated Test Suite")
        print("🔬 Testing Grok's CGWindowList Solution")
        print("="*60)
        
        # Test 1: Basic app switching
        print("\n1️⃣ BASIC APP SWITCHING TEST")
        basic_apps = ["Cursor", "Google Chrome", "Terminal"]
        basic_results = self.test_app_sequence(basic_apps, cycles=3)
        
        # Test 2: Rapid Cursor<->Chrome switching
        print("\n2️⃣ RAPID CURSOR ↔ CHROME TEST")
        rapid_results = self.test_cursor_chrome_rapid(switches=10)
        
        # Print analyses
        print("\n" + "="*60)
        print("1️⃣ BASIC SWITCHING RESULTS")
        self.print_analysis(basic_results)
        
        print("\n" + "="*60)
        print("2️⃣ RAPID SWITCHING RESULTS")
        self.print_analysis(rapid_results)
        
        # Overall assessment
        overall_success_rate = (basic_results.get('success_rate', 0) + rapid_results.get('success_rate', 0)) / 2
        overall_latency = (basic_results.get('latency_stats', {}).get('mean', 0) + rapid_results.get('latency_stats', {}).get('mean', 0)) / 2
        
        print("\n" + "="*60)
        print("🏆 OVERALL ASSESSMENT")
        print("="*60)
        print(f"Average Success Rate: {overall_success_rate:.1f}%")
        print(f"Average Latency: {overall_latency:.1f}ms")
        
        if overall_success_rate > 95 and overall_latency < 100:
            print("🎉 SUCCESS: Grok's solution meets all criteria!")
        else:
            print("⚠️  PARTIAL: Some metrics need improvement")
            
        return {
            'basic': basic_results,
            'rapid': rapid_results,
            'overall_success_rate': overall_success_rate,
            'overall_latency': overall_latency
        }

def main():
    if len(sys.argv) > 1:
        command = sys.argv[1].lower()
        
        tester = AutomatedAppSwitchTester()
        
        if command == 'basic':
            apps = ["Cursor", "Google Chrome"]
            results = tester.test_app_sequence(apps, cycles=2)
            tester.print_analysis(results)
            
        elif command == 'rapid':
            results = tester.test_cursor_chrome_rapid(switches=10)
            tester.print_analysis(results)
            
        elif command == 'chrome':
            result = tester.test_single_switch("Google Chrome")
            print(f"Result: {result}")
            
        elif command == 'cursor':
            result = tester.test_single_switch("Cursor")
            print(f"Result: {result}")
            
        elif command == 'comprehensive':
            tester.run_comprehensive_test()
            
        else:
            print("Usage: python test_app_switching_automated.py [basic|rapid|chrome|cursor|comprehensive]")
            
    else:
        # Default: comprehensive test
        tester = AutomatedAppSwitchTester()
        tester.run_comprehensive_test()

if __name__ == "__main__":
    main()