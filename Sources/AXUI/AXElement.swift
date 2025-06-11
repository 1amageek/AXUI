import Foundation
import ApplicationServices


public struct AXElement: Codable {
    // Core properties
    public let role: String?
    public let description: String?
    public let identifier: String?
    public let roleDescription: String?
    public let help: String?
    public let position: Point?
    public let size: Size?
    public let state: AXElementState?
    public let children: [AXElement]?
    
    // Computed property for bounds
    public var bounds: [Int]? {
        guard let position = position, let size = size else { return nil }
        return [
            Int(position.x),
            Int(position.y),
            Int(size.width),
            Int(size.height)
        ]
    }
    
    // Internal reference (not serialized)
    internal let axElementRef: AXUIElement?
    
    private enum CodingKeys: String, CodingKey {
        case role, description, identifier, roleDescription, help, position, size, state, children
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(role, forKey: .role)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(identifier, forKey: .identifier)
        try container.encodeIfPresent(roleDescription, forKey: .roleDescription)
        try container.encodeIfPresent(help, forKey: .help)
        try container.encodeIfPresent(position, forKey: .position)
        try container.encodeIfPresent(size, forKey: .size)
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
        position = try container.decodeIfPresent(Point.self, forKey: .position)
        size = try container.decodeIfPresent(Size.self, forKey: .size)
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
        position: Point?,
        size: Size?,
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
        self.position = position
        self.size = size
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
