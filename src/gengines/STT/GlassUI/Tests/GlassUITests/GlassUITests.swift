import XCTest
import AppKit
import SwiftUI
@testable import GlassUI

/// Test suite for Glass UI implementation
@MainActor
final class GlassUITests: XCTestCase {
    
    var glassManager: GlassManager!
    
    override func setUpWithError() throws {
        glassManager = GlassManager.shared
        // Skip GUI setup in tests to avoid crashes
        // glassManager.setup()
    }
    
    override func tearDownWithError() throws {
        // glassManager.shutdown()
    }
    
    // MARK: - Glass Window Tests
    
    func testGlassWindowCreation() throws {
        // Skip GUI tests in CI environment
        guard NSScreen.main != nil else {
            throw XCTSkip("No display available for GUI tests")
        }
        
        let window = GlassWindow(forScreen: NSScreen.main!)
        
        XCTAssertNotNil(window)
        XCTAssertEqual(window.level, .popUpMenu)
        XCTAssertTrue(window.collectionBehavior.contains(.ignoresCycle))
        XCTAssertEqual(window.backgroundColor, NSColor.clear)
        XCTAssertFalse(window.isOpaque)
        XCTAssertTrue(window.ignoresMouseEvents)
        XCTAssertEqual(window.alphaValue, 0.0)
    }
    
    func testGlassWindowInvisibilitySettings() throws {
        // Skip GUI tests in CI environment
        guard NSScreen.main != nil else {
            throw XCTSkip("No display available for GUI tests")
        }
        
        let window = GlassWindow(forScreen: NSScreen.main!)
        
        XCTAssertTrue(window.validateInvisibilitySettings())
        
        // Test individual settings
        XCTAssertTrue(window.level == .popUpMenu || window.level == .screenSaver)
        XCTAssertTrue(window.collectionBehavior.contains(.ignoresCycle))
        XCTAssertFalse(window.isOpaque)
        XCTAssertEqual(window.backgroundColor, NSColor.clear)
        XCTAssertTrue(window.ignoresMouseEvents)
    }
    
    func testGlassWindowFadeInOut() {
        let window = GlassWindow(forScreen: NSScreen.main!)
        
        // Test fade in
        window.fadeIn(duration: 0.1)
        
        // Use expectation for animation
        let fadeInExpectation = XCTestExpectation(description: "Fade in animation")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            XCTAssertGreaterThan(window.alphaValue, 0.0)
            fadeInExpectation.fulfill()
        }
        
        wait(for: [fadeInExpectation], timeout: 1.0)
        
        // Test fade out
        window.fadeOut(duration: 0.1)
        
