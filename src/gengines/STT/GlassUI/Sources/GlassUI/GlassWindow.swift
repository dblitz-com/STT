import AppKit
import SwiftUI

/// Custom NSWindow subclass implementing Glass UI transparency and click-through
/// Based on Zeus VLA research specification for invisibility in screen recordings
public class GlassWindow: NSWindow {
    
    // MARK: - Properties
    
    private var isGlassVisible: Bool = false
    private var targetOpacity: CGFloat = 0.9
    private var isDragging: Bool = false
    private var dragStartLocation: NSPoint = NSZeroPoint
    private var isDraggingEnabled: Bool = true
    
    // MARK: - Initialization
    
    public override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing bufferingType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: [.borderless], backing: .buffered, defer: false)
        
        // Critical invisibility settings for screen recording bypass
        self.level = .popUpMenu  // High level for overlay but invisible to recordings
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]  // Invisible to recordings
        
        // Transparency settings
        self.backgroundColor = NSColor.clear
        self.isOpaque = false
        self.hasShadow = false
        
        // Click-through settings
        self.ignoresMouseEvents = true  // Events pass to underlying apps
        
        // Setup content view for transparency
        self.contentView?.wantsLayer = true
        self.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
        
        // Start invisible
        self.alphaValue = 0.0
        
        // Performance optimization: Metal-backed layer
        if let layer = self.contentView?.layer {
            layer.isOpaque = false
            layer.backgroundColor = NSColor.clear.cgColor
        }
    }
    
    // MARK: - Glass UI Controls
    
    /// Fade in the Glass UI with smooth animation
    /// - Parameter duration: Animation duration (default: 0.3s)
    public func fadeIn(duration: TimeInterval = 0.3) {
        guard !isGlassVisible else { return }
        
        isGlassVisible = true
        
        // Enable dragging when window becomes visible
        if isDraggingEnabled {
            self.ignoresMouseEvents = false
        }
        
        // Direct alpha setting for immediate visibility (no animation issues)
        self.alphaValue = targetOpacity
        
        // Also use animation for smooth effect
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.animator().alphaValue = targetOpacity
        }
    }
    
    /// Fade out the Glass UI with smooth animation
    /// - Parameter duration: Animation duration (default: 0.3s)
    public func fadeOut(duration: TimeInterval = 0.3) {
        guard isGlassVisible else { return }
        
        isGlassVisible = false
        
        // Disable mouse events when window becomes invisible
        self.ignoresMouseEvents = true
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.animator().alphaValue = 0.0
        }
    }
    
    /// Toggle Glass UI visibility
    public func toggleVisibility() {
        if isGlassVisible {
            fadeOut()
        } else {
            fadeIn()
        }
    }
    
    /// Set adaptive opacity based on context
    /// - Parameter opacity: Target opacity (0.0 to 1.0)
    public func setAdaptiveOpacity(_ opacity: CGFloat) {
        targetOpacity = min(max(opacity, 0.0), 1.0)
        if isGlassVisible {
            self.alphaValue = targetOpacity
        }
    }
    
    // MARK: - Dragging Controls
    
    /// Enable or disable window dragging
    /// - Parameter enabled: Whether dragging should be enabled
    public func setDraggingEnabled(_ enabled: Bool) {
        isDraggingEnabled = enabled
        
        // Update mouse event behavior based on dragging state
        if enabled && isGlassVisible {
            // When dragging is enabled and window is visible, allow mouse events for dragging
            self.ignoresMouseEvents = false
        } else {
            // When dragging is disabled or window is hidden, maintain click-through
            self.ignoresMouseEvents = true
        }
    }
    
    /// Start drag operation
    private func startDragging(at location: NSPoint) {
        guard isDraggingEnabled && isGlassVisible else { return }
        
        isDragging = true
        dragStartLocation = location
        
        // Temporarily disable click-through during dragging
        self.ignoresMouseEvents = false
        
        print("🖱️ Starting drag at: \(location)")
    }
    
    /// End drag operation
    private func endDragging() {
        guard isDragging else { return }
        
        isDragging = false
        dragStartLocation = NSZeroPoint
        
        // Re-enable click-through after dragging (if dragging is still enabled)
        if isDraggingEnabled && isGlassVisible {
            // Brief delay to allow click events to complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Only re-enable click-through if we're not actively dragging
                if !self.isDragging {
                    self.ignoresMouseEvents = false  // Keep interactive for dragging
                }
            }
        } else {
            self.ignoresMouseEvents = true
        }
        
        print("🖱️ Ended dragging")
    }
    
    // MARK: - Mouse Event Overrides
    
    /// Handle mouse down events for dragging
    public override func mouseDown(with event: NSEvent) {
        if isDraggingEnabled && isGlassVisible {
            let locationInWindow = event.locationInWindow
            startDragging(at: locationInWindow)
        }
        super.mouseDown(with: event)
    }
    
    /// Handle mouse dragged events for moving window
    public override func mouseDragged(with event: NSEvent) {
        guard isDragging && isDraggingEnabled else { 
            super.mouseDragged(with: event)
            return 
        }
        
        // Calculate new window position
        let currentLocation = NSEvent.mouseLocation
        let newOrigin = NSPoint(
            x: currentLocation.x - dragStartLocation.x,
            y: currentLocation.y - dragStartLocation.y
        )
        
        // Constrain to screen bounds
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let windowFrame = self.frame
            
            let constrainedX = max(screenFrame.minX, 
                                 min(newOrigin.x, screenFrame.maxX - windowFrame.width))
            let constrainedY = max(screenFrame.minY, 
                                 min(newOrigin.y, screenFrame.maxY - windowFrame.height))
            
            self.setFrameOrigin(NSPoint(x: constrainedX, y: constrainedY))
        } else {
            self.setFrameOrigin(newOrigin)
        }
        
        super.mouseDragged(with: event)
    }
    
    /// Handle mouse up events to end dragging
    public override func mouseUp(with event: NSEvent) {
        if isDragging {
            endDragging()
        }
        super.mouseUp(with: event)
    }
    
    // MARK: - Window Behavior Overrides
    
    /// Allow window to become key when dragging is enabled
    public override var canBecomeKey: Bool {
        return isDraggingEnabled && isGlassVisible
    }
    
    /// Allow window to become main when dragging is enabled  
    public override var canBecomeMain: Bool {
        return isDraggingEnabled && isGlassVisible
    }
    
    // MARK: - Screen Recording Invisibility
    
    /// Verify invisibility settings are properly configured
    public func validateInvisibilitySettings() -> Bool {
        let validLevel = (level == .popUpMenu || level == .screenSaver)
        let validBehavior = collectionBehavior.contains(.ignoresCycle)
        let validTransparency = !isOpaque && backgroundColor == NSColor.clear
        let validClickThrough = ignoresMouseEvents
        
        return validLevel && validBehavior && validTransparency && validClickThrough
    }
    
    /// Configure for maximum invisibility (for testing)
    public func configureMaxInvisibility() {
        self.level = .screenSaver  // Highest level for complete invisibility
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .participatesInCycle]
        self.ignoresMouseEvents = true
        self.isOpaque = false
        self.backgroundColor = NSColor.clear
        self.hasShadow = false
    }
    
    // MARK: - Performance Optimization
    
    /// Optimize rendering for <16ms performance
    public func optimizeRendering() {
        guard let contentView = self.contentView else { return }
        
        // Enable Metal-backed layer for performance
        contentView.wantsLayer = true
        contentView.layer?.drawsAsynchronously = true
        
        // Optimize layer properties
        if let layer = contentView.layer {
            layer.isOpaque = false
            layer.backgroundColor = NSColor.clear.cgColor
            layer.allowsEdgeAntialiasing = true
            layer.allowsGroupOpacity = true
        }
    }
    
    // MARK: - Context-Aware Positioning
    
    /// Position window to avoid content occlusion
    /// - Parameter avoidRect: Rectangle to avoid (e.g., active window bounds)
    public func positionToAvoidOcclusion(avoidRect: NSRect) {
        guard let screen = NSScreen.main else { return }
        
        let screenFrame = screen.visibleFrame
        let windowFrame = self.frame
        
        var newOrigin = windowFrame.origin
        
        // Check if current position overlaps with avoid rect
        if windowFrame.intersects(avoidRect) {
            // Try positioning to the right
            let rightPosition = NSPoint(x: avoidRect.maxX + 10, y: avoidRect.origin.y)
            if rightPosition.x + windowFrame.width < screenFrame.maxX {
                newOrigin = rightPosition
            } else {
                // Try positioning to the left
                let leftPosition = NSPoint(x: avoidRect.origin.x - windowFrame.width - 10, y: avoidRect.origin.y)
                if leftPosition.x > screenFrame.origin.x {
                    newOrigin = leftPosition
                } else {
                    // Try positioning below
                    let belowPosition = NSPoint(x: avoidRect.origin.x, y: avoidRect.origin.y - windowFrame.height - 10)
                    if belowPosition.y > screenFrame.origin.y {
                        newOrigin = belowPosition
                    }
                }
            }
        }
        
        self.setFrameOrigin(newOrigin)
    }
    
    // MARK: - Debug Helpers
    
    /// Get current Glass UI state for debugging
    public func getDebugInfo() -> [String: Any] {
        return [
            "isGlassVisible": isGlassVisible,
            "alphaValue": alphaValue,
            "targetOpacity": targetOpacity,
            "level": level.rawValue,
            "ignoresMouseEvents": ignoresMouseEvents,
            "isOpaque": isOpaque,
            "backgroundColor": backgroundColor.debugDescription,
            "collectionBehavior": collectionBehavior.rawValue,
            "invisibilityValid": validateInvisibilitySettings()
        ]
    }
}

