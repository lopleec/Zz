import Foundation
import ApplicationServices

// MARK: - Accessibility Reader

class AccessibilityReader {
    static let shared = AccessibilityReader()

    var hasPermission: Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Request accessibility permission (opens System Settings)
    func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    /// Get the focused application info
    func getFocusedApp() -> AccessibilityInfo? {
        let systemWide = AXUIElementCreateSystemWide()

        var focusedApp: AnyObject?
        let err = AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedApp)
        guard err == .success, let app = focusedApp else { return nil }

        let element = app as! AXUIElement
        return extractInfo(from: element, depth: 0, maxDepth: 2)
    }

    /// Get the focused UI element and its text content
    func getFocusedElementText() -> String? {
        let systemWide = AXUIElementCreateSystemWide()

        var focusedElement: AnyObject?
        let err = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        guard err == .success, let element = focusedElement else { return nil }

        var value: AnyObject?
        let valueErr = AXUIElementCopyAttributeValue(element as! AXUIElement, kAXValueAttribute as CFString, &value)
        if valueErr == .success, let text = value as? String {
            return text
        }
        return nil
    }

    /// Get a structured description of the current screen's UI tree
    func getScreenDescription() -> String {
        guard hasPermission else {
            return "[Accessibility permission not granted. Using screenshot mode.]"
        }

        guard let info = getFocusedApp() else {
            return "[No focused application found]"
        }

        return formatAccessibilityInfo(info, indent: 0)
    }

    /// Get window list with titles
    func getWindowList() -> [(app: String, title: String, bounds: CGRect)] {
        var result: [(app: String, title: String, bounds: CGRect)] = []

        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return result
        }

        for window in windowList {
            let ownerName = window[kCGWindowOwnerName as String] as? String ?? "Unknown"
            let windowName = window[kCGWindowName as String] as? String ?? ""
            let layer = window[kCGWindowLayer as String] as? Int ?? 0

            // Only include normal windows (layer 0)
            guard layer == 0, !windowName.isEmpty else { continue }

            var bounds = CGRect.zero
            if let boundsDict = window[kCGWindowBounds as String] as? [String: Any] {
                bounds = CGRect(
                    x: boundsDict["X"] as? CGFloat ?? 0,
                    y: boundsDict["Y"] as? CGFloat ?? 0,
                    width: boundsDict["Width"] as? CGFloat ?? 0,
                    height: boundsDict["Height"] as? CGFloat ?? 0
                )
            }

            result.append((app: ownerName, title: windowName, bounds: bounds))
        }

        return result
    }

    // MARK: - Private

    private func extractInfo(from element: AXUIElement, depth: Int, maxDepth: Int) -> AccessibilityInfo {
        var info = AccessibilityInfo()

        // Get role
        var role: AnyObject?
        if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role) == .success {
            info.role = role as? String ?? ""
        }

        // Get title
        var title: AnyObject?
        if AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &title) == .success {
            info.title = title as? String ?? ""
        }

        // Get value
        var value: AnyObject?
        if AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value) == .success {
            if let s = value as? String {
                info.value = s
            } else if let n = value as? NSNumber {
                info.value = n.stringValue
            }
        }

        // Get description
        var desc: AnyObject?
        if AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &desc) == .success {
            info.axDescription = desc as? String ?? ""
        }

        // Get position
        var pos: AnyObject?
        if AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &pos) == .success {
            var point = CGPoint.zero
            if AXValueGetValue(pos as! AXValue, .cgPoint, &point) {
                info.position = point
            }
        }

        // Get size
        var sizeVal: AnyObject?
        if AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeVal) == .success {
            var size = CGSize.zero
            if AXValueGetValue(sizeVal as! AXValue, .cgSize, &size) {
                info.size = size
            }
        }

        // Recurse into children (limited depth)
        if depth < maxDepth {
            var children: AnyObject?
            if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children) == .success {
                if let childElements = children as? [AXUIElement] {
                    info.children = childElements.prefix(20).map {
                        extractInfo(from: $0, depth: depth + 1, maxDepth: maxDepth)
                    }
                }
            }
        }

        return info
    }

    private func formatAccessibilityInfo(_ info: AccessibilityInfo, indent: Int) -> String {
        let prefix = String(repeating: "  ", count: indent)
        var parts: [String] = []

        var line = "\(prefix)[\(info.role ?? "?")]"
        if let title = info.title, !title.isEmpty { line += " title=\"\(title)\"" }
        if let value = info.value, !value.isEmpty {
            let truncated = value.count > 50 ? String(value.prefix(50)) + "..." : value
            line += " value=\"\(truncated)\""
        }
        if let pos = info.position, let size = info.size {
            line += " pos=(\(Int(pos.x)),\(Int(pos.y))) size=(\(Int(size.width))x\(Int(size.height)))"
        }
        parts.append(line)

        for child in info.children {
            parts.append(formatAccessibilityInfo(child, indent: indent + 1))
        }

        return parts.joined(separator: "\n")
    }
}

// MARK: - Accessibility Info Model

struct AccessibilityInfo {
    var role: String?
    var title: String?
    var value: String?
    var axDescription: String?
    var position: CGPoint?
    var size: CGSize?
    var children: [AccessibilityInfo] = []
}
