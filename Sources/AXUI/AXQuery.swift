import Foundation
import CoreGraphics
import ApplicationServices

// MARK: - AX Query System

/// A flexible query structure for matching UI elements based on multiple conditions
public struct AXQuery {
    // Basic properties
    public var role: String?
    public var description: String?
    public var identifier: String?
    public var roleDescription: String?
    public var help: String?
    
    // State properties
    public var selected: Bool?
    public var enabled: Bool?
    public var focused: Bool?
    
    // Spatial properties
    public var boundsContains: CGPoint?  // Element contains this point
    public var boundsIntersects: CGRect? // Element intersects this rect
    public var minWidth: Int?
    public var minHeight: Int?
    public var maxWidth: Int?
    public var maxHeight: Int?
    
    // Text matching
    public var descriptionContains: String?     // Partial match
    public var descriptionRegex: String?        // Regex pattern
    public var identifierContains: String?
    public var identifierRegex: String?
    
    // Hierarchical context (using boxes to break recursion)
    public var hasChildQuery: Box<AXQuery>?         // At least one child matches
    public var childCount: Int?           // Exact child count
    public var minChildCount: Int?        // Minimum child count
    
    // Logical operators (using boxes to break recursion)
    public var andQueries: [Box<AXQuery>]?            // All conditions must match
    public var orQueries: [Box<AXQuery>]?             // At least one condition must match
    public var negatedQuery: Box<AXQuery>?              // Condition must not match
    
    public init() {}
}

// MARK: - Box for Recursive Types

public final class Box<T> {
    public let value: T
    
    public init(_ value: T) {
        self.value = value
    }
}

// MARK: - Flat Element Representation

/// A flat representation of a UI element with essential children
public struct AXElement: Codable {
    // Core properties
    public let role: String?
    public let description: String?
    public let identifier: String?
    public let roleDescription: String?
    public let help: String?
    public let bounds: [Int]?
    public let state: AXElementState?
    public let children: [AXElement]?
    
    // Internal reference (not serialized)
    internal let axElementRef: AXUIElement?
    
    private enum CodingKeys: String, CodingKey {
        case role, description, identifier, roleDescription, help, bounds, state, children
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(role, forKey: .role)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(identifier, forKey: .identifier)
        try container.encodeIfPresent(roleDescription, forKey: .roleDescription)
        try container.encodeIfPresent(help, forKey: .help)
        try container.encodeIfPresent(bounds, forKey: .bounds)
        try container.encodeIfPresent(state, forKey: .state)
        try container.encodeIfPresent(children, forKey: .children)
        // Internal properties are not encoded
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        role = try container.decodeIfPresent(String.self, forKey: .role)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        identifier = try container.decodeIfPresent(String.self, forKey: .identifier)
        roleDescription = try container.decodeIfPresent(String.self, forKey: .roleDescription)
        help = try container.decodeIfPresent(String.self, forKey: .help)
        bounds = try container.decodeIfPresent([Int].self, forKey: .bounds)
        state = try container.decodeIfPresent(AXElementState.self, forKey: .state)
        children = try container.decodeIfPresent([AXElement].self, forKey: .children)
        axElementRef = nil
    }
    
    public init(
        role: String?,
        description: String?,
        identifier: String?,
        roleDescription: String?,
        help: String?,
        bounds: [Int]?,
        selected: Bool,
        enabled: Bool,
        focused: Bool,
        children: [AXElement]? = nil,
        axElementRef: AXUIElement? = nil
    ) {
        self.role = role
        self.description = description
        self.identifier = identifier
        self.roleDescription = roleDescription
        self.help = help
        self.bounds = bounds
        self.children = children
        
        // Only include non-default state values
        let state = AXElementState.create(
            selected: selected,
            enabled: enabled,
            focused: focused
        )
        self.state = state
        
        self.axElementRef = axElementRef
    }
}

/// Element state for flat representation
public struct AXElementState: Codable {
    public let selected: Bool?
    public let enabled: Bool?
    public let focused: Bool?
    
