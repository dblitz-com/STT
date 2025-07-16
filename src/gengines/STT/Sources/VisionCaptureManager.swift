import Foundation
import ScreenCaptureKit
import CoreImage
import AppKit
import OSLog

@available(macOS 12.3, *)
class VisionCaptureManager: NSObject, ObservableObject {
    
    // MARK: - Private Properties
    private var stream: SCStream?
    private var filter: SCContentFilter?
    private var streamConfiguration: SCStreamConfiguration
    private let logger = Logger(subsystem: "com.stt.dictate", category: "VisionCapture")
    
    // Image optimization settings (Glass Sharp equivalent)
    private let targetHeight: CGFloat = 384
    private let jpegQuality: CGFloat = 0.8
    
    // Core Image context for GPU-accelerated processing
    private let ciContext = CIContext(options: [
        .useSoftwareRenderer: false,
        .priorityRequestLow: false
    ])
    
    // Capture state
    @Published var isCaptureReady = false
    @Published var lastCaptureTime: Date?
    private var isCapturing = false
    
    // Queue for background processing
    private let processingQueue = DispatchQueue(label: "com.stt.vision.processing", qos: .userInitiated)
    
    // MARK: - Initialization
    override init() {
        // Initialize stream configuration with research-based optimizations
        self.streamConfiguration = SCStreamConfiguration()
        super.init()
        
        setupStreamConfiguration()
        logger.info("🔍 VisionCaptureManager initialized")
    }
    
    // MARK: - Setup Methods
    private func setupStreamConfiguration() {
        // Dynamic resolution based on main display
        guard let mainScreen = NSScreen.main else {
            logger.error("❌ No main screen found")
            return
        }
        
        let displaySize = mainScreen.frame.size
        streamConfiguration.width = Int(displaySize.width)
        streamConfiguration.height = Int(displaySize.height)
        
        // Optimize for vision processing (research specs)
        streamConfiguration.minimumFrameInterval = CMTimeMake(value: 1, timescale: 1) // 1 FPS max
        streamConfiguration.pixelFormat = kCVPixelFormatType_32BGRA
        streamConfiguration.queueDepth = 3 // Minimal buffer for memory efficiency
        streamConfiguration.showsCursor = false // Don't include cursor in capture
        
        logger.info("📋 Stream config: \(Int(displaySize.width))x\(Int(displaySize.height)), 1 FPS, BGRA format")
    }
    
    func setupCapture() async throws {
        logger.info("🔧 Setting up ScreenCaptureKit capture...")
        
        // Check for Screen Recording permission
        let hasPermission = await checkScreenRecordingPermission()
        guard hasPermission else {
            throw VisionCaptureError.permissionDenied
        }
        
        // Get available displays
        let availableDisplays = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        
        guard let mainDisplay = availableDisplays.displays.first else {
            throw VisionCaptureError.noDisplaysAvailable
        }
        
        // Exclude Zeus_STT windows from capture
        let excludedWindows = getZeusSTTWindows(from: availableDisplays.windows)
        
        // Create content filter
        self.filter = SCContentFilter(
            display: mainDisplay,
            excludingWindows: excludedWindows
        )
        
        guard let filter = self.filter else {
            throw VisionCaptureError.filterCreationFailed
        }
        
        logger.info("✅ Content filter created, excluding \(excludedWindows.count) Zeus_STT windows")
        
        // Create stream
        self.stream = SCStream(filter: filter, configuration: streamConfiguration, delegate: self)
        
        // Add stream output for sample buffer processing
        try stream?.addStreamOutput(self, type: .screen, sampleHandlerQueue: processingQueue)
        
        await MainActor.run {
            self.isCaptureReady = true
        }
        
        logger.info("✅ Vision capture setup complete")
    }
    
    private func checkScreenRecordingPermission() async -> Bool {
        // Check current permission status
        guard CGPreflightScreenCaptureAccess() else {
            logger.warning("⚠️ Screen recording permission not granted")
            
            // Request permission
            let granted = CGRequestScreenCaptureAccess()
            if granted {
                logger.info("✅ Screen recording permission granted")
                return true
            } else {
                logger.error("❌ Screen recording permission denied by user")
                return false
            }
        }
        
        logger.info("✅ Screen recording permission already granted")
        return true
    }
    
    private func getZeusSTTWindows(from windows: [SCWindow]) -> [SCWindow] {
        // Filter windows that belong to Zeus_STT app
        return windows.filter { window in
            guard let ownerName = window.owningApplication?.applicationName else { return false }
            return ownerName.contains("STT") || ownerName.contains("Zeus")
        }
    }
    
    // MARK: - Capture Methods
    
