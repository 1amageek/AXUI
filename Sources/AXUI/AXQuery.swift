import Foundation
@preconcurrency import ApplicationServices

// MARK: - Basic Types

public struct Point: Codable, Sendable {
    public let x: Double
    public let y: Double
    
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct Size: Codable, Sendable {
    public let width: Double
    public let height: Double
    
    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

// MARK: - Comparison Query

public struct ComparisonQuery<T: Comparable & Codable & Sendable>: Codable, Sendable {
    public var equals: T?
    public var notEquals: T?
    public var greaterThan: T?
    public var lessThan: T?
    public var greaterThanOrEqual: T?
    public var lessThanOrEqual: T?
    
    public init() {}
    
    public func matches(_ value: T) -> Bool {
        if let eq = equals, value != eq { return false }
        if let neq = notEquals, value == neq { return false }
        if let gt = greaterThan, value <= gt { return false }
        if let lt = lessThan, value >= lt { return false }
        if let gte = greaterThanOrEqual, value < gte { return false }
        if let lte = lessThanOrEqual, value > lte { return false }
        return true
    }
}

// MARK: - AX Query System

/// A flexible query structure for matching UI elements based on multiple conditions
public struct AXQuery: Sendable {
    // Basic properties
    public var role: Role?
    public var description: String?
    public var identifier: String?
    public var roleDescription: String?
    public var help: String?
    
    // State properties
    public var selected: Bool?
    public var enabled: Bool?
    public var focused: Bool?
    
    // Spatial properties
    public var boundsContains: Point?  // Element contains this point
    public var boundsIntersects: [Double]? // Element intersects this rect [x, y, width, height]
    public var x: ComparisonQuery<Double>?
    public var y: ComparisonQuery<Double>?
    public var width: ComparisonQuery<Double>?
    public var height: ComparisonQuery<Double>?
    
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

public final class Box<T: Sendable>: @unchecked Sendable {
    public let value: T
    
    public init(_ value: T) {
        self.value = value
    }
}

// MARK: - Query Builder

extension AXQuery {
    /// Create a query for buttons
    public static func button(description: String? = nil) -> AXQuery {
        var query = AXQuery()
        query.role = .button
        query.description = description
        return query
    }
    
    /// Create a query for text fields
    public static func textField(identifier: String? = nil) -> AXQuery {
        var query = AXQuery()
        query.role = .field
        query.identifier = identifier
        return query
    }
    
    /// Create a query for interactive elements
    public static func interactive() -> AXQuery {
        var query = AXQuery()
        var buttonQuery = AXQuery()
        buttonQuery.role = .button
        var fieldQuery = AXQuery()
        fieldQuery.role = .field
        var checkQuery = AXQuery()
        checkQuery.role = .check
        var radioQuery = AXQuery()
        radioQuery.role = .radio
        var sliderQuery = AXQuery()
        sliderQuery.role = .slider
        var popupQuery = AXQuery()
        popupQuery.role = .popUp
        var tabQuery = AXQuery()
        tabQuery.role = .tabGroup
        var menuQuery = AXQuery()
        menuQuery.role = .menuItem
        var linkQuery = AXQuery()
        linkQuery.role = .link
        
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
    public static func within(rect: [Double]) -> AXQuery {
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
            } else {
                // Handle comparison operators
                let operators = [">=", "<=", "!=", ">", "<", "="]
                var operatorFound: String?
                var keyPart: String?
                var valuePart: String?
                
                for op in operators {
                    if pair.contains(op) {
                        let parts = pair.split(separator: Character(extendedGraphemeClusterLiteral: op.first!), maxSplits: 1).map { String($0) }
                        if parts.count == 2 {
                            keyPart = parts[0]
                            if op.count == 2 {
                                // Handle two-character operators (>=, <=, !=)
                                let remainingPart = parts[1]
                                if remainingPart.hasPrefix(String(op.dropFirst())) {
                                    valuePart = String(remainingPart.dropFirst())
                                    operatorFound = op
                                    break
                                }
                            } else {
                                // Handle single-character operators (>, <, =)
                                valuePart = parts[1]
                                operatorFound = op
                                break
                            }
                        }
                    }
                }
                
                guard let key = keyPart, let value = valuePart, let op = operatorFound else { continue }
                
                switch key {
                case "role":
                    if op == "=" { query.role = Role(rawValue: String(value)) }
                case "description":
                    if op == "=" { query.description = String(value) }
                case "identifier":
                    if op == "=" { query.identifier = String(value) }
                case "selected":
                    if op == "=" { query.selected = value == "true" }
                case "enabled":
                    if op == "=" { query.enabled = value == "true" }
                case "focused":
                    if op == "=" { query.focused = value == "true" }
                case "x":
                    if let doubleValue = Double(value) {
                        var xQuery = query.x ?? ComparisonQuery<Double>()
                        switch op {
                        case "=": xQuery.equals = doubleValue
                        case "!=": xQuery.notEquals = doubleValue
                        case ">=": xQuery.greaterThanOrEqual = doubleValue
                        case "<=": xQuery.lessThanOrEqual = doubleValue
                        case ">": xQuery.greaterThan = doubleValue
                        case "<": xQuery.lessThan = doubleValue
                        default: break
                        }
                        query.x = xQuery
                    }
                case "y":
                    if let doubleValue = Double(value) {
                        var yQuery = query.y ?? ComparisonQuery<Double>()
                        switch op {
                        case "=": yQuery.equals = doubleValue
                        case "!=": yQuery.notEquals = doubleValue
                        case ">=": yQuery.greaterThanOrEqual = doubleValue
                        case "<=": yQuery.lessThanOrEqual = doubleValue
                        case ">": yQuery.greaterThan = doubleValue
                        case "<": yQuery.lessThan = doubleValue
                        default: break
                        }
                        query.y = yQuery
                    }
                case "width":
                    if let doubleValue = Double(value) {
                        var widthQuery = query.width ?? ComparisonQuery<Double>()
                        switch op {
                        case "=": widthQuery.equals = doubleValue
                        case "!=": widthQuery.notEquals = doubleValue
                        case ">=": widthQuery.greaterThanOrEqual = doubleValue
                        case "<=": widthQuery.lessThanOrEqual = doubleValue
                        case ">": widthQuery.greaterThan = doubleValue
                        case "<": widthQuery.lessThan = doubleValue
                        default: break
                        }
                        query.width = widthQuery
                    }
                case "height":
                    if let doubleValue = Double(value) {
                        var heightQuery = query.height ?? ComparisonQuery<Double>()
                        switch op {
                        case "=": heightQuery.equals = doubleValue
                        case "!=": heightQuery.notEquals = doubleValue
                        case ">=": heightQuery.greaterThanOrEqual = doubleValue
                        case "<=": heightQuery.lessThanOrEqual = doubleValue
                        case ">": heightQuery.greaterThan = doubleValue
                        case "<": heightQuery.lessThan = doubleValue
                        default: break
                        }
                        query.height = heightQuery
                    }
                default:
                    break
                }
            }
        }
        
        return query
    }
}

