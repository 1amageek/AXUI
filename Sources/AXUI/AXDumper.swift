import Foundation
import ApplicationServices
import AppKit
import Compression

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
            role: normalizedRole,
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
}

// MARK: - JSON Conversion Extensions

extension AXDumper {
    /// Convert AX dump to minified JSON
    public static func convert(axDump: String) throws -> String {
        let properties = try AXParser.parse(content: axDump)
        let uiNode = properties.toUINode()
        return try uiNode.toMinifiedJSON()
    }
    
    /// Convert AX dump to pretty JSON
    public static func convertToPrettyJSON(axDump: String) throws -> String {
        let properties = try AXParser.parse(content: axDump)
        let uiNode = properties.toUINode()
        return try uiNode.toPrettyJSON()
    }
    
    /// Convert AX dump to compressed JSON data
    public static func convertToCompressed(axDump: String) throws -> Data {
        let properties = try AXParser.parse(content: axDump)
        let uiNode = properties.toUINode()
        return try uiNode.toCompressedJSON()
    }
}

// MARK: - AX Properties and UI Node Types

/// Properties extracted from AX dump
public struct AXProperties {
    public let role: String?
    public let value: String?
    public let identifier: String?
    public let roleDescription: String?
    public let help: String?
    public let position: Point?
    public let size: Size?
    public let selected: Bool
    public let enabled: Bool
    public let focused: Bool
    public let children: [AXProperties]
    
    public init(
        role: String? = nil,
        value: String? = nil,
        identifier: String? = nil,
        roleDescription: String? = nil,
        help: String? = nil,
        position: Point? = nil,
        size: Size? = nil,
        selected: Bool = false,
        enabled: Bool = true,
        focused: Bool = false,
        children: [AXProperties] = []
    ) {
        self.role = role
        self.value = value
        self.identifier = identifier
        self.roleDescription = roleDescription
        self.help = help
        self.position = position
        self.size = size
        self.selected = selected
        self.enabled = enabled
        self.focused = focused
        self.children = children
    }
}

/// UI Node representation (from JSON specification)
public enum UINode: Codable {
    case normal(UINodeObject)
    case group([UINode])
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let array = try? container.decode([UINode].self) {
            self = .group(array)
        } else {
            let obj = try container.decode(UINodeObject.self)
            self = .normal(obj)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .normal(let obj):
            try container.encode(obj)
        case .group(let children):
            try container.encode(children)
        }
    }
}

/// UI Node Object
public struct UINodeObject: Codable {
    public let role: String?
    public let value: String?
    public let bounds: [Int]?
    public let state: UINodeState?
    public let children: [UINode]?
    
    private enum CodingKeys: String, CodingKey {
        case role, value, bounds, state, children
    }
    
    public init(
        role: String? = nil,
        value: String? = nil,
        bounds: [Int]? = nil,
        state: UINodeState? = nil,
        children: [UINode]? = nil
    ) {
        self.role = role
        self.value = value
        self.bounds = bounds
        self.state = state
        self.children = children?.isEmpty == true ? nil : children
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(role, forKey: .role)
        try container.encodeIfPresent(value, forKey: .value)
        try container.encodeIfPresent(bounds, forKey: .bounds)
        try container.encodeIfPresent(state, forKey: .state)
        try container.encodeIfPresent(children, forKey: .children)
    }
}

/// UI Node State
public struct UINodeState: Codable, Equatable {
    public let selected: Bool?
    public let enabled: Bool?
    public let focused: Bool?
    
    public init(selected: Bool?, enabled: Bool?, focused: Bool?) {
        self.selected = selected
        self.enabled = enabled
        self.focused = focused
    }
    
    /// Create state with only non-default values
    public static func create(
        selected: Bool = false,
        enabled: Bool = true,
        focused: Bool = false
    ) -> UINodeState? {
        let state = UINodeState(
            selected: selected ? true : nil,
            enabled: !enabled ? false : nil,
            focused: focused ? true : nil
        )
        return state.selected == nil && state.enabled == nil && state.focused == nil ? nil : state
    }
    
    /// Check if state has default values
    public var isDefault: Bool {
        return (selected == nil || selected == false) && 
               (enabled == nil || enabled == true) && 
               (focused == nil || focused == false)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(selected, forKey: .selected)
        try container.encodeIfPresent(enabled, forKey: .enabled)
        try container.encodeIfPresent(focused, forKey: .focused)
    }
    
    private enum CodingKeys: String, CodingKey {
        case selected, enabled, focused
    }
}

// MARK: - AX Parser

public struct AXParser {
    /// Parse AX dump content into properties
    public static func parse(content: String) throws -> AXProperties {
        let lines = content.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        
        guard !lines.isEmpty else {
            throw AXParseError.emptyInput
        }
        
        return try parse(lines: lines)
    }
    
    /// Parse lines into properties
    public static func parse(lines: [String]) throws -> AXProperties {
        guard !lines.isEmpty else {
            throw AXParseError.emptyInput
        }
        
        var index = 0
        return try parseNode(lines: lines, index: &index, depth: 0)
    }
    
