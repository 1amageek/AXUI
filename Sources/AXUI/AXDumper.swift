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
    
    /// Dump AX tree for a running application by bundle identifier with multiple filters
    public static func dump(bundleIdentifier: String, filters: [String]? = nil) throws -> String {
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
        
        return try dumpElement(appElement, depth: 0, filters: filters)
    }
    
    /// Dump AX tree for a running application by bundle identifier with single filter (convenience method)
    public static func dump(bundleIdentifier: String, filter: String) throws -> String {
        let filters = filter.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        return try dump(bundleIdentifier: bundleIdentifier, filters: filters)
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
    public static func dumpWindow(bundleIdentifier: String, windowIndex: Int, filters: [String]? = nil) throws -> String {
        let windows = try listWindows(bundleIdentifier: bundleIdentifier)
        
        guard windowIndex >= 0 && windowIndex < windows.count else {
            throw AXDumperError.windowNotFound(windowIndex, windows.count)
        }
        
        let window = windows[windowIndex]
        return try dumpElement(window.element, depth: 0, filters: filters)
    }
    
    /// Dump AX tree for a specific window with single filter (convenience method)
    public static func dumpWindow(bundleIdentifier: String, windowIndex: Int, filter: String) throws -> String {
        let filters = filter.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        return try dumpWindow(bundleIdentifier: bundleIdentifier, windowIndex: windowIndex, filters: filters)
    }
    
    // MARK: - Private Implementation
    
    private static func dumpElement(_ element: AXUIElement, depth: Int, filters: [String]? = nil) throws -> String {
        // If filtering is enabled, return flat list of matching elements
        if let filters = filters, !filters.isEmpty && !filters.contains("all") {
            return try dumpElementsFlat(element, filters: filters)
        }
        
        // Otherwise, return hierarchical structure
        return try dumpElementHierarchical(element, depth: depth)
    }
    
    private static func dumpElementsFlat(_ rootElement: AXUIElement, filters: [String]) throws -> String {
        var result = ""
        var stack: [AXUIElement] = [rootElement]
        var elementIndex = 0
        
        while !stack.isEmpty {
            let element = stack.removeLast()
            let role = getStringProperty(element, kAXRoleAttribute)
            
            // Check if element matches filter
            if shouldIncludeElement(role: role, filters: filters) {
                result += "Element[\(elementIndex)]:\n"
                
                // Get basic properties
                if let role = role {
                    result += "  Role: \(role)\n"
                }
                
                if let value = getStringProperty(element, kAXValueAttribute) {
                    result += "  Value: \(value)\n"
                }
                
                if let identifier = getStringProperty(element, kAXIdentifierAttribute) {
                    result += "  Identifier: \(identifier)\n"
                }
                
                if let roleDescription = getStringProperty(element, kAXRoleDescriptionAttribute) {
                    result += "  RoleDescription: \(roleDescription)\n"
                }
                
                if let help = getStringProperty(element, kAXHelpAttribute) {
                    result += "  Help: \(help)\n"
                }
                
                // Get position and size (important for interactive elements)
                if let position = getPositionProperty(element) {
                    result += "  Position: (\(Int(position.x)), \(Int(position.y)))\n"
                }
                
                if let size = getSizeProperty(element) {
                    result += "  Size: (\(Int(size.width)), \(Int(size.height)))\n"
                }
                
                // Get state properties
                if let selected = getBoolProperty(element, kAXSelectedAttribute) {
                    result += "  Selected: \(selected)\n"
                }
                
                if let enabled = getBoolProperty(element, kAXEnabledAttribute) {
                    result += "  Enabled: \(enabled)\n"
                }
                
                if let focused = getBoolProperty(element, kAXFocusedAttribute) {
                    result += "  Focused: \(focused)\n"
                }
                
                // Include children information for context (labels, icons, etc.)
                if let children = getChildrenProperty(element) {
                    result += try dumpChildrenFlat(children, indent: "  ")
                }
                
                elementIndex += 1
            }
            
            // Add children to stack for traversal
            if let children = getChildrenProperty(element) {
                stack.append(contentsOf: children.reversed())
            }
        }
        
        return result
    }
    
    private static func dumpElementHierarchical(_ element: AXUIElement, depth: Int) throws -> String {
        var result = ""
        let indent = String(repeating: "  ", count: depth)
        
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
        if let children = getChildrenProperty(element) {
            for (index, child) in children.enumerated() {
                result += "\(indent)  Child[\(index)]:\n"
                result += try dumpElementHierarchical(child, depth: depth + 1)
            }
        }
        
        return result
    }
    
    private static func dumpChildrenFlat(_ children: [AXUIElement], indent: String) throws -> String {
        var result = ""
        
        for (index, child) in children.enumerated() {
            result += "\(indent)Child[\(index)]:\n"
            
            // Get child properties
            if let role = getStringProperty(child, kAXRoleAttribute) {
                result += "\(indent)  Role: \(role)\n"
            }
            
            if let value = getStringProperty(child, kAXValueAttribute) {
                result += "\(indent)  Value: \(value)\n"
            }
            
            if let identifier = getStringProperty(child, kAXIdentifierAttribute) {
                result += "\(indent)  Identifier: \(identifier)\n"
            }
            
            if let roleDescription = getStringProperty(child, kAXRoleDescriptionAttribute) {
                result += "\(indent)  RoleDescription: \(roleDescription)\n"
            }
            
            if let help = getStringProperty(child, kAXHelpAttribute) {
                result += "\(indent)  Help: \(help)\n"
            }
            
            // Position and size for child elements
            if let position = getPositionProperty(child) {
                result += "\(indent)  Position: (\(Int(position.x)), \(Int(position.y)))\n"
            }
            
            if let size = getSizeProperty(child) {
                result += "\(indent)  Size: (\(Int(size.width)), \(Int(size.height)))\n"
            }
            
            // State properties
            if let selected = getBoolProperty(child, kAXSelectedAttribute) {
                result += "\(indent)  Selected: \(selected)\n"
            }
            
            if let enabled = getBoolProperty(child, kAXEnabledAttribute) {
                result += "\(indent)  Enabled: \(enabled)\n"
            }
            
            if let focused = getBoolProperty(child, kAXFocusedAttribute) {
                result += "\(indent)  Focused: \(focused)\n"
            }
            
            // Recursively include grandchildren (but keep them flat)
            if let grandchildren = getChildrenProperty(child) {
                result += try dumpChildrenFlat(grandchildren, indent: "\(indent)  ")
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
    
    private static func shouldIncludeElement(role: String?, filters: [String]) -> Bool {
        guard let role = role else { return false }
        
        for filter in filters {
            if shouldIncludeElementForSingleFilter(role: role, filter: filter) {
                return true
            }
        }
        return false
    }
    
    private static func shouldIncludeElementForSingleFilter(role: String, filter: String) -> Bool {
        switch filter.lowercased() {
        case "button":
            return role == kAXButtonRole as String
        case "textfield":
            return role == kAXTextFieldRole as String || role == kAXTextAreaRole as String
        case "checkbox":
            return role == kAXCheckBoxRole as String
        case "radiobutton":
            return role == kAXRadioButtonRole as String
        case "slider":
            return role == kAXSliderRole as String
        case "popupbutton":
            return role == kAXPopUpButtonRole as String
        case "tab":
            return role == "AXTab"
        case "menuitem":
            return role == kAXMenuItemRole as String
        case "link":
            return role == "AXLink"
        case "interactive":
            return isInteractiveRole(role)
        default:
            return false
        }
    }
    
    private static func isInteractiveRole(_ role: String) -> Bool {
        let interactiveRoles = [
            kAXButtonRole as String,
            kAXTextFieldRole as String,
            kAXTextAreaRole as String,
            kAXCheckBoxRole as String,
            kAXRadioButtonRole as String,
            kAXSliderRole as String,
            kAXPopUpButtonRole as String,
            "AXTab",
            kAXMenuItemRole as String,
            "AXLink",
            kAXMenuButtonRole as String,
            kAXColorWellRole as String,
            kAXComboBoxRole as String,
            kAXDisclosureTriangleRole as String,
            kAXIncrementorRole as String,
            "AXSearchField"
        ]
        return interactiveRoles.contains(role)
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
