import Foundation
import ApplicationServices
import AppKit
import Compression

// MARK: - AX Dumper

public struct AXDumper {
    
    // MARK: - Cache Management
    
    private static let cacheQueue = DispatchQueue(label: "com.axui.cache", attributes: .concurrent)
    private nonisolated(unsafe) static var _elementCache: [String: [AXElement]] = [:]
    
    private static var elementCache: [String: [AXElement]] {
        get {
            return cacheQueue.sync { _elementCache }
        }
        set {
            cacheQueue.async(flags: .barrier) { _elementCache = newValue }
        }
    }
    
    /// Clear cache for all applications
    public static func clearCache() {
        cacheQueue.async(flags: .barrier) {
            _elementCache.removeAll()
        }
    }
    
    /// Clear cache for specific application
    public static func clearCache(for bundleIdentifier: String) {
        cacheQueue.async(flags: .barrier) {
            _elementCache.removeValue(forKey: bundleIdentifier)
        }
    }
    
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
    
    // MARK: - Property Getters
    
    private static func safeIntConversion(_ value: Double) -> Int {
        if value.isNaN || value.isInfinite {
            return 0
        }
        return Int(value)
    }
    
    private static func safeDoubleConversion(_ value: Double) -> Double {
        if value.isNaN || value.isInfinite {
            return 0.0
        }
        return value
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
    public static func dump(bundleIdentifier: String, query: AXQuery? = nil, includeZeroSize: Bool = false, maxElements: Int = 5000) throws -> [AXElement] {
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
        var elementCount = 0
        
        // Build flat array of elements with filtering during traversal
        try flattenElementWithFilter(appElement, elements: &elements, elementCount: &elementCount, maxElements: maxElements, query: query, includeZeroSize: includeZeroSize)
        
        // Cache the full element list (only if no query filter was applied)
        if query == nil {
            let elementsToCache = elements
            cacheQueue.async(flags: .barrier) {
                _elementCache[bundleIdentifier] = elementsToCache
            }
        }
        
        return elements
    }
    
    /// Dump AX elements for a specific window as a flat array
    public static func dumpWindow(bundleIdentifier: String, windowIndex: Int, query: AXQuery? = nil, includeZeroSize: Bool = false, maxElements: Int = 5000) throws -> [AXElement] {
        let windows = try listWindows(bundleIdentifier: bundleIdentifier)
        
        guard windowIndex >= 0 && windowIndex < windows.count else {
            throw AXDumperError.windowNotFound(windowIndex, windows.count)
        }
        
        let window = windows[windowIndex]
        
        var elements: [AXElement] = []
        var elementCount = 0
        
        // Build flat array of elements starting from window with filtering during traversal
        try flattenElementWithFilter(window.element, elements: &elements, elementCount: &elementCount, maxElements: maxElements, query: query, includeZeroSize: includeZeroSize)
        
        return elements
    }
    
    /// Query elements with a specific query
    public static func queryElements(bundleIdentifier: String, query: AXQuery, maxElements: Int = 5000) throws -> [AXElement] {
        return try dump(bundleIdentifier: bundleIdentifier, query: query, maxElements: maxElements)
    }
    
    /// Query elements in a specific window
    public static func queryWindowElements(bundleIdentifier: String, windowIndex: Int, query: AXQuery, maxElements: Int = 5000) throws -> [AXElement] {
        return try dumpWindow(bundleIdentifier: bundleIdentifier, windowIndex: windowIndex, query: query, maxElements: maxElements)
    }
    
    /// Get element by its generated ID using cache when available
    public static func element(id: String, bundleIdentifier: String, maxElements: Int = 5000) throws -> AXElement? {
        // First try to find in cache
        let cachedElement = cacheQueue.sync {
            _elementCache[bundleIdentifier]?.first { $0.id == id }
        }
        
        if let element = cachedElement {
            return element
        }
        
        // If not in cache, perform full dump (which will update cache)
        let elements = try dump(bundleIdentifier: bundleIdentifier, maxElements: maxElements)
        return elements.first { $0.id == id }
    }
    
    /// Debug dump with absolutely no filtering - includes all elements including Groups and zero-size elements
    public static func debugDump(bundleIdentifier: String, maxElements: Int = 50000) throws -> [AXElement] {
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
        var elementCount = 0
        
        // Build flat array of elements with NO filtering whatsoever
        try flattenElementDebug(appElement, elements: &elements, elementCount: &elementCount, maxElements: maxElements)
        
        return elements
    }
    
    /// Debug dump for a specific window with no filtering
    public static func debugDumpWindow(bundleIdentifier: String, windowIndex: Int, maxElements: Int = 50000) throws -> [AXElement] {
        let windows = try listWindows(bundleIdentifier: bundleIdentifier)
        
        guard windowIndex >= 0 && windowIndex < windows.count else {
            throw AXDumperError.windowNotFound(windowIndex, windows.count)
        }
        
        let window = windows[windowIndex]
        
        var elements: [AXElement] = []
        var elementCount = 0
        
        // Build flat array of elements starting from window with NO filtering
        try flattenElementDebug(window.element, elements: &elements, elementCount: &elementCount, maxElements: maxElements)
        
        return elements
    }
    
    // MARK: - Private Flattening Implementation
    
    private static func flattenElement(
        _ element: AXUIElement,
        elements: inout [AXElement],
        elementCount: inout Int,
        maxElements: Int,
        includeZeroSize: Bool = false
    ) throws {
        
        // Get size first to check if we should skip this element
        let size = getSizeProperty(element)
        
        // Default behavior: exclude zero-size elements unless explicitly requested
        if !includeZeroSize {
            if let size = size, (size.width == 0 || size.height == 0) {
                // Skip this element but still process its children
                if let children = getChildrenProperty(element) {
                    for child in children {
                        try flattenElement(child, elements: &elements, elementCount: &elementCount, maxElements: maxElements, includeZeroSize: includeZeroSize)
                    }
                }
                return
            }
        }
        
        // Get element properties
        let role = getStringProperty(element, kAXRoleAttribute)
        let description = getStringProperty(element, kAXDescriptionAttribute)
        let identifier = getStringProperty(element, kAXIdentifierAttribute)
        let roleDescription = getStringProperty(element, kAXRoleDescriptionAttribute)
        let help = getStringProperty(element, kAXHelpAttribute)
        let position = getPositionProperty(element)
        // Size already obtained above for zero-size check
        let selected = getBoolProperty(element, kAXSelectedAttribute) ?? false
        let enabled = getBoolProperty(element, kAXEnabledAttribute) ?? true
        let focused = getBoolProperty(element, kAXFocusedAttribute) ?? false
        
        // Convert position and size to safe values
        let safePosition: Point? = {
            guard let position = position else { return nil }
            return Point(
                x: safeDoubleConversion(position.x),
                y: safeDoubleConversion(position.y)
            )
        }()
        
        let safeSize: Size? = {
            guard let size = size else { return nil }
            return Size(
                width: safeDoubleConversion(size.width),
                height: safeDoubleConversion(size.height)
            )
        }()
        
        // Skip elements without meaningful content (no role, description, identifier, or roleDescription)
        if role == nil && description == nil && identifier == nil && roleDescription == nil {
            return
        }
        
        // Check element count limit before processing
        elementCount += 1
        if elementCount > maxElements {
            throw AXDumperError.tooManyElements(elementCount, maxElements)
        }
        
        // Get children for processing
        let children = getChildrenProperty(element) ?? []
        
        // Normalize role (remove AX prefix)
        let normalizedRole = normalizeRole(role)
        
        // Skip Group elements as they have no meaning in this program
        if normalizedRole == .group {
            // Process children but don't include the Group itself
            for child in children {
                try flattenElement(child, elements: &elements, elementCount: &elementCount, maxElements: maxElements, includeZeroSize: includeZeroSize)
            }
            return
        }
        
        // Determine if this element should include children structure
        let shouldIncludeChildren = normalizedRole?.isInteractive ?? false
        let childElements: [AXElement] = shouldIncludeChildren ? createChildElements(children) : []
        
        // Create element with children if applicable
        let axElement = AXElement(
            systemRole: normalizedRole ?? .unknown,
            description: description,
            identifier: identifier,
            roleDescription: roleDescription,
            help: help,
            position: safePosition,
            size: safeSize,
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
            try flattenElement(child, elements: &elements, elementCount: &elementCount, maxElements: maxElements, includeZeroSize: includeZeroSize)
        }
    }
    
    internal static func normalizeRole(_ role: String?) -> SystemRole? {
        guard let role = role else { return nil }
        
        let cleanRole = role.hasPrefix("AX") ? String(role.dropFirst(2)) : role
        
        // Convert to SystemRole
        return SystemRole(rawValue: cleanRole)
    }
    
    
    /// Create child elements for structure, flattening Groups
    private static func createChildElements(_ elements: [AXUIElement]) -> [AXElement] {
        var childElements: [AXElement] = []
        
        for element in elements {
            let role = getStringProperty(element, kAXRoleAttribute)
            let normalizedRole = normalizeRole(role)
            
            // If it's a Group, get its children instead of the Group itself
            if normalizedRole == .group {
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
        
        let safePosition: Point? = {
            guard let position = position else { return nil }
            return Point(
                x: safeDoubleConversion(position.x),
                y: safeDoubleConversion(position.y)
            )
        }()
        
        let safeSize: Size? = {
            guard let size = size else { return nil }
            return Size(
                width: safeDoubleConversion(size.width),
                height: safeDoubleConversion(size.height)
            )
        }()
        
        return AXElement(
            systemRole: normalizedRole ?? .unknown,
            description: description,
            identifier: identifier,
            roleDescription: roleDescription,
            help: help,
            position: safePosition,
            size: safeSize,
            selected: selected,
            enabled: enabled,
            focused: focused,
            children: nil, // Child elements don't include their own children
            axElementRef: element
        )
    }
    
    /// Flatten elements with filtering during traversal for better performance
    private static func flattenElementWithFilter(
        _ element: AXUIElement,
        elements: inout [AXElement],
        elementCount: inout Int,
        maxElements: Int,
        query: AXQuery?,
        includeZeroSize: Bool = false
    ) throws {
        
        // Get size first to check if we should skip this element
        let size = getSizeProperty(element)
        
        // Default behavior: exclude zero-size elements unless explicitly requested
        if !includeZeroSize {
            if let size = size, (size.width == 0 || size.height == 0) {
                // Skip this element but still process its children
                if let children = getChildrenProperty(element) {
                    for child in children {
                        try flattenElementWithFilter(child, elements: &elements, elementCount: &elementCount, maxElements: maxElements, query: query, includeZeroSize: includeZeroSize)
                        // Stop if we've reached the limit
                        if elements.count >= maxElements { 
                            throw AXDumperError.tooManyElements(elements.count, maxElements)
                        }
                    }
                }
                return
            }
        }
        
        // Get element properties
        let role = getStringProperty(element, kAXRoleAttribute)
        let description = getStringProperty(element, kAXDescriptionAttribute)
        let identifier = getStringProperty(element, kAXIdentifierAttribute)
        let roleDescription = getStringProperty(element, kAXRoleDescriptionAttribute)
        let help = getStringProperty(element, kAXHelpAttribute)
        let position = getPositionProperty(element)
        // Size already obtained above for zero-size check
        let selected = getBoolProperty(element, kAXSelectedAttribute) ?? false
        let enabled = getBoolProperty(element, kAXEnabledAttribute) ?? true
        let focused = getBoolProperty(element, kAXFocusedAttribute) ?? false
        
        // Convert position and size to safe values
        let safePosition: Point? = {
            guard let position = position else { return nil }
            return Point(
                x: safeDoubleConversion(position.x),
                y: safeDoubleConversion(position.y)
            )
        }()
        
        let safeSize: Size? = {
            guard let size = size else { return nil }
            return Size(
                width: safeDoubleConversion(size.width),
                height: safeDoubleConversion(size.height)
            )
        }()
        
        // Skip elements without meaningful content (no role, description, identifier, or roleDescription)
        if role == nil && description == nil && identifier == nil && roleDescription == nil {
            // Still process children
            if let children = getChildrenProperty(element) {
                for child in children {
                    try flattenElementWithFilter(child, elements: &elements, elementCount: &elementCount, maxElements: maxElements, query: query, includeZeroSize: includeZeroSize)
                    // Stop if we've reached the limit
                    if elements.count >= maxElements { 
                        throw AXDumperError.tooManyElements(elements.count, maxElements)
                    }
                }
            }
            return
        }
        
        // Get children for processing
        let children = getChildrenProperty(element) ?? []
        
        // Normalize role (remove AX prefix)
        let normalizedRole = normalizeRole(role)
        
        // Skip Group elements as they have no meaning in this program
        if normalizedRole == .group {
            // Process children but don't include the Group itself
            for child in children {
                try flattenElementWithFilter(child, elements: &elements, elementCount: &elementCount, maxElements: maxElements, query: query, includeZeroSize: includeZeroSize)
                // Stop if we've reached the limit
                if elements.count >= maxElements { 
                    throw AXDumperError.tooManyElements(elements.count, maxElements)
                }
            }
            return
        }
        
        // Determine if this element should include children structure
        let shouldIncludeChildren = normalizedRole?.isInteractive ?? false
        let childElements: [AXElement] = shouldIncludeChildren ? createChildElements(children) : []
        
        // Create element with children if applicable
        let axElement = AXElement(
            systemRole: normalizedRole ?? .unknown,
            description: description,
            identifier: identifier,
            roleDescription: roleDescription,
            help: help,
            position: safePosition,
            size: safeSize,
            selected: selected,
            enabled: enabled,
            focused: focused,
            children: childElements.isEmpty ? nil : childElements,
            axElementRef: element
        )
        
        // Apply query filter if provided
        let shouldInclude = if let query = query {
            AXQueryMatcher.matches(element: axElement, query: query, allElements: elements)
        } else {
            true
        }
        
        // Add to array if it matches the query
        if shouldInclude {
            elements.append(axElement)
            // Stop if we've reached the limit
            if elements.count >= maxElements { 
                throw AXDumperError.tooManyElements(elements.count, maxElements)
            }
        }
        
        // Process children for flattening (separate from structure children)
        for child in children {
            try flattenElementWithFilter(child, elements: &elements, elementCount: &elementCount, maxElements: maxElements, query: query, includeZeroSize: includeZeroSize)
            // Stop if we've reached the limit
            if elements.count >= maxElements { 
                throw AXDumperError.tooManyElements(elements.count, maxElements)
            }
        }
    }
    
    /// Debug version of flatten element with NO filtering whatsoever
    private static func flattenElementDebug(
        _ element: AXUIElement,
        elements: inout [AXElement],
        elementCount: inout Int,
        maxElements: Int
    ) throws {
        
        // Check element count limit before processing
        elementCount += 1
        if elementCount > maxElements {
            throw AXDumperError.tooManyElements(elementCount, maxElements)
        }
        
        // Get ALL element properties without any filtering
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
        
        // Convert position and size to safe values
        let safePosition: Point? = {
            guard let position = position else { return nil }
            return Point(
                x: safeDoubleConversion(position.x),
                y: safeDoubleConversion(position.y)
            )
        }()
        
        let safeSize: Size? = {
            guard let size = size else { return nil }
            return Size(
                width: safeDoubleConversion(size.width),
                height: safeDoubleConversion(size.height)
            )
        }()
        
        // Get children for processing
        let children = getChildrenProperty(element) ?? []
        
        // Normalize role (remove AX prefix)
        let normalizedRole = normalizeRole(role)
        
        // Skip Group elements but process their children
        if normalizedRole == .group {
            // Process children but don't include the Group itself
            for child in children {
                try flattenElementDebug(child, elements: &elements, elementCount: &elementCount, maxElements: maxElements)
                // Stop if we've reached the limit
                if elements.count >= maxElements { 
                    throw AXDumperError.tooManyElements(elements.count, maxElements)
                }
            }
            return
        }
        
        // Create element - INCLUDE ALL ELEMENTS except Groups, including zero-size
        let axElement = AXElement(
            systemRole: normalizedRole ?? .unknown,
            description: description,
            identifier: identifier,
            roleDescription: roleDescription,
            help: help,
            position: safePosition,
            size: safeSize,
            selected: selected,
            enabled: enabled,
            focused: focused,
            children: nil, // Keep it flat for debug dump
            axElementRef: element
        )
        
        // Add ALL elements to array (no filtering)
        elements.append(axElement)
        
        // Stop if we've reached the limit
        if elements.count >= maxElements { 
            throw AXDumperError.tooManyElements(elements.count, maxElements)
        }
        
        // Process ALL children recursively
        for child in children {
            try flattenElementDebug(child, elements: &elements, elementCount: &elementCount, maxElements: maxElements)
            // Stop if we've reached the limit
            if elements.count >= maxElements { 
                throw AXDumperError.tooManyElements(elements.count, maxElements)
            }
        }
    }
}

// MARK: - AX Dumper Errors

public enum AXDumperError: Error, LocalizedError, Equatable {
    case applicationNotFound(String)
    case noFrontmostApp
    case noBundleIdentifier
    case accessibilityPermissionDenied
    case windowNotFound(Int, Int)
    case tooManyElements(Int, Int)
    
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
        case .tooManyElements(let found, let limit):
            return "Too many UI elements (\(found) exceeds limit of \(limit)). Use AXQuery to filter elements and retrieve only what you need to avoid excessive token consumption."
        }
    }
}
