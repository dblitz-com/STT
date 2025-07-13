import Foundation
import AppKit
import ApplicationServices

// MARK: - Context Management for Phase 3

actor ContextManager {
    private var currentApp: String?
    private var uiContext: String?
    private var lastUpdate: Date = Date()
    private let updateInterval: TimeInterval = 1.0 // Cache for 1 second
    
    // Context mapping for tone adaptation
    private let appContextMap: [String: String] = [
        "com.apple.mail": "email",
        "com.apple.iChat": "messaging", 
        "com.apple.Messages": "messaging",
        "com.microsoft.teams": "meeting",
        "com.tinyspeck.slackmacgui": "messaging",
        "com.apple.dt.Xcode": "coding",
        "com.microsoft.VSCode": "coding",
        "com.sublimetext.4": "coding",
        "com.apple.Notes": "notes",
        "com.apple.TextEdit": "document",
        "com.microsoft.Word": "document",
        "com.apple.Safari": "web",
        "com.google.Chrome": "web",
        "us.zoom.xos": "meeting"
    ]
    
    init() {
        NSLog("🎯 ContextManager initialized for Phase 3")
    }
    
    func updateContext() async {
        // Rate limiting - only update if needed
        let now = Date()
        if now.timeIntervalSince(lastUpdate) < updateInterval {
            return
        }
        
        let appInfo = await detectApplicationContext()
        await detectUIContext()
        currentApp = appInfo
        lastUpdate = now
        
        NSLog("🎯 Context updated: app=\(currentApp ?? "unknown"), ui=\(uiContext ?? "unknown")")
    }
    
    @MainActor
    private func detectApplicationContext() -> String? {
        let workspace = NSWorkspace.shared
        return workspace.frontmostApplication?.bundleIdentifier
    }
    
    private func detectUIContext() async {
        // AXUIElement for deeper UI context
        var focused: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            AXUIElementCreateSystemWide(), 
            kAXFocusedUIElementAttribute as CFString, 
            &focused
        )
        
        guard result == .success, focused != nil else {
            uiContext = "unknown"
            return
        }
        
        let element = unsafeBitCast(focused!, to: AXUIElement.self)
        
        // Get role attribute
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        let roleString = role as? String ?? "unknown"
        
        // Get title/description for more context
        var title: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &title)
        let titleString = title as? String ?? ""
        
        // Classify UI context
        uiContext = classifyUIContext(role: roleString, title: titleString)
    }
    
    private func classifyUIContext(role: String, title: String) -> String {
        let titleLower = title.lowercased()
        
        switch role {
        case "AXTextArea", "AXTextField":
            if titleLower.contains("subject") {
                return "email_subject"
            } else if titleLower.contains("body") || titleLower.contains("compose") {
                return "email_body"  
            } else if titleLower.contains("message") || titleLower.contains("chat") {
                return "message_input"
            } else if titleLower.contains("comment") {
                return "code_comment"
            } else {
                return "text_input"
            }
        case "AXWebArea":
            return "web_content"
        case "AXDocument":
            return "document_edit"
        default:
            return role.replacingOccurrences(of: "AX", with: "").lowercased()
        }
    }
    
    func getCurrentContext() async -> ContextInfo {
        await updateContext()
        
        let appCategory = appContextMap[currentApp ?? ""] ?? "general"
        let advanced = inferAdvancedContext(app: currentApp, ui: uiContext)
        
        return ContextInfo(
            appId: currentApp ?? "unknown",
            appCategory: appCategory,
            uiContext: uiContext ?? "unknown", 
            advancedContext: advanced,
            timestamp: Date()
        )
    }
    
    private func inferAdvancedContext(app: String?, ui: String?) -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        let base = appContextMap[app ?? ""] ?? "general"
        
        // Time-based inference
        let timeContext = hour < 9 ? "formal" : (hour > 17 ? "casual" : "neutral")
        
        // Meeting detection
        if app?.contains("zoom") == true || app?.contains("teams") == true {
            return "meeting_transcript"
        }
        
        // Email composition context
        if base == "email" && ui == "email_body" {
            return "email_composition_\(timeContext)"
        }
        
        // Code context
        if base == "coding" && ui == "code_comment" {
            return "code_documentation"
        }
        
        return "\(base)_\(timeContext)"
    }
}

// MARK: - Context Data Structures

struct ContextInfo {
    let appId: String
    let appCategory: String  // email, messaging, coding, etc.
    let uiContext: String    // email_body, text_input, etc.
    let advancedContext: String  // email_composition_formal, etc.
    let timestamp: Date
    
    var toneHint: String {
        switch appCategory {
        case "email":
            return uiContext == "email_subject" ? "concise professional" : "formal professional tone for emails"
        case "messaging":
            return "casual conversational tone"
        case "coding":
            return uiContext == "code_comment" ? "technical precise tone for code comments" : "technical documentation tone"
        case "document":
            return "clear structured tone for documents"
        case "meeting":
            return "conversational meeting transcript tone"
        default:
            return "neutral balanced tone"
        }
    }
    
    var shouldLearnVocab: Bool {
        // Learn technical terms in coding contexts, names in emails
        return appCategory == "coding" || appCategory == "email" || appCategory == "document"
    }
}

// MARK: - Context Observer for Real-Time Updates

@MainActor
class ContextObserver: ObservableObject {
    private let contextManager: ContextManager
    private var notificationObserver: NSObjectProtocol?
    
    init(contextManager: ContextManager) {
        self.contextManager = contextManager
        setupNotifications()
    }
    
    deinit {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func setupNotifications() {
        // Observe app switching
        notificationObserver = NotificationCenter.default.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task {
                await self.contextManager.updateContext()
            }
        }
        
        NSLog("🎯 ContextObserver setup complete - monitoring app switches")
    }
    
    func forceUpdate() {
        Task {
            await contextManager.updateContext()
        }
    }
}