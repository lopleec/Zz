import Foundation
import CoreGraphics
import AppKit
import ImageIO

// MARK: - Image Utilities

struct ImageUtils {
    /// Scale factor to meet Claude API constraints (max 1568px longest edge, ~1.15 megapixels)
    static func getScaleFactor(width: Int, height: Int) -> CGFloat {
        let longEdge = max(width, height)
        let totalPixels = width * height
        let longEdgeScale = 1568.0 / Double(longEdge)
        let totalPixelsScale = sqrt(1_150_000.0 / Double(totalPixels))
        return CGFloat(min(1.0, longEdgeScale, totalPixelsScale))
    }

    /// Convert CGImage to JPEG data with optional resizing
    static func cgImageToJPEG(_ image: CGImage, quality: CGFloat = 0.85, maxSize: Int = 1568) -> Data? {
        let width = image.width
        let height = image.height
        let scale = getScaleFactor(width: width, height: height)

        let scaledWidth = Int(Double(width) * Double(scale))
        let scaledHeight = Int(Double(height) * Double(scale))

        guard let context = CGContext(
            data: nil,
            width: scaledWidth,
            height: scaledHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: scaledWidth, height: scaledHeight))

        guard let scaledImage = context.makeImage() else { return nil }

        let nsImage = NSImage(cgImage: scaledImage, size: NSSize(width: scaledWidth, height: scaledHeight))
        guard let tiffData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }

        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality])
    }

    /// Convert CGImage to base64 encoded JPEG string
    static func cgImageToBase64(_ image: CGImage) -> String? {
        guard let jpegData = cgImageToJPEG(image) else { return nil }
        return jpegData.base64EncodedString()
    }

    /// Convert CGImage to PNG data
    static func cgImageToPNG(_ image: CGImage) -> Data? {
        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        guard let tiffData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }

    /// Get the scaled dimensions for a screen size
    static func scaledDimensions(screenWidth: Int, screenHeight: Int) -> (width: Int, height: Int, scale: CGFloat) {
        let scale = getScaleFactor(width: screenWidth, height: screenHeight)
        return (
            width: Int(Double(screenWidth) * Double(scale)),
            height: Int(Double(screenHeight) * Double(scale)),
            scale: scale
        )
    }

    /// Scale Claude's coordinates back to screen coordinates
    static func scaleCoordinates(_ point: CGPoint, scaleFactor: CGFloat) -> CGPoint {
        return CGPoint(x: point.x / scaleFactor, y: point.y / scaleFactor)
    }

    /// Load image from file path
    static func loadImage(from path: String) -> NSImage? {
        return NSImage(contentsOfFile: path)
    }

    /// Convert NSImage to Data for sending with message
    static func nsImageToJPEGData(_ image: NSImage) -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.85])
    }
}
