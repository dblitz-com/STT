#!/usr/bin/swift

import Cocoa
import UserNotifications

print("🧪 Testing notification system...")

// Modern UserNotifications (iOS 10+/macOS 10.14+)
let center = UNUserNotificationCenter.current()

// Request permission
center.requestAuthorization(options: [.alert, .sound]) { granted, error in
    if granted {
        print("✅ Notification permission granted")
        
        // Create notification
        let content = UNMutableNotificationContent()
        content.title = "⚡ Fn Key Detected!"
        content.body = "STT Dictate simulated Fn key press test"
        content.sound = UNNotificationSound.default
        
        // Trigger immediately
        let request = UNNotificationRequest(
            identifier: "fn-test",
            content: content,
            trigger: nil
        )
        
        center.add(request) { error in
            if let error = error {
                print("❌ Notification error: \(error)")
            } else {
                print("✅ Notification sent!")
            }
        }
    } else {
        print("❌ Notification permission denied")
    }
}

// Keep script alive briefly
RunLoop.main.run(until: Date().addingTimeInterval(2))