    /// Create state with only non-default values
    public static func create(selected: Bool, enabled: Bool, focused: Bool) -> AXElementState? {
        // Only include non-default values
        let state = AXElementState(
            selected: selected ? true : nil,
            enabled: !enabled ? false : nil,  // Only include when false (non-default)
            focused: focused ? true : nil
        )
        return state.selected == nil && state.enabled == nil && state.focused == nil ? nil : state
    }
}

// MARK: - Query Builder

extension AXQuery {
    /// Create a query for buttons
    public static func button(description: String? = nil) -> AXQuery {
        var query = AXQuery()
        query.role = "Button"
        query.description = description
        return query
    }
    
    /// Create a query for text fields
    public static func textField(identifier: String? = nil) -> AXQuery {
        var query = AXQuery()
        query.role = "Field"
        query.identifier = identifier
        return query
    }
    
    /// Create a query for interactive elements
    public static func interactive() -> AXQuery {
        var query = AXQuery()
        var buttonQuery = AXQuery()
        buttonQuery.role = "Button"
        var fieldQuery = AXQuery()
        fieldQuery.role = "Field"
        var checkQuery = AXQuery()
        checkQuery.role = "Check"
        var radioQuery = AXQuery()
        radioQuery.role = "Radio"
        var sliderQuery = AXQuery()
        sliderQuery.role = "Slider"
        var popupQuery = AXQuery()
        popupQuery.role = "PopUp"
        var tabQuery = AXQuery()
        tabQuery.role = "Tab"
        var menuQuery = AXQuery()
        menuQuery.role = "MenuItem"
        var linkQuery = AXQuery()
        linkQuery.role = "Link"
        
        query.orQueries = [
            Box(buttonQuery),
            Box(fieldQuery),
            Box(checkQuery),
            Box(radioQuery),
            Box(sliderQuery),
            Box(popupQuery),
            Box(tabQuery),
            Box(menuQuery),
            Box(linkQuery)
        ]
        return query
    }
    
    /// Create a spatial query
    public static func within(rect: CGRect) -> AXQuery {
        var query = AXQuery()
        query.boundsIntersects = rect
        return query
    }
    
    /// Create a query for elements containing text
    public static func containing(text: String) -> AXQuery {
        var query = AXQuery()
        query.descriptionContains = text
        return query
    }
}

// MARK: - Query Parsing

extension AXQuery {
    /// Parse query from command line string format
    /// Format: "key=value,key2=value2" or "key~=regex"
    public static func parse(_ queryString: String) -> AXQuery? {
        var query = AXQuery()
        
        let pairs = queryString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        for pair in pairs {
            if pair.contains("~=") {
                // Regex match
                let parts = pair.split(separator: "~", maxSplits: 1).map { String($0) }
                guard parts.count == 2 else { continue }
                let key = parts[0]
                let value = String(parts[1].dropFirst()) // Remove '='
                
                switch key {
                case "description":
                    query.descriptionRegex = value
                case "identifier":
                    query.identifierRegex = value
                default:
                    break
                }
            } else if pair.contains("*=") {
                // Contains match
                let parts = pair.split(separator: "*", maxSplits: 1).map { String($0) }
                guard parts.count == 2 else { continue }
                let key = parts[0]
                let value = String(parts[1].dropFirst()) // Remove '='
                
                switch key {
                case "description":
                    query.descriptionContains = value
                case "identifier":
                    query.identifierContains = value
                default:
                    break
                }
            } else if pair.contains("=") {
                // Exact match
                let parts = pair.split(separator: "=", maxSplits: 1).map { String($0) }
                guard parts.count == 2 else { continue }
                let key = parts[0]
                let value = parts[1]
                
                switch key {
                case "role":
                    query.role = String(value)
                case "description":
                    query.description = String(value)
                case "identifier":
                    query.identifier = String(value)
                case "selected":
                    query.selected = value == "true"
                case "enabled":
                    query.enabled = value == "true"
                case "focused":
                    query.focused = value == "true"
                case "minWidth":
                    query.minWidth = Int(value)
                case "minHeight":
                    query.minHeight = Int(value)
                default:
                    break
                }
            }
        }
        
        return query
    }
}

