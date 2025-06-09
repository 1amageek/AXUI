import Foundation
import ApplicationServices
import AppKit

// MARK: - AX Dumper

public struct AXDumper {
    
    /// Check if accessibility permissions are granted
    public static func checkAccessibilityPermissions() -> Bool {
        return AXIsProcessTrusted()
    }
    
    /// Request accessibility permissions with prompt
    @MainActor
    public static func requestAccessibilityPermissions() -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
    
    /// Dump AX tree for a running application by bundle identifier
    public static func dump(bundleIdentifier: String, maxDepth: Int = 10, maxChildren: Int = 10) throws -> String {
        // Check accessibility permissions first
        guard checkAccessibilityPermissions() else {
            throw AXDumperError.accessibilityPermissionDenied
        }
        
        let runningApps = NSWorkspace.shared.runningApplications
                
        guard let targetApp = runningApps.first(where: { $0.bundleIdentifier == bundleIdentifier }) else {
            throw AXDumperError.applicationNotFound(bundleIdentifier)
        }
        
        let pid = targetApp.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)
        
        return try dumpElement(appElement, depth: 0, maxDepth: maxDepth, maxChildren: maxChildren)
    }
    
    /// List all running applications with their bundle identifiers
    public static func listRunningApps() -> [(name: String, bundleId: String?)] {
        return NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .map { (name: $0.localizedName ?? "Unknown", bundleId: $0.bundleIdentifier) }
    }
    
    /// Window information structure
    public struct WindowInfo {
        public let index: Int
        public let title: String?
        public let role: String?
        public let subrole: String?
        public let position: CGPoint?
        public let size: CGSize?
        public let element: AXUIElement
    }
    
    /// List all windows for an application
    public static func listWindows(bundleIdentifier: String) throws -> [WindowInfo] {
        guard checkAccessibilityPermissions() else {
            throw AXDumperError.accessibilityPermissionDenied
        }
        
        let runningApps = NSWorkspace.shared.runningApplications
        guard let targetApp = runningApps.first(where: { $0.bundleIdentifier == bundleIdentifier }) else {
            throw AXDumperError.applicationNotFound(bundleIdentifier)
        }
        
        let pid = targetApp.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)
        
        // Get windows
        guard let windows = getChildrenProperty(appElement)?.filter({ 
            getStringProperty($0, kAXRoleAttribute) == kAXWindowRole as String 
        }) else {
            return []
        }
        
        return windows.enumerated().map { index, window in
            WindowInfo(
                index: index,
                title: getStringProperty(window, kAXTitleAttribute),
                role: getStringProperty(window, kAXRoleAttribute),
                subrole: getStringProperty(window, kAXSubroleAttribute),
                position: getPositionProperty(window),
                size: getSizeProperty(window),
                element: window
            )
        }
    }
    
    /// Dump AX tree for a specific window
    public static func dumpWindow(bundleIdentifier: String, windowIndex: Int, maxDepth: Int = 10, maxChildren: Int = 10) throws -> String {
        let windows = try listWindows(bundleIdentifier: bundleIdentifier)
        
        guard windowIndex >= 0 && windowIndex < windows.count else {
            throw AXDumperError.windowNotFound(windowIndex, windows.count)
        }
        
        let window = windows[windowIndex]
        return try dumpElement(window.element, depth: 0, maxDepth: maxDepth, maxChildren: maxChildren)
    }
    
    // MARK: - Private Implementation
    
    private static func dumpElement(_ element: AXUIElement, depth: Int, maxDepth: Int, maxChildren: Int) throws -> String {
        var result = ""
        let indent = String(repeating: "  ", count: depth)
        
        // Stop if we've reached max depth
        guard depth <= maxDepth else {
            return result
        }
        
        // Get basic properties
        if let role = getStringProperty(element, kAXRoleAttribute) {
            result += "\(indent)Role: \(role)\n"
        }
        
        if let value = getStringProperty(element, kAXValueAttribute) {
            result += "\(indent)Value: \(value)\n"
        }
        
        if let identifier = getStringProperty(element, kAXIdentifierAttribute) {
            result += "\(indent)Identifier: \(identifier)\n"
        }
        
        if let roleDescription = getStringProperty(element, kAXRoleDescriptionAttribute) {
            result += "\(indent)RoleDescription: \(roleDescription)\n"
        }
        
        if let help = getStringProperty(element, kAXHelpAttribute) {
            result += "\(indent)Help: \(help)\n"
        }
        
        // Get position and size
        if let position = getPositionProperty(element) {
            result += "\(indent)Position: (\(Int(position.x)), \(Int(position.y)))\n"
        }
        
        if let size = getSizeProperty(element) {
            result += "\(indent)Size: (\(Int(size.width)), \(Int(size.height)))\n"
        }
        
        // Get state properties
        if let selected = getBoolProperty(element, kAXSelectedAttribute) {
            result += "\(indent)Selected: \(selected)\n"
        }
        
        if let enabled = getBoolProperty(element, kAXEnabledAttribute) {
            result += "\(indent)Enabled: \(enabled)\n"
        }
        
        if let focused = getBoolProperty(element, kAXFocusedAttribute) {
            result += "\(indent)Focused: \(focused)\n"
        }
        
        // Get children
        if depth < maxDepth {
            if let children = getChildrenProperty(element) {
                let limitedChildren = Array(children.prefix(maxChildren))
                for (index, child) in limitedChildren.enumerated() {
                    result += "\(indent)  Child[\(index)]:\n"
                    result += try dumpElement(child, depth: depth + 1, maxDepth: maxDepth, maxChildren: maxChildren)
                }
            }
        }
        
        return result
    }
    
    // MARK: - Property Getters
    
    private static func getStringProperty(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        
        guard result == .success, let stringValue = value as? String else {
            return nil
        }
        
        return stringValue
    }
    
    private static func getBoolProperty(_ element: AXUIElement, _ attribute: String) -> Bool? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        
        guard result == .success, let boolValue = value as? Bool else {
            return nil
        }
        
        return boolValue
    }
    
    private static func getPositionProperty(_ element: AXUIElement) -> CGPoint? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &value)
        
        guard result == .success,
              let axValue = value,
              CFGetTypeID(axValue) == AXValueGetTypeID() else {
            return nil
        }
        
        var point = CGPoint.zero
        guard AXValueGetValue(axValue as! AXValue, .cgPoint, &point) else {
            return nil
        }
        
        return point
    }
    
    private static func getSizeProperty(_ element: AXUIElement) -> CGSize? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &value)
        
        guard result == .success,
              let axValue = value,
              CFGetTypeID(axValue) == AXValueGetTypeID() else {
            return nil
        }
        
        var size = CGSize.zero
        guard AXValueGetValue(axValue as! AXValue, .cgSize, &size) else {
            return nil
        }
        
        return size
    }
    
    private static func getChildrenProperty(_ element: AXUIElement) -> [AXUIElement]? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value)
        
        guard result == .success, let children = value as? [AXUIElement] else {
            return nil
        }
        
        return children
    }
}

// MARK: - AX Dumper Errors

public enum AXDumperError: Error, LocalizedError, Equatable {
    case applicationNotFound(String)
    case noFrontmostApp
    case noBundleIdentifier
    case accessibilityPermissionDenied
    case windowNotFound(Int, Int)
    
    public var errorDescription: String? {
        switch self {
        case .applicationNotFound(let bundleId):
            return "Application with bundle identifier '\(bundleId)' not found"
        case .noFrontmostApp:
            return "No frontmost application found"
        case .noBundleIdentifier:
            return "Application has no bundle identifier"
        case .accessibilityPermissionDenied:
            return "Accessibility permission denied. Please enable accessibility access for this application in System Preferences."
        case .windowNotFound(let index, let total):
            return "Window index \(index) not found. Application has \(total) window(s)."
        }
    }
}