    private static func parseNode(lines: [String], index: inout Int, depth: Int) throws -> AXProperties {
        var role: String?
        var value: String?
        var identifier: String?
        var roleDescription: String?
        var help: String?
        var position: Point?
        var size: Size?
        var selected = false
        var enabled = true
        var focused = false
        var children: [AXProperties] = []
        
        while index < lines.count {
            let line = lines[index]
            let currentDepth = getDepth(line)
            
            if currentDepth < depth {
                break
            }
            
            if currentDepth > depth {
                index -= 1
                break
            }
            
            if line.contains("Child[") {
                index += 1
                let child = try parseNode(lines: lines, index: &index, depth: currentDepth + 1)
                children.append(child)
                continue
            }
            
            let content = line.trimmingCharacters(in: .whitespaces)
            
            if let colonIndex = content.firstIndex(of: ":") {
                let key = String(content[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                let valueStr = String(content[content.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                
                switch key {
                case "Role":
                    role = valueStr
                case "Value":
                    value = valueStr
                case "Identifier":
                    identifier = valueStr
                case "RoleDescription":
                    roleDescription = valueStr
                case "Help":
                    help = valueStr
                case "Position":
                    position = parsePosition(valueStr)
                case "Size":
                    size = parseSize(valueStr)
                case "Selected":
                    selected = valueStr.lowercased() == "true"
                case "Enabled":
                    enabled = valueStr.lowercased() == "true"
                case "Focused":
                    focused = valueStr.lowercased() == "true"
                default:
                    break
                }
            }
            
            index += 1
        }
        
        return AXProperties(
            role: role,
            value: value,
            identifier: identifier,
            roleDescription: roleDescription,
            help: help,
            position: position,
            size: size,
            selected: selected,
            enabled: enabled,
            focused: focused,
            children: children
        )
    }
    
    private static func getDepth(_ line: String) -> Int {
        return line.prefix { $0 == " " }.count / 2
    }
    
    private static func parsePosition(_ valueStr: String) -> Point? {
        let cleaned = valueStr.trimmingCharacters(in: CharacterSet(charactersIn: "()"))
        let components = cleaned.components(separatedBy: ",")
        guard components.count == 2,
              let x = Double(components[0].trimmingCharacters(in: .whitespaces)),
              let y = Double(components[1].trimmingCharacters(in: .whitespaces)) else {
            return nil
        }
        return Point(x: x, y: y)
    }
    
    private static func parseSize(_ valueStr: String) -> Size? {
        let cleaned = valueStr.trimmingCharacters(in: CharacterSet(charactersIn: "()"))
        let components = cleaned.components(separatedBy: ",")
        guard components.count == 2,
              let width = Double(components[0].trimmingCharacters(in: .whitespaces)),
              let height = Double(components[1].trimmingCharacters(in: .whitespaces)) else {
            return nil
        }
        return Size(width: width, height: height)
    }
}

// MARK: - Parse Errors

public enum AXParseError: Error, LocalizedError, Equatable {
    case emptyInput
    case invalidFormat(String)
    
    public var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "Empty input provided to parser"
        case .invalidFormat(let details):
            return "Invalid format: \(details)"
        }
    }
}

// MARK: - Conversion Extensions

extension AXProperties {
    /// Convert to UI Node representation
    public func toUINode() -> UINode {
        let normalizedRole = normalizeRole(role)
        
        // Group optimization logic
        if normalizedRole == "Group" {
            let childNodes = children.map { $0.toUINode() }
            
            // G-Minimal: Array representation if only role and children
            if hasOnlyRoleAndChildren() {
                return .group(childNodes)
            }
            
            // G-Object: Object representation with role omitted
            let bounds = createBounds()
            let state = UINodeState.create(selected: selected, enabled: enabled, focused: focused)
            
            return .normal(UINodeObject(
                role: nil, // Group role omitted
                value: value,
                bounds: bounds,
                state: state,
                children: childNodes.isEmpty ? nil : childNodes
            ))
        }
        
        // Normal node
        let bounds = createBounds()
        let state = UINodeState.create(selected: selected, enabled: enabled, focused: focused)
        let childNodes = children.map { $0.toUINode() }
        
        return .normal(UINodeObject(
            role: normalizedRole,
            value: value,
            bounds: bounds,
            state: state,
            children: childNodes.isEmpty ? nil : childNodes
        ))
    }
    
    private func normalizeRole(_ role: String?) -> String? {
        guard let role = role else { return nil }
        return role.hasPrefix("AX") ? String(role.dropFirst(2)) : role
    }
    
    private func hasOnlyRoleAndChildren() -> Bool {
        return value == nil &&
               identifier == nil &&
               roleDescription == nil &&
               help == nil &&
               position == nil &&
               size == nil &&
               selected == false &&
               enabled == true &&
               focused == false
    }
    
    private func createBounds() -> [Int]? {
        guard let position = position, let size = size else { return nil }
        return [
            Int(position.x),
            Int(position.y),
            Int(size.width),
            Int(size.height)
        ]
    }
}

// MARK: - JSON Extensions

extension UINode {
    /// Convert to minified JSON
    public func toMinifiedJSON() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = []
        let data = try encoder.encode(self)
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    /// Convert to pretty JSON
    public func toPrettyJSON() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    /// Convert to compressed JSON data
    public func toCompressedJSON() throws -> Data {
        let jsonData = try JSONEncoder().encode(self)
        return try jsonData.compressed(using: .lzfse)
    }
    
    /// Create from JSON string
    public static func fromJSON(_ jsonString: String) throws -> UINode {
        guard let data = jsonString.data(using: .utf8) else {
            throw AXParseError.invalidFormat("Invalid UTF-8 string")
        }
        return try JSONDecoder().decode(UINode.self, from: data)
    }
    
    /// Create from compressed JSON data
    public static func fromCompressedJSON(_ data: Data) throws -> UINode {
        let decompressed = try data.decompressed(using: .lzfse)
        return try JSONDecoder().decode(UINode.self, from: decompressed)
    }
}

// MARK: - Data Compression Extensions

extension Data {
    func compressed(using algorithm: NSData.CompressionAlgorithm) throws -> Data {
        return try (self as NSData).compressed(using: algorithm) as Data
    }
    
    func decompressed(using algorithm: NSData.CompressionAlgorithm) throws -> Data {
        return try (self as NSData).decompressed(using: algorithm) as Data
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
