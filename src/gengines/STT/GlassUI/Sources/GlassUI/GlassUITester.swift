import AppKit
import SwiftUI
import Foundation
import GlassUI

/// Test class to verify Glass UI functionality
@MainActor
public class GlassUITester {
    
    private var glassManager: GlassManager!
    private var testResults: [String: Bool] = [:]
    
    public init() {}
    
    public func runAllTests() {
        print("🧪 Starting Glass UI Comprehensive Tests")
        print(String(repeating: "=", count: 50))
        
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
        
        // Test 6: Glass Properties
        testGlassProperties()
        
        // Print Results
        printTestResults()
    }
    
    private func testManagerInitialization() {
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
    
    private func testWindowCreation() {
        print("\n2️⃣ Testing Window Creation...")
        
        guard let screen = NSScreen.main else {
            testResults["window_creation"] = false
            print("   ❌ No screen available")
            return
        }
        
        let window = GlassWindow(forScreen: screen)
        
        let windowExists = true // If we get here, window was created
        let hasCorrectLevel = window.level == .popUpMenu
        let hasCorrectBehavior = window.collectionBehavior.contains(.ignoresCycle)
        let isTransparent = window.backgroundColor == NSColor.clear
        let isNotOpaque = !window.isOpaque
        
        testResults["window_creation"] = windowExists && hasCorrectLevel && hasCorrectBehavior && isTransparent && isNotOpaque
        
        print("   Window exists: \(windowExists)")
        print("   Correct level (.popUpMenu): \(hasCorrectLevel)")
        print("   Correct behavior (.ignoresCycle): \(hasCorrectBehavior)")
        print("   Transparent background: \(isTransparent)")
        print("   Not opaque: \(isNotOpaque)")
        print("   Window frame: \(window.frame)")
        print("   ✅ Window creation: \(testResults["window_creation"]!)")
    }
    
    private func testContentDisplay() {
        print("\n3️⃣ Testing Content Display...")
        
        guard glassManager.isInitialized else {
            testResults["content_display"] = false
            print("   ❌ Manager not initialized")
            return
        }
        
        // Test displaying content
        glassManager.displayVisionSummary(
            "TEST: Glass UI content display verification - you should see this!",
            confidence: 0.95
        )
        
        // Give it a moment to process
        Thread.sleep(forTimeInterval: 0.5)
        
        let isVisible = glassManager.isVisible
        testResults["content_display"] = isVisible
        
        print("   Content displayed: \(isVisible)")
        print("   ✅ Content display: \(testResults["content_display"]!)")
    }
    
    private func testWindowVisibility() {
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
        print("   Window debug info keys: \(windowDebug.keys)")
        
        if let invisibilityValid = windowDebug["invisibilityValid"] as? Bool {
            print("   Window invisibility valid: \(invisibilityValid)")
        }
        
        testResults["window_visibility"] = isInitialized && isVisible
        print("   ✅ Window visibility: \(testResults["window_visibility"]!)")
    }
    
    private func testWindowPositioning() {
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
        let isWithinScreen = screenFrame.intersects(windowFrame)
        
        // Check if window is reasonably sized (400x300 as designed)
        let hasCorrectSize = windowFrame.width == 400 && windowFrame.height == 300
        
        // Check if window is centered
        let expectedX = screenFrame.midX - 200 // 400/2
        let expectedY = screenFrame.midY - 150 // 300/2
        let isCentered = abs(windowFrame.origin.x - expectedX) < 1 && abs(windowFrame.origin.y - expectedY) < 1
        
        testResults["window_positioning"] = isWithinScreen && hasCorrectSize && isCentered
        
        print("   Window frame: \(windowFrame)")
        print("   Screen frame: \(screenFrame)")
        print("   Within screen: \(isWithinScreen)")
        print("   Correct size (400x300): \(hasCorrectSize)")
        print("   Centered: \(isCentered)")
        print("   Expected position: (\(expectedX), \(expectedY))")
        print("   ✅ Window positioning: \(testResults["window_positioning"]!)")
    }
    
    private func testGlassProperties() {
        print("\n6️⃣ Testing Glass Properties...")
        
        guard let screen = NSScreen.main else {
            testResults["glass_properties"] = false
            print("   ❌ No screen available")
            return
        }
        
        let window = GlassWindow(forScreen: screen)
        
        // Test invisibility settings
        let invisibilityValid = window.validateInvisibilitySettings()
        
        // Test click-through
        let hasClickThrough = window.ignoresMouseEvents
        
        // Test can't become key/main (maintains overlay behavior)
        let cantBecomeKey = !window.canBecomeKey
        let cantBecomeMain = !window.canBecomeMain
        
        // Test initial alpha (should be 0)
        let startsInvisible = window.alphaValue == 0.0
        
        testResults["glass_properties"] = invisibilityValid && hasClickThrough && cantBecomeKey && cantBecomeMain && startsInvisible
        
        print("   Invisibility settings valid: \(invisibilityValid)")
        print("   Click-through enabled: \(hasClickThrough)")
        print("   Can't become key: \(cantBecomeKey)")
        print("   Can't become main: \(cantBecomeMain)")
        print("   Starts invisible (alpha=0): \(startsInvisible)")
        print("   ✅ Glass properties: \(testResults["glass_properties"]!)")
    }
    
    private func printTestResults() {
        print("\n" + String(repeating: "=", count: 50))
        print("🎯 Glass UI Test Results")
        print(String(repeating: "=", count: 50))
        
        var passedTests = 0
        let totalTests = testResults.count
        
        for (testName, passed) in testResults.sorted(by: { $0.key < $1.key }) {
            let status = passed ? "✅ PASS" : "❌ FAIL"
            print("   \(testName.replacingOccurrences(of: "_", with: " ").capitalized): \(status)")
            if passed { passedTests += 1 }
        }
        
        print("\n📊 Summary: \(passedTests)/\(totalTests) tests passed")
        
        if passedTests == totalTests {
            print("🎉 All tests passed! Glass UI is working correctly.")
            print("👁️  If you ran this test, you should see a Glass UI window with test content!")
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
    
    public func cleanup() {
        print("\n🧹 Cleaning up...")
        glassManager?.shutdown()
        print("   Cleanup complete")
    }
}