// MARK: - Extensions

extension GlassWindow {
    /// Convenience initializer for Glass UI with temp/glass-inspired compact sizing
    public convenience init(forScreen screen: NSScreen) {
        // Match temp/glass compact design - smaller, more centered window
        let screenFrame = screen.visibleFrame  // Use visibleFrame to respect menu bar/dock
        
        // temp/glass dimensions: Header 353x47, Listen ~400 width, compact height
        let windowWidth: CGFloat = 380   // Slightly smaller than temp/glass for better fit
        let windowHeight: CGFloat = 280  // Much more compact, like temp/glass
        
        // Position more centrally like temp/glass, not as a right panel
        let windowRect = NSRect(
            x: screenFrame.midX - windowWidth / 2,      // Horizontally centered
            y: screenFrame.midY - windowHeight / 2,     // Vertically centered  
            width: windowWidth,
            height: windowHeight
        )
        
        self.init(
            contentRect: windowRect,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        self.optimizeRendering()
    }
    
    /// Create compact header-style window like temp/glass header (353x47)
    public convenience init(headerStyleForScreen screen: NSScreen) {
        let screenFrame = screen.visibleFrame
        
        // Match temp/glass header dimensions exactly
        let windowWidth: CGFloat = 353
        let windowHeight: CGFloat = 47
        
        // Position like temp/glass header - center-top area
        let windowRect = NSRect(
            x: screenFrame.midX - windowWidth / 2,
            y: screenFrame.maxY - windowHeight - 21,  // Near top with margin like temp/glass
            width: windowWidth,
            height: windowHeight
        )
        
        self.init(
            contentRect: windowRect,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        self.optimizeRendering()
    }
}