        let fadeOutExpectation = XCTestExpectation(description: "Fade out animation")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            XCTAssertEqual(window.alphaValue, 0.0)
            fadeOutExpectation.fulfill()
        }
        
        wait(for: [fadeOutExpectation], timeout: 1.0)
    }
    
    func testGlassWindowAdaptiveOpacity() {
        let window = GlassWindow(forScreen: NSScreen.main!)
        
        // Test setting adaptive opacity
        window.setAdaptiveOpacity(0.7)
        window.fadeIn(duration: 0.1)
        
        let opacityExpectation = XCTestExpectation(description: "Adaptive opacity")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            XCTAssertEqual(window.alphaValue, 0.7, accuracy: 0.01)
            opacityExpectation.fulfill()
        }
        
        wait(for: [opacityExpectation], timeout: 1.0)
    }
    
    func testGlassWindowPerformanceOptimization() {
        let window = GlassWindow(forScreen: NSScreen.main!)
        
        window.optimizeRendering()
        
        XCTAssertNotNil(window.contentView?.layer)
        XCTAssertTrue(window.contentView?.wantsLayer ?? false)
        
        if let layer = window.contentView?.layer {
            XCTAssertFalse(layer.isOpaque)
            XCTAssertEqual(layer.backgroundColor, NSColor.clear.cgColor)
            XCTAssertTrue(layer.allowsEdgeAntialiasing)
            XCTAssertTrue(layer.allowsGroupOpacity)
        }
    }
    
    // MARK: - Glass View Model Tests
    
    func testGlassViewModelInitialization() {
        let viewModel = GlassViewModel()
        
        XCTAssertFalse(viewModel.isVisible)
        XCTAssertEqual(viewModel.currentMode, .hidden)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertEqual(viewModel.visionSummary, "")
        XCTAssertEqual(viewModel.visionConfidence, 0.0)
        XCTAssertEqual(viewModel.temporalQuery, "")
        XCTAssertEqual(viewModel.temporalResult, "")
        XCTAssertEqual(viewModel.workflowTransition, "")
        XCTAssertEqual(viewModel.relationshipType, "")
        XCTAssertEqual(viewModel.relationshipConfidence, 0.0)
        XCTAssertEqual(viewModel.memoryUsage, 0)
        XCTAssertEqual(viewModel.cpuUsage, 0)
        XCTAssertEqual(viewModel.latency, 0)
    }
    
    func testGlassViewModelVisionSummary() {
        let viewModel = GlassViewModel()
        
        viewModel.showVisionSummary("Test summary", confidence: 0.85)
        
        XCTAssertTrue(viewModel.isVisible)
        XCTAssertEqual(viewModel.currentMode, .visionSummary)
        XCTAssertEqual(viewModel.visionSummary, "Test summary")
        XCTAssertEqual(viewModel.visionConfidence, 0.85)
        XCTAssertTrue(viewModel.validateVisionData())
    }
    
    func testGlassViewModelTemporalQuery() {
        let viewModel = GlassViewModel()
        
        viewModel.showTemporalQuery("What did I do?")
        
        XCTAssertTrue(viewModel.isVisible)
        XCTAssertEqual(viewModel.currentMode, .temporalQuery)
        XCTAssertEqual(viewModel.temporalQuery, "What did I do?")
        XCTAssertEqual(viewModel.temporalResult, "")
        XCTAssertTrue(viewModel.isLoading)
        XCTAssertTrue(viewModel.validateTemporalData())
        
        viewModel.showTemporalResult("You were coding")
        
        XCTAssertEqual(viewModel.temporalResult, "You were coding")
        XCTAssertFalse(viewModel.isLoading)
    }
    
    func testGlassViewModelWorkflowFeedback() {
        let viewModel = GlassViewModel()
        
        viewModel.showWorkflowFeedback("Coding to debugging", relationshipType: "FOLLOWS", confidence: 0.9)
        
        XCTAssertTrue(viewModel.isVisible)
        XCTAssertEqual(viewModel.currentMode, .workflowFeedback)
        XCTAssertEqual(viewModel.workflowTransition, "Coding to debugging")
        XCTAssertEqual(viewModel.relationshipType, "FOLLOWS")
        XCTAssertEqual(viewModel.relationshipConfidence, 0.9)
        XCTAssertTrue(viewModel.validateWorkflowData())
    }
    
    func testGlassViewModelHealthStatus() {
        let viewModel = GlassViewModel()
        
        viewModel.showHealthStatus(memory: 350, cpu: 25, latency: 150)
        
        XCTAssertTrue(viewModel.isVisible)
        XCTAssertEqual(viewModel.currentMode, .healthStatus)
        XCTAssertEqual(viewModel.memoryUsage, 350)
        XCTAssertEqual(viewModel.cpuUsage, 25)
        XCTAssertEqual(viewModel.latency, 150)
        XCTAssertTrue(viewModel.validateHealthData())
    }
    
    func testGlassViewModelAutoHide() {
        let viewModel = GlassViewModel()
        viewModel.setAutoHideDelay(0.1) // Short delay for testing
        
        viewModel.showVisionSummary("Test", confidence: 0.5)
        XCTAssertTrue(viewModel.isVisible)
        
        let autoHideExpectation = XCTestExpectation(description: "Auto hide")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            XCTAssertFalse(viewModel.isVisible)
            autoHideExpectation.fulfill()
        }
        
        wait(for: [autoHideExpectation], timeout: 1.0)
    }
    
    func testGlassViewModelXPCDataUpdate() {
        let viewModel = GlassViewModel()
        
        let xpcData: [String: Any] = [
            "vision_data": [
                "summary": "XPC test summary",
                "confidence": 0.95
            ],
            "temporal_data": [
                "query": "XPC test query",
                "result": "XPC test result"
            ],
            "workflow_data": [
                "transition": "XPC workflow transition",
                "relationship_type": "TRIGGERS",
                "confidence": 0.8
            ],
            "health_data": [
                "memory_mb": 400,
                "cpu_percent": 30,
                "latency_ms": 200
            ]
        ]
        
        viewModel.updateFromXPCData(xpcData)
        
        XCTAssertEqual(viewModel.visionSummary, "XPC test summary")
        XCTAssertEqual(viewModel.visionConfidence, 0.95)
        XCTAssertEqual(viewModel.temporalQuery, "XPC test query")
        XCTAssertEqual(viewModel.temporalResult, "XPC test result")
        XCTAssertEqual(viewModel.workflowTransition, "XPC workflow transition")
        XCTAssertEqual(viewModel.relationshipType, "TRIGGERS")
        XCTAssertEqual(viewModel.relationshipConfidence, 0.8)
        XCTAssertEqual(viewModel.memoryUsage, 400)
        XCTAssertEqual(viewModel.cpuUsage, 30)
        XCTAssertEqual(viewModel.latency, 200)
    }
    
    func testGlassViewModelReset() {
        let viewModel = GlassViewModel()
        
        // Set some data
        viewModel.showVisionSummary("Test", confidence: 0.5)
        viewModel.showWorkflowFeedback("Test transition", relationshipType: "FOLLOWS", confidence: 0.7)
        
        // Reset
        viewModel.reset()
        
        XCTAssertFalse(viewModel.isVisible)
        XCTAssertEqual(viewModel.currentMode, .hidden)
        XCTAssertEqual(viewModel.visionSummary, "")
        XCTAssertEqual(viewModel.visionConfidence, 0.0)
        XCTAssertEqual(viewModel.workflowTransition, "")
        XCTAssertEqual(viewModel.relationshipType, "")
        XCTAssertEqual(viewModel.relationshipConfidence, 0.0)
    }
    
    // MARK: - Glass Manager Tests
    
    func testGlassManagerInitialization() {
        XCTAssertTrue(glassManager.isInitialized)
        XCTAssertFalse(glassManager.isVisible)
        XCTAssertNil(glassManager.currentError)
    }
    
    func testGlassManagerShowHide() {
        glassManager.showGlass()
        XCTAssertTrue(glassManager.isVisible)
        
        glassManager.hideGlass()
        XCTAssertFalse(glassManager.isVisible)
    }
    
    func testGlassManagerToggle() {
        let initialState = glassManager.isVisible
        
        glassManager.toggleGlass()
        XCTAssertNotEqual(glassManager.isVisible, initialState)
        
        glassManager.toggleGlass()
        XCTAssertEqual(glassManager.isVisible, initialState)
    }
    
    func testGlassManagerContentDisplay() {
        glassManager.displayVisionSummary("Test vision summary", confidence: 0.8)
        XCTAssertTrue(glassManager.isVisible)
        
        glassManager.displayTemporalQuery("Test query")
        XCTAssertTrue(glassManager.isVisible)
        
        glassManager.displayWorkflowFeedback("Test workflow", relationshipType: "TRIGGERS", confidence: 0.9)
        XCTAssertTrue(glassManager.isVisible)
        
        glassManager.displayHealthStatus(memory: 300, cpu: 20, latency: 100)
        XCTAssertTrue(glassManager.isVisible)
    }
    
    func testGlassManagerDebugInfo() {
        let debugInfo = glassManager.getDebugInfo()
        
        XCTAssertNotNil(debugInfo["is_initialized"])
        XCTAssertNotNil(debugInfo["is_visible"])
        XCTAssertNotNil(debugInfo["keyboard_shortcuts_enabled"])
        XCTAssertNotNil(debugInfo["xpc_base_url"])
        
        XCTAssertTrue(debugInfo["is_initialized"] as? Bool ?? false)
        XCTAssertEqual(debugInfo["xpc_base_url"] as? String, "http://localhost:5002")
    }
    
    // MARK: - Performance Tests
    
    func testGlassWindowRenderingPerformance() {
        let window = GlassWindow(forScreen: NSScreen.main!)
        window.optimizeRendering()
        
        measure {
            for _ in 0..<100 {
                window.fadeIn(duration: 0.001)
                window.fadeOut(duration: 0.001)
            }
        }
    }
    
    func testGlassViewModelUpdatePerformance() {
        let viewModel = GlassViewModel()
        
        measure {
            for i in 0..<100 {
                viewModel.showVisionSummary("Performance test \(i)", confidence: 0.9)
                viewModel.hide()
            }
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testGlassErrorHandling() {
        let screenNotFoundError = GlassError.screenNotFound
        XCTAssertEqual(screenNotFoundError.errorDescription, "Main screen not found")
        
        let windowCreationError = GlassError.windowCreationFailed
        XCTAssertEqual(windowCreationError.errorDescription, "Failed to create Glass window")
        
        let xpcConnectionError = GlassError.xpcConnectionFailed
        XCTAssertEqual(xpcConnectionError.errorDescription, "Failed to connect to XPC service")
        
        let keyboardShortcutsError = GlassError.keyboardShortcutsFailed
        XCTAssertEqual(keyboardShortcutsError.errorDescription, "Failed to setup keyboard shortcuts")
    }
    
    // MARK: - Integration Tests
    
    func testFullIntegrationFlow() {
        // Test complete flow from manager to window to view
        glassManager.displayVisionSummary("Integration test summary", confidence: 0.95)
        
        XCTAssertTrue(glassManager.isVisible)
        
        // Test that the view model is updated
        let debugInfo = glassManager.getDebugInfo()
        XCTAssertNotNil(debugInfo["view_model_metrics"])
        
        // Test hiding
        glassManager.hideGlass()
        XCTAssertFalse(glassManager.isVisible)
    }
    
    func testKeyboardShortcutConfiguration() {
        glassManager.setKeyboardShortcutsEnabled(false)
        
        let debugInfo = glassManager.getDebugInfo()
        XCTAssertFalse(debugInfo["keyboard_shortcuts_enabled"] as? Bool ?? true)
        
        glassManager.setKeyboardShortcutsEnabled(true)
        
        let debugInfo2 = glassManager.getDebugInfo()
        XCTAssertTrue(debugInfo2["keyboard_shortcuts_enabled"] as? Bool ?? false)
    }
    
    func testInvisibilityValidation() async {
        let result = await glassManager.testInvisibility()
        XCTAssertTrue(result)
    }
}