import Foundation
import SwiftUI
import Combine

/// ViewModel for Glass UI state management and data handling
@MainActor
public class GlassViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var isVisible: Bool = false
    @Published public var currentMode: GlassView.DisplayMode = .hidden
    @Published public var isLoading: Bool = false
    
    // Vision Summary Properties
    @Published public var visionSummary: String = ""
    @Published public var visionConfidence: Double = 0.0
    
    // Temporal Query Properties
    @Published public var temporalQuery: String = ""
    @Published public var temporalResult: String = ""
    
    // Workflow Feedback Properties
    @Published public var workflowTransition: String = ""
    @Published public var relationshipType: String = ""
    @Published public var relationshipConfidence: Double = 0.0
    
    // Health Status Properties
    @Published public var memoryUsage: Int = 0
    @Published public var cpuUsage: Int = 0
    @Published public var latency: Int = 0
    
    // MARK: - Private Properties
    
    private var hideTimer: Timer?
    private var autoHideDelay: TimeInterval = 5.0
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    public init() {
        setupAutoHide()
    }
    
    // MARK: - Public Methods
    
    /// Show vision summary with optional confidence score
    public func showVisionSummary(_ summary: String, confidence: Double = 0.0) {
        print("🧠 GlassViewModel.showVisionSummary called with: '\(summary)', confidence: \(confidence)")
        visionSummary = summary
        visionConfidence = confidence
        currentMode = .visionSummary
        show()
        print("🧠 GlassViewModel state updated - isVisible: \(isVisible), mode: \(currentMode), summary: '\(visionSummary)'")
    }
    
    /// Show temporal query (loading state)
    public func showTemporalQuery(_ query: String) {
        temporalQuery = query
        temporalResult = ""
        isLoading = true
        currentMode = .temporalQuery
        show()
    }
    
    /// Show temporal query result
    public func showTemporalResult(_ result: String) {
        temporalResult = result
        isLoading = false
        currentMode = .temporalQuery
        show()
    }
    
    /// Show workflow feedback with relationship information
    public func showWorkflowFeedback(_ transition: String, relationshipType: String = "", confidence: Double = 0.0) {
        workflowTransition = transition
        self.relationshipType = relationshipType
        relationshipConfidence = confidence
        currentMode = .workflowFeedback
        show()
    }
    
    /// Show system health status
    public func showHealthStatus(memory: Int, cpu: Int, latency: Int) {
        memoryUsage = memory
        cpuUsage = cpu
        self.latency = latency
        currentMode = .healthStatus
        show()
    }
    
    /// Hide the Glass UI
    public func hide() {
        isVisible = false
        currentMode = .hidden
        cancelAutoHide()
    }
    
    /// Update auto-hide delay
    public func setAutoHideDelay(_ delay: TimeInterval) {
        autoHideDelay = delay
    }
    
    /// Disable auto-hide
    public func disableAutoHide() {
        cancelAutoHide()
    }
    
    /// Enable auto-hide
    public func enableAutoHide() {
        if isVisible {
            startAutoHideTimer()
        }
    }
    
    // MARK: - Private Methods
    
    private func show() {
        print("🧠 GlassViewModel.show() called - setting isVisible = true")
        isVisible = true
        startAutoHideTimer()
        print("🧠 GlassViewModel.show() completed - isVisible: \(isVisible)")
    }
    
    private func setupAutoHide() {
        // Setup auto-hide when visibility changes
        $isVisible
            .sink { [weak self] visible in
                if visible {
                    self?.startAutoHideTimer()
                } else {
                    self?.cancelAutoHide()
                }
            }
            .store(in: &cancellables)
    }
    
    private func startAutoHideTimer() {
        cancelAutoHide()
        
        hideTimer = Timer.scheduledTimer(withTimeInterval: autoHideDelay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.hide()
            }
        }
    }
    
    private func cancelAutoHide() {
        hideTimer?.invalidate()
        hideTimer = nil
    }
    
    // MARK: - Data Validation
    
    /// Validate vision summary data
    public func validateVisionData() -> Bool {
        return !visionSummary.isEmpty && visionConfidence >= 0.0 && visionConfidence <= 1.0
    }
    
    /// Validate temporal query data
    public func validateTemporalData() -> Bool {
        return !temporalQuery.isEmpty
    }
    
    /// Validate workflow feedback data
    public func validateWorkflowData() -> Bool {
        return !workflowTransition.isEmpty && relationshipConfidence >= 0.0 && relationshipConfidence <= 1.0
    }
    
    /// Validate health status data
    public func validateHealthData() -> Bool {
        return memoryUsage >= 0 && cpuUsage >= 0 && latency >= 0
    }
    
    // MARK: - Performance Monitoring
    
    /// Get current performance metrics
    public func getPerformanceMetrics() -> [String: Any] {
        return [
            "memory_usage_mb": memoryUsage,
            "cpu_usage_percent": cpuUsage,
            "latency_ms": latency,
            "is_visible": isVisible,
            "current_mode": currentMode.rawValue,
            "auto_hide_delay": autoHideDelay
        ]
    }
    
    /// Reset all data
    public func reset() {
        visionSummary = ""
        visionConfidence = 0.0
        temporalQuery = ""
        temporalResult = ""
        workflowTransition = ""
        relationshipType = ""
        relationshipConfidence = 0.0
        memoryUsage = 0
        cpuUsage = 0
        latency = 0
        isLoading = false
        hide()
    }
}

// MARK: - Extensions

extension GlassView.DisplayMode {
    var rawValue: String {
        switch self {
        case .hidden:
            return "hidden"
        case .visionSummary:
            return "vision_summary"
        case .temporalQuery:
            return "temporal_query"
        case .workflowFeedback:
            return "workflow_feedback"
        case .healthStatus:
            return "health_status"
        }
    }
}

extension GlassViewModel {
    /// Update from XPC data
    public func updateFromXPCData(_ data: [String: Any]) {
        if let visionData = data["vision_data"] as? [String: Any] {
            if let summary = visionData["summary"] as? String {
                let confidence = visionData["confidence"] as? Double ?? 0.0
                showVisionSummary(summary, confidence: confidence)
            }
        }
        
        if let temporalData = data["temporal_data"] as? [String: Any] {
            if let query = temporalData["query"] as? String {
                showTemporalQuery(query)
            }
            if let result = temporalData["result"] as? String {
                showTemporalResult(result)
            }
        }
        
        if let workflowData = data["workflow_data"] as? [String: Any] {
            if let transition = workflowData["transition"] as? String {
                let relationshipType = workflowData["relationship_type"] as? String ?? ""
                let confidence = workflowData["confidence"] as? Double ?? 0.0
                showWorkflowFeedback(transition, relationshipType: relationshipType, confidence: confidence)
            }
        }
        
        if let healthData = data["health_data"] as? [String: Any] {
            let memory = healthData["memory_mb"] as? Int ?? 0
            let cpu = healthData["cpu_percent"] as? Int ?? 0
            let latency = healthData["latency_ms"] as? Int ?? 0
            showHealthStatus(memory: memory, cpu: cpu, latency: latency)
        }
    }
}