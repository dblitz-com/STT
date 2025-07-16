import Foundation
import OSLog

/**
 * Memory XPC Service for Zeus_STT
 * Provides low-latency Swift-Python bridge for Mem0 + Graphiti memory queries
 * Adapted from proven zQuery patterns for <50ms response times
 */

// MARK: - XPC Protocol Definition

@objc protocol MemoryXPCServiceProtocol {
    func resolveContext(command: String, ocrText: String, sessionID: String, reply: @escaping (String?) -> Void)
    func addTextContext(command: String, ocrText: String, ocrElements: [String: Any], sessionID: String, reply: @escaping (Bool) -> Void)
    func healthCheck(reply: @escaping (Bool) -> Void)
}

// MARK: - Memory Context Types

struct MemoryContext: Codable {
    let resolvedTarget: String
    let confidence: Double
    let method: String
    let spatialContext: [String: String]?  // Changed from Any to String for Codable compliance
    let temporalContext: [String: String]?  // Changed from Any to String for Codable compliance
    let error: String?
    
    // Custom initializer for creating instances
    init(resolvedTarget: String, confidence: Double, method: String, spatialContext: [String: String]? = nil, temporalContext: [String: String]? = nil, error: String? = nil) {
        self.resolvedTarget = resolvedTarget
        self.confidence = confidence
        self.method = method
        self.spatialContext = spatialContext
        self.temporalContext = temporalContext
        self.error = error
    }
}

// MARK: - XPC Service Client

class MemoryXPCService {
    private let connection: NSXPCConnection
    private let logger = Logger(subsystem: "com.zeus.stt", category: "MemoryXPC")
    private var isConnected = false
    
    init() {
        // Create XPC connection to Python memory service
        connection = NSXPCConnection(serviceName: "com.zeus.stt.memory")
        connection.remoteObjectInterface = NSXPCInterface(with: MemoryXPCServiceProtocol.self)
        
        // Connection event handlers
        connection.interruptionHandler = { [weak self] in
            self?.logger.warning("🔄 Memory XPC connection interrupted")
            self?.isConnected = false
        }
        
        connection.invalidationHandler = { [weak self] in
            self?.logger.error("❌ Memory XPC connection invalidated")
            self?.isConnected = false
        }
        
        connection.resume()
        isConnected = true
        logger.info("✅ Memory XPC service initialized")
    }
    
    deinit {
        connection.invalidate()
    }
    
    // MARK: - Public Interface
    
    /**
     * Resolve context for voice command using memory system
     * Primary interface for Zeus_STT voice command processing
     */
    func resolveContext(command: String, ocrText: String, sessionID: String) async -> MemoryContext? {
        guard isConnected else {
            logger.warning("⚠️ Memory XPC not connected - using fallback")
            return createFallbackContext(command: command)
        }
        
        return await withCheckedContinuation { continuation in
            let startTime = CFAbsoluteTimeGetCurrent()
            
            guard let service = connection.remoteObjectProxy as? MemoryXPCServiceProtocol else {
                logger.error("❌ Failed to get memory service proxy")
                continuation.resume(returning: createFallbackContext(command: command))
                return
            }
            
            service.resolveContext(command: command, ocrText: ocrText, sessionID: sessionID) { [weak self] reply in
                let latency = (CFAbsoluteTimeGetCurrent() - startTime) * 1000 // ms
                
                guard let reply = reply else {
                    self?.logger.error("❌ Memory XPC returned nil response")
                    continuation.resume(returning: self?.createFallbackContext(command: command))
                    return
                }
                
                do {
                    let data = reply.data(using: .utf8) ?? Data()
                    let context = try JSONDecoder().decode(MemoryContext.self, from: data)
                    self?.logger.debug("✅ Memory resolved in \(String(format: "%.1f", latency))ms: \(context.method)")
                    continuation.resume(returning: context)
                } catch {
                    self?.logger.error("❌ Failed to decode memory response: \(error)")
                    continuation.resume(returning: self?.createFallbackContext(command: command))
                }
            }
        }
    }
    
    /**
     * Add text context to memory system
     * Called when new text interactions occur
     */
    func addTextContext(command: String, ocrText: String, ocrElements: [[String: Any]], sessionID: String) async -> Bool {
        guard isConnected else {
            logger.warning("⚠️ Memory XPC not connected - skipping context storage")
            return false
        }
        
        return await withCheckedContinuation { continuation in
            guard let service = connection.remoteObjectProxy as? MemoryXPCServiceProtocol else {
                logger.error("❌ Failed to get memory service proxy")
                continuation.resume(returning: false)
                return
            }
            
            // Convert OCR elements to serializable format
            let serializedElements: [String: Any] = [
                "elements": ocrElements,
                "timestamp": Date().timeIntervalSince1970
            ]
            
            service.addTextContext(command: command, ocrText: ocrText, 
                                 ocrElements: serializedElements, sessionID: sessionID) { [weak self] success in
                if success {
                    self?.logger.debug("✅ Added text context for: \(command)")
                } else {
                    self?.logger.warning("⚠️ Failed to add text context")
                }
                continuation.resume(returning: success)
            }
        }
    }
    
