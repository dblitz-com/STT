import AppKit
import SwiftUI
import GlassUI

/// Main entry point for Zeus VLA Glass UI application
@main
struct ZeusVLAGlassApp: App {
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var glassManager = GlassManager.shared
    
    var body: some Scene {
        // Hidden menu bar app - no main window
        MenuBarExtra("Zeus VLA Glass", systemImage: "eye.circle") {
            VStack {
                Text("Zeus VLA Glass UI")
                    .font(.headline)
                    .padding()
                
                Divider()
                
                Button("Show Glass UI") {
                    // Show glass with some test content
                    print("🔵 Button clicked - showing vision summary")
                    glassManager.displayVisionSummary(
                        "🎯 BUTTON TEST: Glass UI is now visible! This is a test of the vision summary display.",
                        confidence: 0.95
                    )
                    print("🔵 Button action completed")
                }
                .keyboardShortcut("\\", modifiers: .command)
                
                Button("Hide Glass UI") {
                    glassManager.hideGlass()
                }
                .keyboardShortcut(.escape, modifiers: .command)
                
                Divider()
                
                Button("Test Vision Summary") {
                    glassManager.displayVisionSummary(
                        "User is working in Xcode, implementing Glass UI components",
                        confidence: 0.92
                    )
                }
                
                Button("Test Temporal Query") {
                    glassManager.displayTemporalQuery("What did I do 5 minutes ago?")
                    
                    // Simulate result after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        glassManager.displayTemporalResult("5 minutes ago: You were reading Glass UI documentation and implementing Swift components")
                    }
                }
                
                Button("Test Workflow Feedback") {
                    glassManager.displayWorkflowFeedback(
                        "Transitioned from coding to debugging",
                        relationshipType: "FOLLOWS",
                        confidence: 0.85
                    )
                }
                
                Button("Test Health Status") {
                    let memory = Int.random(in: 200...450)
                    let cpu = Int.random(in: 5...15)
                    let latency = Int.random(in: 50...200)
                    glassManager.displayHealthStatus(memory: memory, cpu: cpu, latency: latency)
                }
                
                Divider()
                
                Button("Debug Info") {
                    let debugInfo = glassManager.getDebugInfo()
                    print("=== Glass UI Debug Info ===")
                    for (key, value) in debugInfo {
                        print("\(key): \(value)")
                    }
                }
                
                Button("Test Invisibility") {
                    Task {
                        let isInvisible = await glassManager.testInvisibility()
                        print("Invisibility test result: \(isInvisible ? "PASS" : "FAIL")")
                    }
                }
                
                Button("🧪 Run Full Glass UI Test") {
                    Task { @MainActor in
                        let tester = GlassUITester()
                        tester.runAllTests()
                        
                        // Keep the test window visible for 5 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                            tester.cleanup()
                        }
                    }
                }
                
                Divider()
                
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
            .padding()
        }
        .menuBarExtraStyle(.window)
    }
}

/// Application delegate for handling app lifecycle
class AppDelegate: NSObject, NSApplicationDelegate {
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 Zeus VLA Glass UI starting...")
        
        // Initialize Glass Manager
        GlassManager.shared.setup()
        
        // Keep dock icon visible for testing
        NSApp.setActivationPolicy(.regular)
        
        print("✅ Zeus VLA Glass UI ready")
        print("📖 Look for the eye icon in your menu bar")
        print("📖 Keyboard shortcuts:")
        print("   ⌘ + \\ : Toggle Glass UI")
        print("   ⌘ + Enter : Quick AI query")
        print("   ⌘ + Escape : Hide Glass UI")
        print("   ⌘ + Arrow keys : Reposition Glass UI")
        
        // Show test content immediately
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("🧪 Auto-showing test content...")
            GlassManager.shared.displayVisionSummary(
                "AUTO-TEST: Glass UI should be visible now!",
                confidence: 0.95
            )
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        print("🔄 Zeus VLA Glass UI shutting down...")
        GlassManager.shared.shutdown()
        print("✅ Shutdown complete")
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool {
        // Don't terminate when last window closes (menu bar app)
        return false
    }
}

// App delegate is handled automatically by @main

/// Command line interface for testing
struct CommandLineInterface {
    static func main() {
        let arguments = CommandLine.arguments
        
        if arguments.count > 1 {
            switch arguments[1] {
            case "test-invisibility":
                testInvisibility()
            case "test-performance":
                testPerformance()
            case "debug":
                showDebugInfo()
            default:
                showUsage()
            }
        } else {
            // Start normal GUI app
            let app = NSApplication.shared
            app.setActivationPolicy(.regular)
            
            let delegate = AppDelegate()
            app.delegate = delegate
            
            app.run()
        }
    }
    
    static func testInvisibility() {
        print("🧪 Testing Glass UI invisibility...")
        
        let manager = GlassManager.shared
        manager.setup()
        
        Task {
            let result = await manager.testInvisibility()
            print("Invisibility test: \(result ? "✅ PASS" : "❌ FAIL")")
            
            if result {
                print("Glass UI is properly configured for screen recording invisibility")
            } else {
                print("Glass UI may be visible in screen recordings")
            }
            
            exit(result ? 0 : 1)
        }
        
        RunLoop.main.run()
    }
    
    static func testPerformance() {
        print("🚀 Testing Glass UI performance...")
        
        let manager = GlassManager.shared
        manager.setup()
        
        // Test rendering performance
        let startTime = Date()
        
        for i in 0..<100 {
            manager.displayVisionSummary("Performance test iteration \(i)", confidence: 0.9)
            usleep(16000) // 16ms delay (60 FPS)
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        let averageRenderTime = duration / 100.0
        
        print("Performance test results:")
        print("  Average render time: \(averageRenderTime * 1000.0)ms")
        print("  Target: <16ms")
        print("  Result: \(averageRenderTime < 0.016 ? "✅ PASS" : "❌ FAIL")")
        
        manager.shutdown()
        exit(averageRenderTime < 0.016 ? 0 : 1)
    }
    
    static func showDebugInfo() {
        print("🔍 Glass UI Debug Information")
        
        let manager = GlassManager.shared
        manager.setup()
        
        let debugInfo = manager.getDebugInfo()
        
        print("=== Glass UI Debug Info ===")
        for (key, value) in debugInfo {
            print("\(key): \(value)")
        }
        
        manager.shutdown()
    }
    
    static func showUsage() {
        print("Zeus VLA Glass UI")
        print("Usage: ZeusVLAGlass [command]")
        print("")
        print("Commands:")
        print("  test-invisibility  Test screen recording invisibility")
        print("  test-performance   Test rendering performance")
        print("  debug             Show debug information")
        print("  (no command)      Start GUI application")
        print("")
        print("GUI Keyboard Shortcuts:")
        print("  ⌘ + \\            Toggle Glass UI")
        print("  ⌘ + Enter         Quick AI query")
        print("  ⌘ + Escape        Hide Glass UI")
        print("  ⌘ + Arrow keys    Reposition Glass UI")
    }
}

// Command line interface removed - use main app instead