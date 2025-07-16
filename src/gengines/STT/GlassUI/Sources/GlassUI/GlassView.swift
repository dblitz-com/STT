import SwiftUI
import AppKit

/// SwiftUI view for Glass UI content display
/// Supports vision summaries, temporal queries, and workflow feedback
public struct GlassView: View {
    
    // MARK: - State Properties
    
    @ObservedObject var viewModel: GlassViewModel
    @State private var animationOffset: CGFloat = 0
    
    // MARK: - Display Modes
    
    public enum DisplayMode {
        case hidden
        case visionSummary
        case temporalQuery
        case workflowFeedback
        case healthStatus
    }
    
    // MARK: - Body
    
    public var body: some View {
        ZStack {
            // Debug background (visible during testing)
            Color.red.opacity(0.2)
                .background(Color.yellow.opacity(0.1))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Main content overlay
            mainContent
                .opacity(viewModel.isVisible ? 1.0 : 0.0)
                .offset(x: animationOffset)
                .animation(.easeInOut(duration: 0.3), value: viewModel.isVisible)
                .animation(.easeInOut(duration: 0.3), value: animationOffset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.green.opacity(0.1))  // Another debug background
        .onReceive(viewModel.$isVisible) { _ in
            updateAnimationOffset()
        }
        .onReceive(viewModel.$currentMode) { _ in
            updateAnimationOffset()
        }
    }
    
    // MARK: - Main Content
    
    @ViewBuilder
    private var mainContent: some View {
        switch viewModel.currentMode {
        case .hidden:
            // Show something even when "hidden" for debugging
            VStack(spacing: 16) {
                Text("🎯 Glass UI Active!")
                    .font(.title)
                    .foregroundColor(.white)
                    .fontWeight(.bold)
                
                Text("Mode: Hidden")
                    .font(.headline)
                    .foregroundColor(.yellow)
                
                // Always show debug info
                VStack(spacing: 8) {
                    Text("Debug Info:")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text("IsVisible: \(viewModel.isVisible)")
                        .font(.body)
                        .foregroundColor(.white)
                    
                    Text("CurrentMode: \(viewModel.currentMode.rawValue)")
                        .font(.body)
                        .foregroundColor(.white)
                        
                    Text("VisionSummary: \(viewModel.visionSummary.isEmpty ? "EMPTY" : "HAS CONTENT")")
                        .font(.body)
                        .foregroundColor(.white)
                }
                .padding()
                .background(Color.black.opacity(0.6))
                .cornerRadius(8)
            }
            .padding()
            .background(Color.purple.opacity(0.8))
            .cornerRadius(12)
            
        case .visionSummary:
            visionSummaryView
            
        case .temporalQuery:
            temporalQueryView
            
        case .workflowFeedback:
            workflowFeedbackView
            
        case .healthStatus:
            healthStatusView
        }
    }
    
    // MARK: - Vision Summary View
    
    private var visionSummaryView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "eye.circle.fill")
                    .foregroundColor(.cyan)
                    .font(.title2)
                Text("Vision Analysis")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
            }
            
            Text(viewModel.visionSummary)
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .padding(.vertical, 8)
            
            // Confidence indicator
            if viewModel.visionConfidence > 0 {
                HStack {
                    Text("Confidence:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.9))
                    
                    ProgressView(value: viewModel.visionConfidence, total: 1.0)
                        .progressViewStyle(LinearProgressViewStyle(tint: confidenceColor))
                        .frame(width: 120)
                    
                    Text("\(Int(viewModel.visionConfidence * 100))%")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
        }
        .padding(20)
        .background(glassBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.5), radius: 12, x: 0, y: 6)
    }
    
    // MARK: - Temporal Query View
    
    private var temporalQueryView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.circle.fill")
                    .foregroundColor(.green)
                Text("Temporal Query")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            
            if !viewModel.temporalQuery.isEmpty {
                Text("Query: \(viewModel.temporalQuery)")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .italic()
            }
            
            if !viewModel.temporalResult.isEmpty {
                ScrollView {
                    Text(viewModel.temporalResult)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                }
                .frame(maxHeight: 200)
            } else if viewModel.isLoading {
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                    Text("Searching...")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .padding(16)
        .background(glassBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Workflow Feedback View
    
    private var workflowFeedbackView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                    .foregroundColor(.orange)
                Text("Workflow Transition")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            
            if !viewModel.workflowTransition.isEmpty {
                Text(viewModel.workflowTransition)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.leading)
            }
            
            // Relationship indicator
            if !viewModel.relationshipType.isEmpty {
                HStack {
                    Text(viewModel.relationshipType.uppercased())
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(relationshipColor)
                        .cornerRadius(4)
                    
                    Spacer()
                    
                    if viewModel.relationshipConfidence > 0 {
                        Text("\(Int(viewModel.relationshipConfidence * 100))%")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
        }
        .padding(16)
        .background(glassBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Health Status View
    
    private var healthStatusView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "heart.circle.fill")
                    .foregroundColor(healthStatusColor)
                Text("System Health")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                GridRow {
                    Text("Memory:")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text("\(viewModel.memoryUsage)MB")
                        .font(.caption)
                        .foregroundColor(.white)
                }
                
                GridRow {
                    Text("CPU:")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text("\(viewModel.cpuUsage)%")
                        .font(.caption)
                        .foregroundColor(.white)
                }
                
                GridRow {
                    Text("Latency:")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text("\(viewModel.latency)ms")
                        .font(.caption)
                        .foregroundColor(.white)
                }
            }
        }
        .padding(12)
        .background(glassBackground)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Computed Properties
    
    private var glassBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.black.opacity(0.8))  // More opaque for visibility
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(0.3))  // Blue tint for testing
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.8), lineWidth: 2)  // Thicker, more visible border
            )
    }
    
    private var confidenceColor: Color {
        switch viewModel.visionConfidence {
        case 0.8...1.0:
            return .green
        case 0.6..<0.8:
            return .yellow
        default:
            return .red
        }
    }
    
    private var relationshipColor: Color {
        switch viewModel.relationshipType.lowercased() {
        case "triggers":
            return .red
        case "follows":
            return .blue
        case "contains":
            return .green
        case "requires":
            return .orange
        default:
            return .gray
        }
    }
    
    private var healthStatusColor: Color {
        if viewModel.memoryUsage > 400 || viewModel.cpuUsage > 80 || viewModel.latency > 500 {
            return .red
        } else if viewModel.memoryUsage > 300 || viewModel.cpuUsage > 60 || viewModel.latency > 300 {
            return .yellow
        } else {
            return .green
        }
    }
    
    // MARK: - Helper Methods
    
    private func updateAnimationOffset() {
        withAnimation(.easeInOut(duration: 0.2)) {
            animationOffset = viewModel.currentMode != .hidden ? 0 : -20
        }
    }
    
}

// MARK: - Preview

struct GlassView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = GlassViewModel()
        GlassView(viewModel: viewModel)
            .frame(width: 400, height: 300)
            .background(Color.black.opacity(0.1))
            .onAppear {
                // Preview with sample data
                viewModel.showVisionSummary("User is coding in Xcode, working on Swift UI implementation", confidence: 0.92)
            }
    }
}