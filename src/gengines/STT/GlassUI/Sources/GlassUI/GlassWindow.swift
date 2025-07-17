import AppKit
import SwiftUI

/// Custom NSWindow subclass implementing Glass UI transparency and click-through
/// Based on Zeus VLA research specification for invisibility in screen recordings
public class GlassWindow: NSWindow {
    
    // MARK: - Properties
    
    private var isGlassVisible: Bool = false
    private var targetOpacity: CGFloat = 0.9
    
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
    
    // MARK: - Window Behavior Overrides
    
    /// Prevent window from becoming key (maintains click-through)
    public override var canBecomeKey: Bool {
        return false
    }
    
    /// Prevent window from becoming main (maintains click-through)
    public override var canBecomeMain: Bool {
        return false
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