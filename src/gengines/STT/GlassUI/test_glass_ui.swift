#!/usr/bin/env swift

import AppKit
import SwiftUI
import Foundation

// Add the package path so we can import GlassUI
import GlassUI

/// Test script to verify Glass UI functionality
class GlassUITester {
    
    var glassManager: GlassManager!
    var testResults: [String: Bool] = [:]
    
    func runAllTests() {
        print("🧪 Starting Glass UI Tests")
        print("=" * 50)
        
        // Test 1: Manager Initialization
        testManagerInitialization()
        
        // Test 2: Window Creation
        testWindowCreation()
        
        // Test 3: Content Display
        testContentDisplay()
        
        // Test 4: Window Visibility
        testWindowVisibility()
        
        // Test 5: Window Positioning
        testWindowPositioning()
        
        // Print Results
        printTestResults()
    }
    
    func testManagerInitialization() {
        print("\n1️⃣ Testing Manager Initialization...")
        
        do {
            glassManager = GlassManager.shared
            glassManager.setup()
            
            testResults["manager_initialization"] = glassManager.isInitialized
            print("   ✅ Manager initialized: \(glassManager.isInitialized)")
            
        } catch {
            testResults["manager_initialization"] = false
            print("   ❌ Manager initialization failed: \(error)")
        }
    }
    
    func testWindowCreation() {
        print("\n2️⃣ Testing Window Creation...")
        
        guard let screen = NSScreen.main else {
            testResults["window_creation"] = false
            print("   ❌ No screen available")
            return
        }
        
        let window = GlassWindow(forScreen: screen)
        
        let windowExists = window != nil
        let hasCorrectLevel = window.level == .popUpMenu
        let hasCorrectBehavior = window.collectionBehavior.contains(.ignoresCycle)
        let isTransparent = window.backgroundColor == NSColor.clear
        
        testResults["window_creation"] = windowExists && hasCorrectLevel && hasCorrectBehavior && isTransparent
        
        print("   Window exists: \(windowExists)")
        print("   Correct level (.popUpMenu): \(hasCorrectLevel)")
        print("   Correct behavior (.ignoresCycle): \(hasCorrectBehavior)")
        print("   Transparent background: \(isTransparent)")
        print("   Window frame: \(window.frame)")
        print("   ✅ Window creation: \(testResults["window_creation"]!)")
    }
    
    func testContentDisplay() {
        print("\n3️⃣ Testing Content Display...")
        
        guard glassManager.isInitialized else {
            testResults["content_display"] = false
            print("   ❌ Manager not initialized")
            return
        }
        
        // Test displaying content
        glassManager.displayVisionSummary(
            "TEST: Glass UI content display verification",
            confidence: 0.95
        )
        
        // Give it a moment to process
        Thread.sleep(forTimeInterval: 0.5)
        
        let isVisible = glassManager.isVisible
        testResults["content_display"] = isVisible
        
        print("   Content displayed: \(isVisible)")
        print("   ✅ Content display: \(testResults["content_display"]!)")
    }
    
    func testWindowVisibility() {
        print("\n4️⃣ Testing Window Visibility...")
        
        guard glassManager.isInitialized else {
            testResults["window_visibility"] = false
            print("   ❌ Manager not initialized")
            return
        }
        
        // Get debug info
        let debugInfo = glassManager.getDebugInfo()
        
        let isInitialized = debugInfo["is_initialized"] as? Bool ?? false
        let isVisible = debugInfo["is_visible"] as? Bool ?? false
        let windowDebug = debugInfo["window_debug"] as? [String: Any] ?? [:]
        
        print("   Manager initialized: \(isInitialized)")
        print("   Manager visible: \(isVisible)")
        print("   Window debug info: \(windowDebug)")
        
        testResults["window_visibility"] = isInitialized && isVisible
        print("   ✅ Window visibility: \(testResults["window_visibility"]!)")
    }
    
    func testWindowPositioning() {
        print("\n5️⃣ Testing Window Positioning...")
        
        guard let screen = NSScreen.main else {
            testResults["window_positioning"] = false
            print("   ❌ No screen available")
            return
        }
        
        let window = GlassWindow(forScreen: screen)
        let windowFrame = window.frame
        let screenFrame = screen.frame
        
        // Check if window is within screen bounds
        let isWithinScreen = screenFrame.contains(windowFrame)
        
        // Check if window is reasonably sized (not too small/large)
        let hasReasonableSize = windowFrame.width > 100 && windowFrame.width < screenFrame.width &&
                               windowFrame.height > 100 && windowFrame.height < screenFrame.height
        
        testResults["window_positioning"] = isWithinScreen && hasReasonableSize
        
        print("   Window frame: \(windowFrame)")
        print("   Screen frame: \(screenFrame)")
        print("   Within screen: \(isWithinScreen)")
        print("   Reasonable size: \(hasReasonableSize)")
        print("   ✅ Window positioning: \(testResults["window_positioning"]!)")
    }
    
    func printTestResults() {
        print("\n" + "=" * 50)
        print("🎯 Glass UI Test Results")
        print("=" * 50)
        
        var passedTests = 0
        let totalTests = testResults.count
        
        for (testName, passed) in testResults {
            let status = passed ? "✅ PASS" : "❌ FAIL"
            print("   \(testName): \(status)")
            if passed { passedTests += 1 }
        }
        
        print("\n📊 Summary: \(passedTests)/\(totalTests) tests passed")
        
        if passedTests == totalTests {
            print("🎉 All tests passed! Glass UI is working correctly.")
        } else {
            print("⚠️  Some tests failed. Glass UI may need debugging.")
        }
        
        // Additional diagnostic info
        print("\n🔍 Diagnostic Information:")
        print("   macOS Version: \(ProcessInfo.processInfo.operatingSystemVersionString)")
        print("   Available Screens: \(NSScreen.screens.count)")
        if let mainScreen = NSScreen.main {
            print("   Main Screen: \(mainScreen.frame)")
        }
    }
    
    func cleanup() {
        print("\n🧹 Cleaning up...")
        glassManager?.shutdown()
        print("   Cleanup complete")
    }
}

// Extension to repeat strings (for formatting)
extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}

// Run the tests
let tester = GlassUITester()
tester.runAllTests()
tester.cleanup()

// Exit with appropriate code
let allPassed = tester.testResults.values.allSatisfy { $0 }
exit(allPassed ? 0 : 1)