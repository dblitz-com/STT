import Cocoa
import SwiftUI

// MARK: - Listening Popup Window Controller
class ListeningPopupController {
    private var window: NSWindow?
    private var hostingController: NSHostingController<ListeningView>?
    private var timer: Timer?
    
    func show() {
        guard window == nil else { return }
        
        // Create SwiftUI view
        let listeningView = ListeningView()
        let hosting = NSHostingController(rootView: listeningView)
        hostingController = hosting
        
        // Create floating window with glass effect
        let contentRect = NSRect(x: 0, y: 0, width: 200, height: 80)
        window = NSWindow(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        guard let window = window else { return }
        
        // Window properties for floating effect
        window.level = .floating
        window.backgroundColor = NSColor.clear
        window.isOpaque = false
        window.hasShadow = false // We'll handle shadow in SwiftUI
        window.contentView = hosting.view
        window.isMovableByWindowBackground = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.ignoresMouseEvents = true // Click-through for true glass effect
        
        // Position at bottom center of screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let windowFrame = window.frame
            let x = screenFrame.midX - windowFrame.width / 2
            let y = screenFrame.minY + 100 // 100 points from bottom
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        // Fade in animation
        window.alphaValue = 0
        window.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            window.animator().alphaValue = 1.0
        })
        
        NSLog("⚡ Listening popup displayed")
    }
    
    func hide() {
        guard let window = window else { return }
        
        // Fade out animation
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            window.animator().alphaValue = 0.0
        }, completionHandler: {
            window.orderOut(nil)
            self.window = nil
            self.hostingController = nil
            NSLog("⚡ Listening popup hidden")
        })
    }
}

// MARK: - SwiftUI Listening View
struct ListeningView: View {
    @State private var isPulsing = false
    @State private var wavePhase = 0.0
    
    var body: some View {
        ZStack {
            // True glass effect with layered approach from research
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .opacity(0.95)
                .clipShape(RoundedRectangle(cornerRadius: 20))
            
            // Subtle white tint for glass appearance
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.03))
            
            // Border overlay for definition
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.4), Color.white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
            
            // Soft shadow for depth
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.clear)
                .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
            
            // Content
            HStack(spacing: 12) {
                // Animated microphone icon
                Image(systemName: "mic.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white)
                    .scaleEffect(isPulsing ? 1.2 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.8)
                        .repeatForever(autoreverses: true),
                        value: isPulsing
                    )
                
                // Listening text with sound wave
                VStack(alignment: .leading, spacing: 4) {
                    Text("Listening...")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                    
                    // Sound wave visualization
                    SoundWaveView(phase: wavePhase)
                        .frame(height: 12)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .frame(width: 200, height: 80)
        .onAppear {
            isPulsing = true
            // Animate wave
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                wavePhase = 1.0
            }
        }
    }
}

// MARK: - Sound Wave Visualization
struct SoundWaveView: View {
    let phase: Double
    let barCount = 12
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(.white.opacity(0.9))
                    .frame(width: 3)
                    .scaleEffect(
                        y: waveHeight(for: index),
                        anchor: .center
                    )
                    .animation(
                        .easeInOut(duration: 0.4)
                        .delay(Double(index) * 0.05),
                        value: phase
                    )
            }
        }
    }
    
    private func waveHeight(for index: Int) -> Double {
        let normalizedIndex = Double(index) / Double(barCount - 1)
        let wave = sin((normalizedIndex + phase) * .pi * 2)
        return 0.3 + (wave + 1) * 0.35 // Height between 0.3 and 1.0
    }
}

// MARK: - Visual Effect View for True Glass (Based on Cluely Research)
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = true
        
        // Add tint layer as per research
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.05).cgColor
        view.layer?.cornerRadius = 20
        view.layer?.borderWidth = 0.5
        view.layer?.borderColor = NSColor.white.withAlphaComponent(0.3).cgColor
        
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Global Singleton
let listeningPopup = ListeningPopupController()