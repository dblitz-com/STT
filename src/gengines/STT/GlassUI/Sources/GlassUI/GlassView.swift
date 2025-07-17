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
            // Transparent background for invisibility
            Color.clear
            
            // Main content overlay
            mainContent
                .opacity(viewModel.isVisible ? 1.0 : 0.0)
                .offset(x: animationOffset)
                .animation(.easeInOut(duration: 0.3), value: viewModel.isVisible)
                .animation(.easeInOut(duration: 0.3), value: animationOffset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)  // Transparent background
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
            // Truly hidden - show nothing
            Color.clear
            
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
        VStack(alignment: .leading, spacing: 8) {
            // Compact header like temp/glass
            HStack {
                Image(systemName: "eye.circle.fill")
                    .foregroundColor(.cyan)
                    .font(.system(size: 16))
                Text("Vision")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                Spacer()
                
                // Compact confidence indicator
                if viewModel.visionConfidence > 0 {
                    Text("\(Int(viewModel.visionConfidence * 100))%")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(confidenceColor)
                }
            }
            .padding(.bottom, 4)
            
            // Full scrollable content with no limits
            ScrollView {
                Text(viewModel.visionSummary)
                    .font(.system(size: 13))
                    .fontWeight(.regular)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)  // No line limit - show all content
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            }
            .frame(maxHeight: 400)  // Much larger scroll area
        }
        .padding(12)  // Much smaller padding like temp/glass
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(compactGlassBackground)
        .cornerRadius(8)  // Smaller corner radius
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Temporal Query View
    
    private var temporalQueryView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "clock.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 16))
                Text("Query")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                Spacer()
            }
            
            if !viewModel.temporalQuery.isEmpty {
                Text("\(viewModel.temporalQuery)")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
                    .italic()
                    .lineLimit(2)
            }
            
            if !viewModel.temporalResult.isEmpty {
                ScrollView {
                    Text(viewModel.temporalResult)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.leading)
                        .lineLimit(6)  // Compact limit
                }
                .frame(maxHeight: 120)  // More compact
            } else if viewModel.isLoading {
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.6)
                    Text("Searching...")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .padding(12)
        .background(compactGlassBackground)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
    }
    
    // MARK: - Workflow Feedback View
    
    private var workflowFeedbackView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 16))
                Text("Workflow")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                Spacer()
            }
            
            if !viewModel.workflowTransition.isEmpty {
                Text(viewModel.workflowTransition)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
            }
            
            // Compact relationship indicator
            if !viewModel.relationshipType.isEmpty {
                HStack {
                    Text(viewModel.relationshipType.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(relationshipColor)
                        .cornerRadius(3)
                    
                    Spacer()
                    
                    if viewModel.relationshipConfidence > 0 {
                        Text("\(Int(viewModel.relationshipConfidence * 100))%")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
        }
        .padding(12)
        .background(compactGlassBackground)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
    }
    
    // MARK: - Health Status View
    
    private var healthStatusView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "heart.circle.fill")
                    .foregroundColor(healthStatusColor)
                    .font(.system(size: 16))
                Text("Health")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                Spacer()
            }
            
            // Compact grid layout
            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 2) {
                GridRow {
                    Text("Memory:")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))
                    Text("\(viewModel.memoryUsage)MB")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                }
                
                GridRow {
                    Text("CPU:")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))
                    Text("\(viewModel.cpuUsage)%")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                }
                
                GridRow {
                    Text("Latency:")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))
                    Text("\(viewModel.latency)ms")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(10)
        .background(compactGlassBackground)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Computed Properties
    
    private var glassBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.black.opacity(0.2))  // Subtle transparent background
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.clear)  // Transparent backing
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)  // Subtle border
            )
    }
    
    // Compact glass background for temp/glass-style appearance
    private var compactGlassBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.black.opacity(0.15))  // More transparent like temp/glass
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)  // Thinner border
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
            .frame(width: 380, height: 280)  // Match new compact dimensions
            .background(Color.black.opacity(0.1))
            .onAppear {
                // Preview with sample data
                viewModel.showVisionSummary("User is coding in Xcode, working on Swift UI implementation", confidence: 0.92)
            }
    }
}