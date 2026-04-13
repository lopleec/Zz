import Foundation
import CoreGraphics
import AppKit
import ScreenCaptureKit

// MARK: - Screen Capture Service

class ScreenCapture {
    static let shared = ScreenCapture()

    /// Check Screen Recording permission
    var hasScreenRecordingPermission: Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// Request Screen Recording permission
    func requestPermission() {
        CGRequestScreenCaptureAccess()
    }

    /// Get the leftmost display
    func getLeftmostDisplay() -> CGDirectDisplayID {
        var displayCount: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &displayCount)

        var displays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        CGGetActiveDisplayList(displayCount, &displays, &displayCount)

        guard !displays.isEmpty else { return CGMainDisplayID() }

        // Find the display with the smallest x origin (leftmost)
        var leftmostDisplay = displays[0]
        var minX = CGFloat.infinity

        for display in displays {
            let bounds = CGDisplayBounds(display)
            if bounds.origin.x < minX {
                minX = bounds.origin.x
                leftmostDisplay = display
            }
        }

        return leftmostDisplay
    }

    /// Get display info for the target display
    func getDisplayInfo() -> (width: Int, height: Int, displayID: CGDirectDisplayID) {
        let displayID = getLeftmostDisplay()
        let width = CGDisplayPixelsWide(displayID)
        let height = CGDisplayPixelsHigh(displayID)
        return (width, height, displayID)
    }

    /// Capture screenshot using ScreenCaptureKit (modern API, macOS 14+)
    @available(macOS 14.0, *)
    func captureScreenCaptureKit() async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        // Find the leftmost display
        let displayInfo = getDisplayInfo()
        guard let display = content.displays.first(where: {
            $0.displayID == displayInfo.displayID
        }) ?? content.displays.first else {
            throw ScreenCaptureError.noDisplay
        }

        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])

        let config = SCStreamConfiguration()
        config.width = displayInfo.width
        config.height = displayInfo.height
        config.showsCursor = true
        config.capturesAudio = false

        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        return image
    }

    /// Capture screenshot using legacy CGWindowListCreateImage
    func captureScreenLegacy() -> CGImage? {
        let displayID = getLeftmostDisplay()
        let bounds = CGDisplayBounds(displayID)
        return CGWindowListCreateImage(bounds, .optionOnScreenOnly, kCGNullWindowID, .bestResolution)
    }

    /// Unified capture method with fallback
    func captureScreen() async -> CGImage? {
        if #available(macOS 14.0, *) {
            do {
                return try await captureScreenCaptureKit()
            } catch {
                print("[ScreenCapture] ScreenCaptureKit failed: \(error), falling back to legacy")
                return captureScreenLegacy()
            }
        } else {
            return captureScreenLegacy()
        }
    }

    /// Capture and return as JPEG data (ready for API)
    func captureScreenAsJPEG() async -> Data? {
        guard let image = await captureScreen() else {
            print("[ScreenCapture] captureScreen returned nil — permission denied or no display")
            return nil
        }
        let data = ImageUtils.cgImageToJPEG(image)
        print("[ScreenCapture] JPEG data size: \(data?.count ?? 0) bytes")
        return data
    }

    /// Capture and return as base64 string
    func captureScreenAsBase64() async -> String? {
        guard let image = await captureScreen() else { return nil }
        return ImageUtils.cgImageToBase64(image)
    }

    /// Get scaled dimensions for the target display
    func getScaledDimensions() -> (width: Int, height: Int, scale: CGFloat) {
        let info = getDisplayInfo()
        return ImageUtils.scaledDimensions(screenWidth: info.width, screenHeight: info.height)
    }
}

// MARK: - Errors

enum ScreenCaptureError: LocalizedError {
    case noDisplay
    case captureFailed
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .noDisplay: return "No display found"
        case .captureFailed: return "Screen capture failed"
        case .permissionDenied: return "Screen recording permission denied"
        }
    }
}
