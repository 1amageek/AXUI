import Foundation

/// AI-optimized representation of an accessibility element
public struct AIElement: Codable {
    /// Unique 4-character identifier
    public let id: String
    
    /// Element type without "AX" prefix (e.g., "Button", "StaticText", "Window")
    public let role: String?
    
    /// Display text content (mapped from description)
    public let value: String?
    
    /// Element identifier (accessibility identifier)
    public let identifier: String?
    
    /// Role description (mapped from roleDescription)
    public let desc: String?
    
    /// Bounds as [x, y, width, height] integers
    public let bounds: [Int]?
    
    /// Element state (omitted if all values are default)
    public let state: AIElementState?
    
    /// Child elements
    public let children: [Node]?
    
    /// Initialize AIElement
    public init(
        id: String,
        role: String? = nil,
        value: String? = nil,
        identifier: String? = nil,
        desc: String? = nil,
        bounds: [Int]? = nil,
        state: AIElementState? = nil,
        children: [Node]? = nil
    ) {
        self.id = id
        self.role = role
        self.value = value
        self.identifier = identifier
        self.desc = desc
        self.bounds = bounds
        self.state = state
        self.children = children
    }
    
    /// Node representation for Group optimization
    public enum Node: Codable {
        case normal(AIElement)
        case group([Node])
        
        public init(from decoder: Decoder) throws {
            if let array = try? [Node](from: decoder) {
                self = .group(array)
            } else {
                self = .normal(try AIElement(from: decoder))
            }
        }
        
        public func encode(to encoder: Encoder) throws {
            switch self {
            case .normal(let element):
                try element.encode(to: encoder)
            case .group(let nodes):
                try nodes.encode(to: encoder)
            }
        }
    }
}

/// Element state with smart omission of default values
public struct AIElementState: Codable {
    public let selected: Bool?
    public let enabled: Bool?
    public let focused: Bool?
    
    /// Initialize with explicit values
    public init(selected: Bool? = nil, enabled: Bool? = nil, focused: Bool? = nil) {
        // Only store non-default values
        self.selected = selected == true ? true : nil
        self.enabled = enabled == false ? false : nil
        self.focused = focused == true ? true : nil
    }
    
    /// Check if all values are default (for omission)
    public var isDefault: Bool {
        selected == nil && enabled == nil && focused == nil
    }
}