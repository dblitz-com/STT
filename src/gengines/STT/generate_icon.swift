#!/usr/bin/env swift

import Foundation
import AppKit

// Generate Zeus_STT app icon with lightning bolt
func generateAppIcon() {
    let sizes = [16, 32, 64, 128, 256, 512, 1024]
    
    for size in sizes {
        generateIcon(size: size)
    }
    
    // Create .icns file
    createIcnsFile()
    
    print("✅ Zeus_STT lightning bolt icons generated!")
}

func generateIcon(size: Int) {
    let image = NSImage(size: NSSize(width: size, height: size))
    
    image.lockFocus()
    
    // White background (user preferred over transparent)
    NSColor.white.setFill()
    NSRect(x: 0, y: 0, width: size, height: size).fill()
    
    // Create SF Symbol lightning bolt
    if let boltSymbol = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "Lightning") {
        // Scale the symbol to fit well in the icon
        let symbolSize = CGFloat(size) * 0.6  // 60% of icon size
        let symbolRect = NSRect(
            x: (CGFloat(size) - symbolSize) / 2,
            y: (CGFloat(size) - symbolSize) / 2,
            width: symbolSize,
            height: symbolSize
        )
        
        // Draw with bright yellow/gold color  
        NSColor(red: 1.0, green: 0.95, blue: 0.0, alpha: 1.0).set()
        boltSymbol.draw(in: symbolRect)
    }
    
    image.unlockFocus()
    
    // Save as PNG
    if let tiffData = image.tiffRepresentation,
       let bitmap = NSBitmapImageRep(data: tiffData),
       let pngData = bitmap.representation(using: .png, properties: [:]) {
        
        let filename = "icon_\(size)x\(size)\(size >= 512 ? "@2x" : "").png"
        let url = URL(fileURLWithPath: filename)
        
        do {
            try pngData.write(to: url)
            print("✅ Generated: \(filename)")
        } catch {
            print("❌ Failed to save \(filename): \(error)")
        }
    }
}

func createIcnsFile() {
    // Create iconset directory
    let iconsetPath = "Zeus_STT.iconset"
    do {
        try FileManager.default.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)
        
        // Copy PNG files to iconset with proper naming
        let iconFiles = [
            ("icon_16x16.png", "icon_16x16.png"),
            ("icon_32x32.png", "icon_16x16@2x.png"), 
            ("icon_32x32.png", "icon_32x32.png"),
            ("icon_64x64.png", "icon_32x32@2x.png"),
            ("icon_128x128.png", "icon_128x128.png"),
            ("icon_256x256.png", "icon_128x128@2x.png"),
            ("icon_256x256.png", "icon_256x256.png"), 
            ("icon_512x512@2x.png", "icon_256x256@2x.png"),
            ("icon_512x512@2x.png", "icon_512x512.png"),
            ("icon_1024x1024@2x.png", "icon_512x512@2x.png")
        ]
        
        for (source, dest) in iconFiles {
            if FileManager.default.fileExists(atPath: source) {
                let destPath = "\(iconsetPath)/\(dest)"
                try? FileManager.default.removeItem(atPath: destPath)
                try FileManager.default.copyItem(atPath: source, toPath: destPath)
            }
        }
        
        // Use iconutil to create .icns file
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
        process.arguments = ["-c", "icns", iconsetPath]
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus == 0 {
            print("✅ Created Zeus_STT.icns file")
            
            // Clean up iconset directory
            try? FileManager.default.removeItem(atPath: iconsetPath)
            
            // Clean up individual PNG files  
            for size in [16, 32, 64, 128, 256, 512, 1024] {
                let filename = "icon_\(size)x\(size)\(size >= 512 ? "@2x" : "").png"
                try? FileManager.default.removeItem(atPath: filename)
            }
        } else {
            print("❌ Failed to create .icns file")
        }
        
    } catch {
        print("❌ Failed to create iconset: \(error)")
    }
}

// Run the generator
generateAppIcon()