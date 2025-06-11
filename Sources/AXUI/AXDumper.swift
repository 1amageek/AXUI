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
    public static func dump(bundleIdentifier: String) throws -> String {
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
        return try dumpElementHierarchical(appElement, depth: 0)
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
    public static func dumpWindow(bundleIdentifier: String, windowIndex: Int) throws -> String {
        let windows = try listWindows(bundleIdentifier: bundleIdentifier)
        
        guard windowIndex >= 0 && windowIndex < windows.count else {
            throw AXDumperError.windowNotFound(windowIndex, windows.count)
        }
        
        let window = windows[windowIndex]
        return try dumpElementHierarchical(window.element, depth: 0)
    }
    
    // MARK: - Private Implementation
    
    
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
            result += "\(indent)Position: (\(safeIntConversion(position.x)), \(safeIntConversion(position.y)))\n"
        }
        
        if let size = getSizeProperty(element) {
            result += "\(indent)Size: (\(safeIntConversion(size.width)), \(safeIntConversion(size.height)))\n"
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
    
    
    // MARK: - Property Getters
    
    private static func safeIntConversion(_ value: Double) -> Int {
        if value.isNaN || value.isInfinite {
            return 0
        }
        return Int(value)
    }
    
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
    
    
    // MARK: - Flat Dumping Methods
    
    /// Dump AX elements as a flat array with optional query filtering
    public static func dumpFlat(bundleIdentifier: String, query: AXQuery? = nil) throws -> [AXElement] {
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
        
        var elements: [AXElement] = []
        
        // Build flat array of elements
        flattenElement(appElement, elements: &elements)
        
        // Apply query filter if provided
        if let query = query {
            return AXQueryMatcher.filter(elements: elements, query: query)
        }
        
        return elements
    }
    
    /// Dump AX elements for a specific window as a flat array
    public static func dumpWindowFlat(bundleIdentifier: String, windowIndex: Int, query: AXQuery? = nil) throws -> [AXElement] {
        let windows = try listWindows(bundleIdentifier: bundleIdentifier)
        
        guard windowIndex >= 0 && windowIndex < windows.count else {
            throw AXDumperError.windowNotFound(windowIndex, windows.count)
        }
        
        let window = windows[windowIndex]
        
        var elements: [AXElement] = []
        
        // Build flat array of elements starting from window
        flattenElement(window.element, elements: &elements)
        
        // Apply query filter if provided
        if let query = query {
            return AXQueryMatcher.filter(elements: elements, query: query)
        }
        
        return elements
    }
    
    /// Query elements with a specific query
    public static func queryElements(bundleIdentifier: String, query: AXQuery) throws -> [AXElement] {
        return try dumpFlat(bundleIdentifier: bundleIdentifier, query: query)
    }
    
    /// Query elements in a specific window
    public static func queryWindowElements(bundleIdentifier: String, windowIndex: Int, query: AXQuery) throws -> [AXElement] {
        return try dumpWindowFlat(bundleIdentifier: bundleIdentifier, windowIndex: windowIndex, query: query)
    }
    
    // MARK: - Private Flattening Implementation
    
    private static func flattenElement(
        _ element: AXUIElement,
        elements: inout [AXElement]
    ) {
        
        // Get element properties
        let role = getStringProperty(element, kAXRoleAttribute)
        let description = getStringProperty(element, kAXDescriptionAttribute)
        let identifier = getStringProperty(element, kAXIdentifierAttribute)
        let roleDescription = getStringProperty(element, kAXRoleDescriptionAttribute)
        let help = getStringProperty(element, kAXHelpAttribute)
        let position = getPositionProperty(element)
        let size = getSizeProperty(element)
        let selected = getBoolProperty(element, kAXSelectedAttribute) ?? false
        let enabled = getBoolProperty(element, kAXEnabledAttribute) ?? true
        let focused = getBoolProperty(element, kAXFocusedAttribute) ?? false
        
        // Convert to bounds array
        let bounds: [Int]? = {
            guard let position = position, let size = size else { return nil }
            return [
                safeIntConversion(position.x),
                safeIntConversion(position.y),
                safeIntConversion(size.width),
                safeIntConversion(size.height)
            ]
        }()
        
        // Skip elements without meaningful content (no role, description, identifier, or roleDescription)
        if role == nil && description == nil && identifier == nil && roleDescription == nil {
            return
        }
        
        // Get children for processing
        let children = getChildrenProperty(element) ?? []
        
        // Normalize role (remove AX prefix)
        let normalizedRole = normalizeRole(role)
        
        // Skip Group elements as they have no meaning in this program
        if normalizedRole == "Group" {
            // Process children but don't include the Group itself
            for child in children {
                flattenElement(child, elements: &elements)
            }
            return
        }
        
        // Determine if this element should include children structure
        let shouldIncludeChildren = isInteractiveElement(role: normalizedRole)
        let childElements: [AXElement] = shouldIncludeChildren ? createChildElements(children) : []
        
        // Create element with children if applicable
        let axElement = AXElement(
            role: normalizedRole,
            description: description,
            identifier: identifier,
            roleDescription: roleDescription,
            help: help,
            bounds: bounds,
            selected: selected,
            enabled: enabled,
            focused: focused,
            children: childElements.isEmpty ? nil : childElements,
            axElementRef: element
        )
        
        // Add to array
        elements.append(axElement)
        
        // Process children for flattening (separate from structure children)
        for child in children {
            flattenElement(child, elements: &elements)
        }
    }
    
    private static func normalizeRole(_ role: String?) -> String? {
        guard let role = role else { return nil }
        
        var normalized = role.hasPrefix("AX") ? String(role.dropFirst(2)) : role
        
        // Further normalize common roles
        switch normalized {
        case "StaticText":
            normalized = "Text"
        case "ScrollArea":
            normalized = "Scroll"
        case "TextField":
            normalized = "Field"
        case "CheckBox":
            normalized = "Check"
        case "RadioButton":
            normalized = "Radio"
        case "PopUpButton":
            normalized = "PopUp"
        default:
            break
        }
        
        return normalized
    }
    
    /// Check if an element is interactive and should include children structure
    private static func isInteractiveElement(role: String?) -> Bool {
        guard let role = role else { return false }
        
        let interactiveRoles = [
            "Button",
            "Field", 
            "Check",
            "Radio",
            "Slider",
            "PopUp",
            "Tab",
            "MenuItem",
            "Link"
        ]
        return interactiveRoles.contains(role)
    }
    
    /// Create child elements for structure, flattening Groups
    private static func createChildElements(_ elements: [AXUIElement]) -> [AXElement] {
        var childElements: [AXElement] = []
        
        for element in elements {
            let role = getStringProperty(element, kAXRoleAttribute)
            let normalizedRole = normalizeRole(role)
            
            // If it's a Group, get its children instead of the Group itself
            if normalizedRole == "Group" {
                if let groupChildren = getChildrenProperty(element) {
                    childElements.append(contentsOf: createChildElements(groupChildren))
                }
            } else {
                // Create child element for non-Group elements
                if let childElement = createChildElement(element) {
                    childElements.append(childElement)
                }
            }
        }
        
        return childElements
    }
    
    /// Create a child element for structure (non-recursive)
    private static func createChildElement(_ element: AXUIElement) -> AXElement? {
        let role = getStringProperty(element, kAXRoleAttribute)
        let description = getStringProperty(element, kAXDescriptionAttribute)
        let identifier = getStringProperty(element, kAXIdentifierAttribute)
        let roleDescription = getStringProperty(element, kAXRoleDescriptionAttribute)
        let help = getStringProperty(element, kAXHelpAttribute)
        let position = getPositionProperty(element)
        let size = getSizeProperty(element)
        let selected = getBoolProperty(element, kAXSelectedAttribute) ?? false
        let enabled = getBoolProperty(element, kAXEnabledAttribute) ?? true
        let focused = getBoolProperty(element, kAXFocusedAttribute) ?? false
        
        // Skip elements without meaningful content
        if role == nil && description == nil && identifier == nil && roleDescription == nil {
            return nil
        }
        
        let normalizedRole = normalizeRole(role)
        
        let bounds: [Int]? = {
            guard let position = position, let size = size else { return nil }
            return [
                safeIntConversion(position.x),
                safeIntConversion(position.y),
                safeIntConversion(size.width),
                safeIntConversion(size.height)
            ]
        }()
        
        return AXElement(
            role: normalizedRole,
            description: description,
            identifier: identifier,
            roleDescription: roleDescription,
            help: help,
            bounds: bounds,
            selected: selected,
            enabled: enabled,
            focused: focused,
            children: nil, // Child elements don't include their own children
            axElementRef: element
        )
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
