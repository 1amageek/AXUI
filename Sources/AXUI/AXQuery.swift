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

// MARK: - Role Query (Specialized for enum matching)

public struct RoleQuery: Codable, Sendable {
    public var equals: Role?
    public var notEquals: Role?
    
    public init() {}
    
    public func matches(_ value: Role) -> Bool {
        if let eq = equals, value != eq { return false }
        if let neq = notEquals, value == neq { return false }
        return true
    }
}

// MARK: - AX Query System

/// A flexible query structure for matching UI elements based on multiple conditions
public struct AXQuery: Codable, Sendable {
    // Basic properties
    public var roleQuery: RoleQuery?
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

// MARK: - Codable Support for Box

extension Box: Codable where T: Codable {
    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(T.self)
        self.init(value)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

// MARK: - Query Builder

extension AXQuery {
    /// Create a query for buttons
    public static func button(description: String? = nil) -> AXQuery {
        var query = AXQuery()
        var roleQuery = RoleQuery()
        roleQuery.equals = .button
        query.roleQuery = roleQuery
        query.description = description
        return query
    }
    
    /// Create a query for text fields
    public static func textField(identifier: String? = nil) -> AXQuery {
        var query = AXQuery()
        var roleQuery = RoleQuery()
        roleQuery.equals = .field
        query.roleQuery = roleQuery
        query.identifier = identifier
        return query
    }
    
