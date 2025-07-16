#!/usr/bin/env swift

import Foundation
import ScreenCaptureKit

print("🧪 Testing Vision Capture directly...")

@available(macOS 12.3, *)
func testVisionCapture() async {
    do {
        print("📱 Getting available content...")
        let content = try await SCShareableContent.current
        
        guard let mainDisplay = content.displays.first else {
            print("❌ No displays found")
            return
        }
        
        print("✅ Found display: \(mainDisplay)")
        print("   Display size: \(mainDisplay.width) x \(mainDisplay.height)")
        
        // Create content filter (exclude nothing)
        let filter = SCContentFilter(
            display: mainDisplay,
            excludingWindows: []
        )
        
        // Create stream configuration  
        let config = SCStreamConfiguration()
        config.width = Int(mainDisplay.width)
        config.height = Int(mainDisplay.height)
        config.captureResolution = .best
        config.pixelFormat = kCVPixelFormatType_32BGRA
        
        print("📸 Attempting screen capture...")
        
        // Capture single frame
        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )
        
        print("✅ Screen capture successful!")
        print("   Image size: \(image.width) x \(image.height)")
        
        // Convert to JPEG data
        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        let tiffData = nsImage.tiffRepresentation!
        let bitmap = NSBitmapImageRep(data: tiffData)!
        let jpegData = bitmap.representation(using: NSBitmapImageRep.FileType.jpeg, properties: [NSBitmapImageRep.PropertyKey.compressionFactor: 0.8])!
        
        print("   JPEG size: \(jpegData.count) bytes (\(jpegData.count / 1024)KB)")
        
        // Save to Desktop
        let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        let testImageURL = desktopURL.appendingPathComponent("vision_test_direct.jpg")
        
        try jpegData.write(to: testImageURL)
        print("✅ Test image saved to: \(testImageURL.path)")
        
        // Open the image
        NSWorkspace.shared.open(testImageURL)
        
    } catch {
        print("❌ Error: \(error)")
        
        if let scError = error as? SCStreamError {
            switch scError.code {
            case .userDeclined:
                print("   ⚠️  User declined screen recording permission")
                print("   💡 Grant permission in System Settings > Privacy & Security > Screen Recording")
            default:
                print("   Error code: \(scError.code)")
            }
        }
    }
}

// Run the test
if #available(macOS 12.3, *) {
    Task {
        await testVisionCapture()
        exit(0)
    }
    RunLoop.main.run()
} else {
    print("❌ This test requires macOS 12.3 or later")
    exit(1)
}