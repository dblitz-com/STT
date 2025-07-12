import Cocoa
import AppKit

NSLog("🚀 STT Dictate starting main.swift")

let app = NSApplication.shared
let delegate = AppDelegate()

NSLog("🔧 Setting app delegate")
app.delegate = delegate

NSLog("🏃 Running app")
app.run()