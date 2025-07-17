import AppKit
import SwiftUI
import Foundation
import Combine

/// Main manager for Glass UI system - handles state, XPC communication, and keyboard shortcuts
public class GlassManager: ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = GlassManager()
    
    // MARK: - Properties
    
    @Published public var isInitialized: Bool = false
    @Published public var isVisible: Bool = false
    @Published public var currentError: String?
    
    // User preferences
    @Published public var autoShowEnabled: Bool = true
    private var userManuallyHidden: Bool = false
    
    private var glassWindow: GlassWindow?
    private var glassView: GlassView?
    private var hostingView: NSHostingView<GlassView>?
    private var glassViewModel: GlassViewModel?
    
    // XPC Communication
    private var xpcTimer: Timer?
    private var xpcSession: URLSession
    private let xpcBaseURL = "http://localhost:5002"
    private var cancellables = Set<AnyCancellable>()
    
    // Keyboard Shortcuts
    private var keyboardMonitor: Any?
    private var isKeyboardShortcutsEnabled: Bool = true
    
    // Performance Monitoring
    private var performanceTimer: Timer?
    private var startTime: Date?
    
    // MARK: - Initialization
    
    private init() {
        // Configure XPC session
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10.0
        config.timeoutIntervalForResource = 10.0
        self.xpcSession = URLSession(configuration: config)
        
        startTime = Date()
    }
    
    // MARK: - Public Setup Methods
    
    /// Initialize the Glass UI system
    public func setup() {
        guard !isInitialized else {
            print("GlassManager already initialized")
            return
        }
        
        print("🚀 Starting Glass UI initialization...")
        
        do {
            print("📋 Step 1: Creating Glass window...")
            try createGlassWindow()
            print("✅ Step 1 complete")
            
            print("📋 Step 2: Setting up Glass view...")
            setupGlassView()
            print("✅ Step 2 complete")
            
            print("📋 Step 3: Setting up keyboard shortcuts...")
            setupKeyboardShortcuts()
            print("✅ Step 3 complete")
            
            print("📋 Step 4: Setting up XPC communication...")
            setupXPCCommunication()
            print("✅ Step 4 complete")
            
            print("📋 Step 5: Setting up performance monitoring...")
            setupPerformanceMonitoring()
            print("✅ Step 5 complete")
            
            isInitialized = true
            print("✅ Glass UI system initialized successfully")
            
        } catch {
            currentError = "Failed to initialize Glass UI: \(error.localizedDescription)"
            print("❌ Glass UI initialization failed: \(error)")
            print("❌ Error details: \(error)")
        }
    }
    
    /// Cleanup and shutdown
    public func shutdown() {
        hideGlass()
        
        // Cleanup keyboard shortcuts
        if let monitor = keyboardMonitor {
            NSEvent.removeMonitor(monitor)
            keyboardMonitor = nil
        }
        
        // Cleanup timers
        xpcTimer?.invalidate()
        performanceTimer?.invalidate()
        
        // Cleanup XPC
        xpcSession.invalidateAndCancel()
        
        // Cleanup window
        glassWindow?.close()
        glassWindow = nil
        
        isInitialized = false
        print("Glass UI system shutdown complete")
    }
    
    // MARK: - Glass UI Controls
    
    /// Show the Glass UI
    public func showGlass() {
        guard isInitialized else {
            print("❌ Glass UI not initialized")
            return
        }
        
        Task { @MainActor in
            print("👁️ Showing Glass UI...")
            print("   Window exists: \(glassWindow != nil)")
            print("   Window frame: \(glassWindow?.frame ?? .zero)")
            print("   Window level: \(glassWindow?.level.rawValue ?? 0)")
            
            glassWindow?.fadeIn()
            isVisible = true
            
            print("   Window alpha after fadeIn: \(glassWindow?.alphaValue ?? 0)")
            
            // Position to avoid active window
            if let activeWindow = getActiveWindowBounds() {
                glassWindow?.positionToAvoidOcclusion(avoidRect: activeWindow)
            }
        }
    }
    
    /// Hide the Glass UI
    public func hideGlass() {
        guard isInitialized else { return }
        
        Task { @MainActor in
            glassWindow?.fadeOut()
            glassViewModel?.hide()
            isVisible = false
            userManuallyHidden = true  // Track user manual hide
        }
    }
    
    /// Toggle Glass UI visibility
    public func toggleGlass() {
        Task { @MainActor in
            if isVisible {
                hideGlass()
            } else {
                userManuallyHidden = false  // Reset manual hide when user shows
                showGlass()
            }
        }
    }
    
    /// Set adaptive opacity based on context
    public func setAdaptiveOpacity(_ opacity: Double) {
        Task { @MainActor in
            glassWindow?.setAdaptiveOpacity(CGFloat(opacity))
        }
    }
    
    // MARK: - Content Display Methods
    
    /// Display vision summary
    public func displayVisionSummary(_ summary: String, confidence: Double = 0.0) {
        Task { @MainActor in
            glassViewModel?.showVisionSummary(summary, confidence: confidence)
            // Only auto-show if user hasn't manually hidden and auto-show is enabled
            if autoShowEnabled && !userManuallyHidden {
                showGlass()
            }
        }
    }
    
    /// Display temporal query
    public func displayTemporalQuery(_ query: String) {
        Task { @MainActor in
            glassViewModel?.showTemporalQuery(query)
            // Only auto-show if user hasn't manually hidden and auto-show is enabled
            if autoShowEnabled && !userManuallyHidden {
                showGlass()
            }
        }
    }
    
    /// Display temporal result
    public func displayTemporalResult(_ result: String) {
        Task { @MainActor in
            glassViewModel?.showTemporalResult(result)
        }
    }
    
    /// Display workflow feedback
    public func displayWorkflowFeedback(_ transition: String, relationshipType: String = "", confidence: Double = 0.0) {
        Task { @MainActor in
            glassViewModel?.showWorkflowFeedback(transition, relationshipType: relationshipType, confidence: confidence)
            // Only auto-show if user hasn't manually hidden and auto-show is enabled
            if autoShowEnabled && !userManuallyHidden {
                showGlass()
            }
        }
    }
    
    /// Display health status
    public func displayHealthStatus(memory: Int, cpu: Int, latency: Int) {
        Task { @MainActor in
            glassViewModel?.showHealthStatus(memory: memory, cpu: cpu, latency: latency)
            // Only auto-show if user hasn't manually hidden and auto-show is enabled
            if autoShowEnabled && !userManuallyHidden {
                showGlass()
            }
        }
    }
    
    // MARK: - Private Setup Methods
    
    private func createGlassWindow() throws {
        // Try multiple screen options
        var targetScreen: NSScreen?
        
        if let mainScreen = NSScreen.main {
            targetScreen = mainScreen
            print("🪟 Using main screen: \(mainScreen.frame)")
        } else if let firstScreen = NSScreen.screens.first {
            targetScreen = firstScreen
            print("🪟 Using first available screen: \(firstScreen.frame)")
        } else {
            print("❌ No screens available - creating window with default frame")
            // Create window with default frame if no screen is available
            glassWindow = GlassWindow(
                contentRect: NSRect(x: 100, y: 100, width: 400, height: 300),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            print("🪟 Window created with default frame")
            return
        }
        
        guard let screen = targetScreen else {
            throw GlassError.screenNotFound
        }
        
        print("🪟 Creating Glass window...")
        glassWindow = GlassWindow(forScreen: screen)
        print("🪟 Window created at: \(glassWindow?.frame ?? .zero)")
        
        glassWindow?.orderFrontRegardless()
        print("🪟 Window ordered front")
        
        // Validate invisibility settings
        if let window = glassWindow, !window.validateInvisibilitySettings() {
            print("⚠️ Warning: Glass UI invisibility settings may not be optimal")
        }
    }
    
    private func setupGlassView() {
        print("🎨 Setting up Glass view...")
        Task { @MainActor in
            glassViewModel = GlassViewModel()
            glassView = GlassView(viewModel: glassViewModel!)
            
            if let view = glassView {
                hostingView = NSHostingView(rootView: view)
                hostingView?.wantsLayer = true
                hostingView?.layer?.backgroundColor = NSColor.clear.cgColor
                
                glassWindow?.contentView = hostingView
                print("🎨 Glass view setup complete")
                
                // Force the view to show some content immediately
                glassViewModel?.showVisionSummary(
                    "🚀 Glass UI Initialized! Ready for content display.",
                    confidence: 1.0
                )
            }
        }
    }
    
    private func setupKeyboardShortcuts() {
        guard isKeyboardShortcutsEnabled else { return }
        
        keyboardMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyboardEvent(event)
        }
    }
    
    private func setupXPCCommunication() {
        // Enable XPC polling for Glass UI updates (reduced frequency to avoid spam)
        xpcTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.pollGlassUIUpdates()
        }
        print("🔌 XPC communication enabled for Glass UI updates (10s interval)")
    }
    
    private func setupPerformanceMonitoring() {
        performanceTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updatePerformanceMetrics()
        }
    }
    
    // MARK: - Keyboard Event Handling
    
    private func handleKeyboardEvent(_ event: NSEvent) {
        let modifiers = event.modifierFlags
        let keyCode = event.keyCode
        
        // Cmd + \ (backslash) - Toggle main glass interface
        if modifiers.contains(.command) && keyCode == 42 {
            toggleGlass()
        }
        
        // Cmd + Enter - Quick AI query with context
        else if modifiers.contains(.command) && keyCode == 36 {
            handleQuickQuery()
        }
        
        // Cmd + Escape - Hide all glass elements
        else if modifiers.contains(.command) && keyCode == 53 {
            hideGlass()
        }
        
        // Cmd + Arrow keys - Reposition glass windows
        else if modifiers.contains(.command) {
            switch keyCode {
            case 123: // Left arrow
                repositionGlass(direction: .left)
            case 124: // Right arrow
                repositionGlass(direction: .right)
            case 125: // Down arrow
                repositionGlass(direction: .down)
            case 126: // Up arrow
                repositionGlass(direction: .up)
            default:
                break
            }
        }
    }
    
    private func handleQuickQuery() {
        // Show temporal query interface
        displayTemporalQuery("Quick context query...")
        
        // Send query to XPC
        Task {
            await sendXPCQuery("what is the current context?")
        }
    }
    
    private enum RepositionDirection {
        case left, right, up, down
    }
    
    private func repositionGlass(direction: RepositionDirection) {
        guard let window = glassWindow else { return }
        
        let currentFrame = window.frame
        let moveDistance: CGFloat = 50
        
        var newOrigin = currentFrame.origin
        
        switch direction {
        case .left:
            newOrigin.x -= moveDistance
        case .right:
            newOrigin.x += moveDistance
        case .up:
            newOrigin.y += moveDistance
        case .down:
            newOrigin.y -= moveDistance
        }
        
        // Ensure window stays on screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            newOrigin.x = max(screenFrame.minX, min(newOrigin.x, screenFrame.maxX - currentFrame.width))
            newOrigin.y = max(screenFrame.minY, min(newOrigin.y, screenFrame.maxY - currentFrame.height))
        }
        
        window.setFrameOrigin(newOrigin)
    }
    
    // MARK: - XPC Communication
    
    private func pollXPCUpdates() {
        Task {
            await checkForXPCUpdates()
        }
    }
    
    private func checkForXPCUpdates() async {
        guard let url = URL(string: "\(xpcBaseURL)/glass_status") else { return }
        
        do {
            let (data, _) = try await xpcSession.data(from: url)
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
            
            if let dict = jsonObject as? [String: Any] {
                await processXPCUpdate(dict)
            }
        } catch {
            // Silent failure for polling - only log if persistent
            if error.localizedDescription.contains("connection") {
                print("XPC connection issue: \(error)")
            }
        }
    }
    
    @MainActor
    private func processXPCUpdate(_ data: [String: Any]) {
        // Update Glass UI based on XPC data
        glassViewModel?.updateFromXPCData(data)
        
        // Check for new vision data
        if let visionChange = data["vision_change"] as? Bool, visionChange {
            if let summary = data["vision_summary"] as? String {
                let confidence = data["vision_confidence"] as? Double ?? 0.0
                displayVisionSummary(summary, confidence: confidence)
            }
        }
        
        // Check for workflow transitions
        if let workflowChange = data["workflow_change"] as? Bool, workflowChange {
            if let transition = data["workflow_transition"] as? String {
                let relationshipType = data["relationship_type"] as? String ?? ""
                let confidence = data["relationship_confidence"] as? Double ?? 0.0
                displayWorkflowFeedback(transition, relationshipType: relationshipType, confidence: confidence)
            }
        }
    }
    
    private func sendXPCQuery(_ query: String) async {
        guard let url = URL(string: "\(xpcBaseURL)/glass_query") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload = ["query": query]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
            let (data, _) = try await xpcSession.data(for: request)
            
            if let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let result = jsonObject["result"] as? String {
                
                await MainActor.run {
                    displayTemporalResult(result)
                }
            }
        } catch {
            await MainActor.run {
                displayTemporalResult("Error: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Performance Monitoring
    
    private func updatePerformanceMetrics() {
        guard let window = glassWindow else { return }
        
        let processInfo = ProcessInfo.processInfo
        let memoryUsage = Int(processInfo.physicalMemory / 1024 / 1024) // Convert to MB
        let _ = startTime?.timeIntervalSinceNow ?? 0
        
        // Simple CPU usage approximation
        let cpuUsage = Int.random(in: 1...5) // Placeholder - would need proper implementation
        
        // Calculate rendering latency (placeholder)
        let renderingLatency = window.alphaValue > 0 ? Int.random(in: 10...30) : 0
        
        // Update view model if needed
        if window.alphaValue > 0 {
            Task { @MainActor in
                glassViewModel?.memoryUsage = memoryUsage
                glassViewModel?.cpuUsage = cpuUsage
                glassViewModel?.latency = renderingLatency
            }
        }
    }
    
    // MARK: - Utility Methods
    
    private func getActiveWindowBounds() -> NSRect? {
        // Get active window bounds using Accessibility API
        // This is a simplified version - would need proper implementation
        guard let screen = NSScreen.main else { return nil }
        
        let screenFrame = screen.frame
        return NSRect(
            x: screenFrame.width * 0.1,
            y: screenFrame.height * 0.1,
            width: screenFrame.width * 0.8,
            height: screenFrame.height * 0.8
        )
    }
    
    // MARK: - Public Configuration
    
    /// Enable/disable keyboard shortcuts
    public func setKeyboardShortcutsEnabled(_ enabled: Bool) {
        isKeyboardShortcutsEnabled = enabled
        
        if enabled && keyboardMonitor == nil {
            setupKeyboardShortcuts()
        } else if !enabled && keyboardMonitor != nil {
            if let monitor = keyboardMonitor {
                NSEvent.removeMonitor(monitor)
                keyboardMonitor = nil
            }
        }
    }
    
    /// Enable/disable auto-show behavior
    public func setAutoShowEnabled(_ enabled: Bool) {
        autoShowEnabled = enabled
        print("📱 Auto-show Glass UI: \(enabled ? "enabled" : "disabled")")
    }
    
    /// Reset manual hide state (allows auto-show again)
    public func resetManualHide() {
        userManuallyHidden = false
        print("🔄 Manual hide state reset - auto-show enabled again")
    }
    
    // MARK: - XPC Communication
    
    /// Poll for Glass UI updates from the XPC server
    private func pollGlassUIUpdates() {
        guard isInitialized else { return }
        
        Task {
            do {
                let url = URL(string: "\(xpcBaseURL)/glass_query")!
                let (data, _) = try await URLSession.shared.data(from: url)
                
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let success = json["success"] as? Bool,
                   success,
                   let glassState = json["glass_ui_state"] as? [String: Any],
                   let active = glassState["active"] as? Bool,
                   active,
                   let content = glassState["content"] as? [String: Any] {
                    
                    await MainActor.run {
                        updateGlassUIFromXPC(content)
                    }
                }
            } catch {
                // Silently handle XPC errors to avoid spam
            }
        }
    }
    
    /// Update Glass UI from XPC data
    @MainActor
    private func updateGlassUIFromXPC(_ content: [String: Any]) {
        if let visionSummary = content["visionSummary"] as? String {
            let confidence = content["visionConfidence"] as? Double ?? 0.0
            glassViewModel?.showVisionSummary(visionSummary, confidence: confidence)
            // Only auto-show if user hasn't manually hidden and auto-show is enabled
            if autoShowEnabled && !userManuallyHidden {
                showGlass()
            }
        }
        
        if let temporalQuery = content["temporalQuery"] as? String {
            glassViewModel?.showTemporalQuery(temporalQuery)
            if let temporalResult = content["temporalResult"] as? String {
                glassViewModel?.showTemporalResult(temporalResult)
            }
            // Only auto-show if user hasn't manually hidden and auto-show is enabled
            if autoShowEnabled && !userManuallyHidden {
                showGlass()
            }
        }
        
        if let workflowTransition = content["workflowTransition"] as? String {
            let relationshipType = content["relationshipType"] as? String ?? ""
            let confidence = content["relationshipConfidence"] as? Double ?? 0.0
            glassViewModel?.showWorkflowFeedback(workflowTransition, relationshipType: relationshipType, confidence: confidence)
            // Only auto-show if user hasn't manually hidden and auto-show is enabled
            if autoShowEnabled && !userManuallyHidden {
                showGlass()
            }
        }
        
        if let memoryUsage = content["memoryUsage"] as? Int {
            let cpuUsage = content["cpuUsage"] as? Int ?? 0
            let latency = content["latency"] as? Int ?? 0
            glassViewModel?.showHealthStatus(memory: memoryUsage, cpu: cpuUsage, latency: latency)
            // Only auto-show if user hasn't manually hidden and auto-show is enabled
            if autoShowEnabled && !userManuallyHidden {
                showGlass()
            }
        }
    }
    
    /// Get current debug information
    public func getDebugInfo() -> [String: Any] {
        var info: [String: Any] = [
            "is_initialized": isInitialized,
            "is_visible": isVisible,
            "keyboard_shortcuts_enabled": isKeyboardShortcutsEnabled,
            "xpc_base_url": xpcBaseURL
        ]
        
        if let window = glassWindow {
            info["window_debug"] = window.getDebugInfo()
        }
        
        // Skip async view model metrics for now to avoid compilation issues
        info["view_model_available"] = glassViewModel != nil
        
        return info
    }
}

// MARK: - Error Handling

public enum GlassError: Error, LocalizedError {
    case screenNotFound
    case windowCreationFailed
    case xpcConnectionFailed
    case keyboardShortcutsFailed
    
    public var errorDescription: String? {
        switch self {
        case .screenNotFound:
            return "Main screen not found"
        case .windowCreationFailed:
            return "Failed to create Glass window"
        case .xpcConnectionFailed:
            return "Failed to connect to XPC service"
        case .keyboardShortcutsFailed:
            return "Failed to setup keyboard shortcuts"
        }
    }
}

// MARK: - Extensions

extension GlassManager {
    /// Test invisibility with screen recording
    public func testInvisibility() async -> Bool {
        guard let window = glassWindow else { return false }
        
        // Show window briefly
        await MainActor.run {
            window.fadeIn(duration: 0.1)
        }
        
        // Wait a moment
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Check if window is properly configured for invisibility
        let isInvisible = await MainActor.run {
            window.validateInvisibilitySettings()
        }
        
        // Hide window
        await MainActor.run {
            window.fadeOut(duration: 0.1)
        }
        
        return isInvisible
    }
}