    /// Create a query for interactive elements
    public static func interactive() -> AXQuery {
        var query = AXQuery()
        
        let roles: [Role] = [.button, .field, .check, .radio, .slider, .popUp, .link]
        var subQueries: [Box<AXQuery>] = []
        
        for role in roles {
            var subQuery = AXQuery()
            var roleQuery = RoleQuery()
            roleQuery.equals = role
            subQuery.roleQuery = roleQuery
            subQueries.append(Box(subQuery))
        }
        
        query.orQueries = subQueries
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

public enum AXQueryParseError: Error, LocalizedError, Sendable, Equatable {
    case emptyQuery
    case invalidCondition(String)
    case unsupportedKey(String)
    case invalidValue(key: String, value: String)
    case invalidRegex(key: String, pattern: String)
    
    public var errorDescription: String? {
        switch self {
        case .emptyQuery:
            return "Query is empty"
        case .invalidCondition(let condition):
            return "Invalid query condition: \(condition)"
        case .unsupportedKey(let key):
            return "Unsupported query key: \(key)"
        case .invalidValue(let key, let value):
            return "Invalid value '\(value)' for key '\(key)'"
        case .invalidRegex(let key, let pattern):
            return "Invalid regex '\(pattern)' for key '\(key)'"
        }
    }
}

extension AXQuery {
    /// Parse query from command line string format
    /// Format: "key=value,key2=value2" or "key~=regex"
    public static func parse(_ queryString: String) -> AXQuery? {
        switch parseResult(queryString) {
        case .success(let query):
            return query
        case .failure:
            return nil
        }
    }
    
    /// Parse query with explicit error reporting.
    public static func parseResult(_ queryString: String) -> Result<AXQuery, AXQueryParseError> {
        var query = AXQuery()
        var subQueries: [Box<AXQuery>] = []
        
        let pairs = splitQueryPairs(queryString)
        if pairs.isEmpty {
            return .failure(.emptyQuery)
        }
        
        for pair in pairs {
            var subQuery = AXQuery()
            
            if pair.contains("~=") {
                // Regex match
                let parts = pair.split(separator: "~", maxSplits: 1).map { String($0) }
                guard parts.count == 2 else {
                    return .failure(.invalidCondition(pair))
                }
                let key = parts[0]
                let value = String(parts[1].dropFirst()) // Remove '='
                
                switch key {
                case "description":
                    do {
                        _ = try NSRegularExpression(pattern: value, options: [])
                    } catch {
                        return .failure(.invalidRegex(key: key, pattern: value))
                    }
                    subQuery.descriptionRegex = value
                case "identifier":
                    do {
                        _ = try NSRegularExpression(pattern: value, options: [])
                    } catch {
                        return .failure(.invalidRegex(key: key, pattern: value))
                    }
                    subQuery.identifierRegex = value
                default:
                    return .failure(.unsupportedKey(key))
                }
            } else if pair.contains("*=") {
                // Contains match
                let parts = pair.split(separator: "*", maxSplits: 1).map { String($0) }
                guard parts.count == 2 else {
                    return .failure(.invalidCondition(pair))
                }
                let key = parts[0]
                let value = String(parts[1].dropFirst()) // Remove '='
                
                switch key {
                case "description":
                    subQuery.descriptionContains = value
                case "identifier":
                    subQuery.identifierContains = value
                default:
                    return .failure(.unsupportedKey(key))
                }
            } else {
                // Handle comparison operators
                let operators = [">=", "<=", "!=", ">", "<", "="]
                var operatorFound: String?
                var keyPart: String?
                var valuePart: String?
                
                for op in operators {
                    if let range = pair.range(of: op) {
                        keyPart = String(pair[..<range.lowerBound])
                        valuePart = String(pair[range.upperBound...])
                        operatorFound = op
                        break
                    }
                }
                
                guard let key = keyPart, let value = valuePart, let op = operatorFound else {
                    return .failure(.invalidCondition(pair))
                }
                
                switch key {
                case "role":
                    if let role = Role(rawValue: String(value)) {
                        var roleQuery = RoleQuery()
                        switch op {
                        case "=": roleQuery.equals = role
                        case "!=": roleQuery.notEquals = role
                        default: return .failure(.invalidCondition(pair))
                        }
                        subQuery.roleQuery = roleQuery
                    } else {
                        return .failure(.invalidValue(key: key, value: value))
                    }
                case "description":
                    if op == "=" { subQuery.description = String(value) }
                    else { return .failure(.invalidCondition(pair)) }
                case "identifier":
                    if op == "=" { subQuery.identifier = String(value) }
                    else { return .failure(.invalidCondition(pair)) }
                case "selected":
                    if op == "=" {
                        switch value.lowercased() {
                        case "true":
                            subQuery.selected = true
                        case "false":
                            subQuery.selected = false
                        default:
                            return .failure(.invalidValue(key: key, value: value))
                        }
                    } else {
                        return .failure(.invalidCondition(pair))
                    }
                case "enabled":
                    if op == "=" {
                        switch value.lowercased() {
                        case "true":
                            subQuery.enabled = true
                        case "false":
                            subQuery.enabled = false
                        default:
                            return .failure(.invalidValue(key: key, value: value))
                        }
                    } else {
                        return .failure(.invalidCondition(pair))
                    }
                case "focused":
                    if op == "=" {
                        switch value.lowercased() {
                        case "true":
                            subQuery.focused = true
                        case "false":
                            subQuery.focused = false
                        default:
                            return .failure(.invalidValue(key: key, value: value))
                        }
                    } else {
                        return .failure(.invalidCondition(pair))
                    }
                case "x":
                    if let doubleValue = Double(value) {
                        var xQuery = ComparisonQuery<Double>()
                        switch op {
                        case "=": xQuery.equals = doubleValue
                        case "!=": xQuery.notEquals = doubleValue
                        case ">=": xQuery.greaterThanOrEqual = doubleValue
                        case "<=": xQuery.lessThanOrEqual = doubleValue
                        case ">": xQuery.greaterThan = doubleValue
                        case "<": xQuery.lessThan = doubleValue
                        default: return .failure(.invalidCondition(pair))
                        }
                        subQuery.x = xQuery
                    } else {
                        return .failure(.invalidValue(key: key, value: value))
                    }
                case "y":
                    if let doubleValue = Double(value) {
                        var yQuery = ComparisonQuery<Double>()
                        switch op {
                        case "=": yQuery.equals = doubleValue
                        case "!=": yQuery.notEquals = doubleValue
                        case ">=": yQuery.greaterThanOrEqual = doubleValue
                        case "<=": yQuery.lessThanOrEqual = doubleValue
                        case ">": yQuery.greaterThan = doubleValue
                        case "<": yQuery.lessThan = doubleValue
                        default: return .failure(.invalidCondition(pair))
                        }
                        subQuery.y = yQuery
                    } else {
                        return .failure(.invalidValue(key: key, value: value))
                    }
                case "width":
                    if let doubleValue = Double(value) {
                        var widthQuery = ComparisonQuery<Double>()
                        switch op {
                        case "=": widthQuery.equals = doubleValue
                        case "!=": widthQuery.notEquals = doubleValue
                        case ">=": widthQuery.greaterThanOrEqual = doubleValue
                        case "<=": widthQuery.lessThanOrEqual = doubleValue
                        case ">": widthQuery.greaterThan = doubleValue
                        case "<": widthQuery.lessThan = doubleValue
                        default: return .failure(.invalidCondition(pair))
                        }
                        subQuery.width = widthQuery
                    } else {
                        return .failure(.invalidValue(key: key, value: value))
                    }
                case "height":
                    if let doubleValue = Double(value) {
                        var heightQuery = ComparisonQuery<Double>()
                        switch op {
                        case "=": heightQuery.equals = doubleValue
                        case "!=": heightQuery.notEquals = doubleValue
                        case ">=": heightQuery.greaterThanOrEqual = doubleValue
                        case "<=": heightQuery.lessThanOrEqual = doubleValue
                        case ">": heightQuery.greaterThan = doubleValue
                        case "<": heightQuery.lessThan = doubleValue
                        default: return .failure(.invalidCondition(pair))
                        }
                        subQuery.height = heightQuery
                    } else {
                        return .failure(.invalidValue(key: key, value: value))
                    }
                default:
                    return .failure(.unsupportedKey(key))
                }
            }
            
            subQueries.append(Box(subQuery))
        }
        
        if subQueries.count == 1 {
            return .success(subQueries[0].value)
        } else if subQueries.count > 1 {
            query.andQueries = subQueries
            return .success(query)
        }

        return .failure(.emptyQuery)
    }

    /// Split query string by unescaped commas. `\,` is treated as a literal comma.
    private static func splitQueryPairs(_ queryString: String) -> [String] {
        var pairs: [String] = []
        var current = ""
        var escaped = false

        for char in queryString {
            if escaped {
                if char == "," {
                    current.append(",")
                } else {
                    current.append("\\")
                    current.append(char)
                }
                escaped = false
            } else if char == "\\" {
                escaped = true
            } else if char == "," {
                pairs.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(char)
            }
        }

        if escaped {
            current.append("\\")
        }

        let trimmed = current.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            pairs.append(trimmed)
        }

        return pairs
    }
}