    /// Capture a single frame for vision processing
    func captureSingleFrame() async throws -> Data? {
        logger.info("📸 Capturing single frame for vision processing...")
        
        guard let filter = self.filter else {
            throw VisionCaptureError.notInitialized
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    // Use SCScreenshotManager for single frame capture
                    let cgImage = try await SCScreenshotManager.captureImage(
                        contentFilter: filter,
                        configuration: streamConfiguration
                    )
                    
                    // Optimize image on background queue
                    processingQueue.async {
                        let optimizedData = self.optimizeImage(cgImage)
                        continuation.resume(returning: optimizedData)
                    }
                    
                } catch {
                    self.logger.error("❌ Screenshot capture failed: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Start continuous capture stream (for future real-time processing)
    func startContinuousCapture() async throws {
        guard let stream = self.stream else {
            throw VisionCaptureError.notInitialized
        }
        
        logger.info("🎬 Starting continuous capture stream...")
        
        try await stream.startCapture()
        isCapturing = true
        
        logger.info("✅ Continuous capture started")
    }
    
    /// Stop continuous capture stream
    func stopContinuousCapture() async {
        guard let stream = self.stream, isCapturing else { return }
        
        logger.info("🛑 Stopping continuous capture stream...")
        
        do {
            try await stream.stopCapture()
            isCapturing = false
            logger.info("✅ Continuous capture stopped")
        } catch {
            logger.error("❌ Failed to stop capture: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Image Optimization (Glass Sharp Equivalent)
    
    private func optimizeImage(_ cgImage: CGImage) -> Data? {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Convert to CIImage for GPU processing
        let ciImage = CIImage(cgImage: cgImage)
        
        // Calculate scale factor to achieve target height (384px)
        let currentHeight = ciImage.extent.height
        let scaleFactor = targetHeight / currentHeight
        
        // Apply Lanczos scale transform (high quality)
        guard let scaleFilter = CIFilter(name: "CILanczosScaleTransform") else {
            logger.error("❌ Failed to create scale filter")
            return fallbackOptimization(cgImage)
        }
        
        scaleFilter.setValue(ciImage, forKey: kCIInputImageKey)
        scaleFilter.setValue(scaleFactor, forKey: kCIInputScaleKey)
        scaleFilter.setValue(1.0, forKey: kCIInputAspectRatioKey)
        
        guard let scaledImage = scaleFilter.outputImage else {
            logger.error("❌ Scale filter failed")
            return fallbackOptimization(cgImage)
        }
        
        // Create JPEG representation with specified quality
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let options: [CIImageRepresentationOption: Any] = [
            kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: jpegQuality
        ]
        
        guard let jpegData = ciContext.jpegRepresentation(
            of: scaledImage,
            colorSpace: colorSpace,
            options: options
        ) else {
            logger.error("❌ JPEG conversion failed")
            return fallbackOptimization(cgImage)
        }
        
        let processingTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        logger.info("✅ Image optimized: \(cgImage.width)x\(cgImage.height) → \(Int(scaledImage.extent.width))x\(Int(scaledImage.extent.height)), \(jpegData.count) bytes, \(String(format: "%.1f", processingTime))ms")
        
        // Update last capture time
        Task { @MainActor in
            self.lastCaptureTime = Date()
        }
        
        return jpegData
    }
    
    private func fallbackOptimization(_ cgImage: CGImage) -> Data? {
        // Fallback: Basic bitmap representation without optimization
        logger.warning("⚠️ Using fallback image optimization")
        
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: jpegQuality])
    }
    
    // MARK: - Integration Methods
    
    /// Get current screen context for vision analysis
    func getCurrentScreenContext() async -> ScreenContext? {
        do {
            guard let imageData = try await captureSingleFrame() else {
                logger.error("❌ Failed to capture screen for context")
                return nil
            }
            
            return ScreenContext(
                imageData: imageData,
                timestamp: Date(),
                screenSize: CGSize(
                    width: streamConfiguration.width,
                    height: streamConfiguration.height
                )
            )
        } catch {
            logger.error("❌ Screen context capture failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    deinit {
        // Synchronous cleanup - stream will be automatically cleaned up
        if let stream = stream, isCapturing {
            // Note: async stopCapture() should be called before deinit in production
            logger.warning("⚠️ Stream still capturing during deinit")
        }
        logger.info("🗑️ VisionCaptureManager deallocated")
    }
}

// MARK: - SCStreamDelegate
@available(macOS 12.3, *)
extension VisionCaptureManager: SCStreamDelegate {
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        logger.error("🚨 Stream stopped with error: \(error.localizedDescription)")
        isCapturing = false
    }
}

// MARK: - SCStreamOutput
@available(macOS 12.3, *)
extension VisionCaptureManager: SCStreamOutput {
    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        // Handle continuous stream frames here (for future real-time processing)
        guard type == .screen else { return }
        
        // Convert sample buffer to CGImage for processing
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            logger.error("❌ Failed to get image buffer from sample")
            return
        }
        
        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            logger.error("❌ Failed to create CGImage from sample buffer")
            return
        }
        
        // Process frame in background
        processingQueue.async {
            let _ = self.optimizeImage(cgImage)
            // Future: Send to vision pipeline for real-time analysis
        }
    }
}

// MARK: - Data Structures

struct ScreenContext {
    let imageData: Data
    let timestamp: Date
    let screenSize: CGSize
    
    var base64String: String {
        return imageData.base64EncodedString()
    }
    
    var sizeDescription: String {
        return "\(Int(screenSize.width))x\(Int(screenSize.height))"
    }
}

// MARK: - Error Types

enum VisionCaptureError: LocalizedError {
    case permissionDenied
    case noDisplaysAvailable
    case filterCreationFailed
    case notInitialized
    case captureTimeout
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Screen recording permission is required for vision features"
        case .noDisplaysAvailable:
            return "No displays available for screen capture"
        case .filterCreationFailed:
            return "Failed to create screen capture filter"
        case .notInitialized:
            return "Vision capture manager not properly initialized"
        case .captureTimeout:
            return "Screen capture timed out"
        }
    }
}