import Foundation
import ApplicationServices

// MARK: - Command Processing Structures

struct Classification {
    let isCommand: Bool
    let intent: String
    let params: [String: String]
    
    static let notCommand = Classification(isCommand: false, intent: "", params: [:])
}

// MARK: - Command Processing Extension
extension VoiceDictationService {
    
    func classifyText(_ text: String) async -> Classification {
        NSLog("🎯 Classifying text for commands: '\(text)'")
        
        let jsonInput = [
            "input": text,
            "type": "classify"
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: jsonInput),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            NSLog("❌ Failed to create JSON input for classification")
            return Classification.notCommand
        }
        
        return await withCheckedContinuation { continuation in
            let process = Process()
            process.launchPath = pythonPath
            process.arguments = [commandProcessorPath, jsonString]
            
            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            
            process.terminationHandler = { _ in
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                
                if let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    NSLog("🎯 Classification output: \(output)")
                    
                    if let data = output.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let isCommand = json["is_command"] as? Bool {
                        
                        let intent = json["intent"] as? String ?? ""
                        let params = json["params"] as? [String: String] ?? [:]
                        
                        continuation.resume(returning: Classification(isCommand: isCommand, intent: intent, params: params))
                    } else {
                        continuation.resume(returning: Classification.notCommand)
                    }
                } else {
                    continuation.resume(returning: Classification.notCommand)
                }
            }
            
            do {
                try process.run()
            } catch {
                NSLog("❌ Failed to run command classification: \(error)")
                continuation.resume(returning: Classification.notCommand)
            }
        }
    }
    
    @MainActor
    func executeCommand(_ classification: Classification) async {
        NSLog("⚡ Executing command: \(classification.intent)")
        
        // Update focused element
        var focused: CFTypeRef?
        AXUIElementCopyAttributeValue(AXUIElementCreateSystemWide(), kAXFocusedUIElementAttribute as CFString, &focused)
        focusedElement = focused as? AXUIElement
        
        guard let element = focusedElement else {
            NSLog("❌ No focused element for command execution")
            return
        }
        
        switch classification.intent {
        case "delete":
            await executeDeleteCommand(classification.params, in: element)
        case "insert":
            await executeInsertCommand(classification.params, in: element)
        case "tone_change":
            await executeToneChangeCommand(classification.params, in: element)
        default:
            NSLog("⚠️ Command not implemented: \(classification.intent)")
        }
    }
    
    @MainActor
    private func executeDeleteCommand(_ params: [String: String], in element: AXUIElement) async {
        let target = params["target"] ?? "last_word"
        NSLog("🗑️ Deleting: \(target)")
        
        // Simple implementation: delete last character for now
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)
        if let currentText = value as? String, !currentText.isEmpty {
            let newText = String(currentText.dropLast())
            AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, newText as CFTypeRef)
        }
        
        NSSound.beep() // Confirmation
    }
    
    @MainActor
    private func executeInsertCommand(_ params: [String: String], in element: AXUIElement) async {
        let content = params["content"] ?? "new_line"
        NSLog("➕ Inserting: \(content)")
        
        var textToInsert = ""
        switch content {
        case "bullet_point":
            textToInsert = "\n- "
        case "new_line":
            textToInsert = "\n"
        default:
            textToInsert = content
        }
        
        // Get current text and append
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)
        let currentText = value as? String ?? ""
        let newText = currentText + textToInsert
        AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, newText as CFTypeRef)
    }
    
    @MainActor
    private func executeToneChangeCommand(_ params: [String: String], in element: AXUIElement) async {
        let tone = params["tone"] ?? "formal"
        NSLog("🎨 Changing tone to: \(tone)")
        
        // Get current text
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)
        let currentText = value as? String ?? ""
        
        guard !currentText.isEmpty else {
            NSLog("⚠️ No text to change tone for")
            return
        }
        
        // Apply tone change via AI command processor
        let toneChangeResult = await applyToneChange(text: currentText, tone: tone)
        
        if let newText = toneChangeResult {
            // Replace text with tone-changed version
            AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, newText as CFTypeRef)
            
            // Learn this tone preference for current context
            if let context = currentContext {
                let toneHint = getToneHint(for: tone)
                learningManager.learnTonePreference(context: context, preferredTone: toneHint, confidence: 0.8)
                NSLog("🧠 Learned tone preference: \(tone) for \(context.appCategory)")
            }
            
            NSSound.beep() // Confirmation
        }
    }
    
    private func applyToneChange(text: String, tone: String) async -> String? {
        let jsonInput = [
            "input": text,
            "type": "tone_\(tone)"
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: jsonInput),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            NSLog("❌ Failed to create tone change JSON")
            return nil
        }
        
        return await withCheckedContinuation { continuation in
            let process = Process()
            process.launchPath = pythonPath
            process.arguments = [commandProcessorPath, jsonString]
            
            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            
            process.terminationHandler = { _ in
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                
                if let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    NSLog("🎨 Tone change result: \(output)")
                    continuation.resume(returning: output)
                } else {
                    continuation.resume(returning: nil)
                }
            }
            
            do {
                try process.run()
            } catch {
                NSLog("❌ Failed to run tone change: \(error)")
                continuation.resume(returning: nil)
            }
        }
    }
    
    private func getToneHint(for tone: String) -> String {
        switch tone.lowercased() {
        case "formal":
            return "formal professional tone for documents"
        case "casual":
            return "casual conversational tone"
        case "professional":
            return "professional business tone"
        default:
            return "neutral balanced tone"
        }
    }
}