    /**
     * Health check for memory service availability
     */
    func isMemoryServiceHealthy() async -> Bool {
        guard isConnected else { return false }
        
        return await withCheckedContinuation { continuation in
            guard let service = connection.remoteObjectProxy as? MemoryXPCServiceProtocol else {
                continuation.resume(returning: false)
                return
            }
            
            service.healthCheck { isHealthy in
                continuation.resume(returning: isHealthy)
            }
        }
    }
    
    // MARK: - Private Helpers
    
    private func createFallbackContext(command: String) -> MemoryContext {
        return MemoryContext(
            resolvedTarget: "",
            confidence: 0.0,
            method: "fallback",
            spatialContext: nil,
            temporalContext: nil,
            error: "Memory service unavailable"
        )
    }
}

// MARK: - Memory-Enhanced Voice Command Processor

/**
 * Enhanced voice command processor that integrates memory context
 * Replaces basic command processing with memory-aware resolution
 */
class MemoryEnhancedCommandProcessor {
    private let memoryService = MemoryXPCService()
    private let logger = Logger(subsystem: "com.zeus.stt", category: "MemoryCommand")
    
    /**
     * Process voice command with memory-enhanced context resolution
     * 
     * Args:
     *   command: Voice command (e.g., "make this formal")
     *   ocrText: Current screen text from Apple Vision
     *   ocrElements: Structured OCR elements with bounding boxes
     *   sessionID: User session identifier
     *
     * Returns:
     *   Processed command with resolved target text
     */
    func processCommand(_ command: String, ocrText: String, 
                       ocrElements: [[String: Any]], sessionID: String) async -> ProcessedCommand {
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Step 1: Add current context to memory
        await memoryService.addTextContext(
            command: command, 
            ocrText: ocrText, 
            ocrElements: ocrElements, 
            sessionID: sessionID
        )
        
        // Step 2: Resolve context using memory system
        guard let memoryContext = await memoryService.resolveContext(
            command: command, 
            ocrText: ocrText, 
            sessionID: sessionID
        ) else {
            logger.warning("⚠️ Memory context resolution failed - using basic processing")
            return processBasicCommand(command, ocrText: ocrText)
        }
        
        let totalLatency = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        
        // Step 3: Create enhanced command result
        let result = ProcessedCommand(
            originalCommand: command,
            resolvedTarget: memoryContext.resolvedTarget.isEmpty ? ocrText : memoryContext.resolvedTarget,
            confidence: memoryContext.confidence,
            processingMethod: memoryContext.method,
            latencyMs: totalLatency,
            requiresTextSelection: shouldSelectText(command),
            actionType: determineActionType(command)
        )
        
        logger.info("✅ Memory-enhanced command processed in \(String(format: "%.1f", totalLatency))ms")
        return result
    }
    
    private func processBasicCommand(_ command: String, ocrText: String) -> ProcessedCommand {
        // Fallback to basic processing when memory unavailable
        return ProcessedCommand(
            originalCommand: command,
            resolvedTarget: ocrText,
            confidence: 0.5,
            processingMethod: "basic_fallback",
            latencyMs: 0,
            requiresTextSelection: shouldSelectText(command),
            actionType: determineActionType(command)
        )
    }
    
    private func shouldSelectText(_ command: String) -> Bool {
        let selectionCommands = ["delete", "select", "make", "change", "replace"]
        return selectionCommands.contains { command.lowercased().contains($0) }
    }
    
    private func determineActionType(_ command: String) -> CommandActionType {
        if command.lowercased().contains("delete") { return .delete }
        if command.lowercased().contains("select") { return .select }
        if command.lowercased().contains("make") || command.lowercased().contains("formal") { return .modify }
        if command.lowercased().contains("insert") { return .insert }
        return .unknown
    }
}

// MARK: - Supporting Types

struct ProcessedCommand {
    let originalCommand: String
    let resolvedTarget: String
    let confidence: Double
    let processingMethod: String
    let latencyMs: Double
    let requiresTextSelection: Bool
    let actionType: CommandActionType
}

enum CommandActionType {
    case delete
    case select
    case modify
    case insert
    case unknown
}

// MARK: - Integration Extensions

extension VoiceDictationService {
    /**
     * Memory-enhanced command processing integration point
     * Call this instead of basic processCommands() for advanced context
     */
    func processMemoryEnhancedCommand(_ command: String, ocrText: String, 
                                     ocrElements: [[String: Any]], sessionID: String) async -> String {
        
        let processor = MemoryEnhancedCommandProcessor()
        let result = await processor.processCommand(command, ocrText: ocrText, 
                                                   ocrElements: ocrElements, sessionID: sessionID)
        
        // Log memory processing results
        NSLog("🧠 Memory: \(result.processingMethod) | Confidence: \(String(format: "%.2f", result.confidence)) | Latency: \(String(format: "%.1f", result.latencyMs))ms")
        
        return result.resolvedTarget
    }
}