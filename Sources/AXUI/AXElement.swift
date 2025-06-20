import Foundation
@preconcurrency import ApplicationServices
import CryptoKit


public struct AXElement: Codable, @unchecked Sendable {
    // Generated ID
    public let id: String
    
    // Core properties (system role for ID generation and compatibility)
    internal let systemRole: SystemRole
    
    /// User-friendly role computed from systemRole
    public var role: Role {
        return systemRole.generic
    }
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
    
    private enum CodingKeys: String, CodingKey, Sendable {
        case id, role, description, identifier, roleDescription, help, position, size, state, children
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(role.rawValue, forKey: .role)
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
        id = try container.decode(String.self, forKey: .id)
        let roleString = try container.decodeIfPresent(String.self, forKey: .role)
        // When deserializing, we need to reverse-map Role back to SystemRole
        // This is a best-effort approach since the mapping isn't perfect
        if let roleString = roleString, let role = Role(rawValue: roleString) {
            // Try to find a corresponding SystemRole for this Role
            systemRole = role.possibleSystemRoles.first ?? .unknown
        } else {
            systemRole = .unknown
        }
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
    
    internal init(
        systemRole: SystemRole,
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
        self.systemRole = systemRole
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
        
        // Generate consistent ID based on element properties
        self.id = Self.generateID(
            role: systemRole.rawValue,
            identifier: identifier,
            position: position,
            size: size
        )
    }
    
    /// Generates a consistent 4-character alphanumeric ID based on element properties
    private static func generateID(role: String?, identifier: String?, position: Point?, size: Size?) -> String {
        // Create a string representation of the key properties
        var hashInput = ""
        if let role = role {
            hashInput += role
        }
        if let identifier = identifier {
            hashInput += identifier
        }
        if let position = position {
            hashInput += "\(position.x),\(position.y)"
        }
        if let size = size {
            hashInput += "\(size.width),\(size.height)"
        }
        
        // Generate SHA256 hash using CryptoKit
        let data = hashInput.data(using: .utf8)!
        let hash = SHA256.hash(data: data)
        
        // Convert hash bytes to alphanumeric string
        let alphanumeric = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
        var id = ""
        
        // Take first 4 bytes and map to alphanumeric characters
        let hashBytes = Array(hash)
        for i in 0..<4 {
            let index = Int(hashBytes[i]) % alphanumeric.count
            let charIndex = alphanumeric.index(alphanumeric.startIndex, offsetBy: index)
            id.append(alphanumeric[charIndex])
        }
        
        return id
    }
    
    // MARK: - Value Operations
    
    /// Get the current value of this element
    public func getValue() -> String? {
        guard let axElement = axElementRef else { return nil }
        
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(axElement, kAXValueAttribute as CFString, &value)
        
        guard result == .success, let stringValue = value as? String else {
            return nil
        }
        
        return stringValue
    }
    
    /// Set the value of this element
    public func setValue(_ newValue: String) throws {
        guard let axElement = axElementRef else {
            throw AXElementError.noElementReference
        }
        
        let result = AXUIElementSetAttributeValue(axElement, kAXValueAttribute as CFString, newValue as CFString)
        
        guard result == .success else {
            throw AXElementError.setValueFailed(result)
        }
    }
}

// MARK: - AXElement Errors

public enum AXElementError: Error, LocalizedError {
    case noElementReference
    case setValueFailed(AXError)
    
    public var errorDescription: String? {
        switch self {
        case .noElementReference:
            return "No accessibility element reference available for this element"
        case .setValueFailed(let axError):
            return "Failed to set value: \(axError.description)"
        }
    }
}

extension AXError {
    var description: String {
        switch self {
        case .success:
            return "Success"
        case .failure:
            return "General failure"
        case .illegalArgument:
            return "Illegal argument"
        case .invalidUIElement:
            return "Invalid UI element"
        case .invalidUIElementObserver:
            return "Invalid UI element observer"
        case .cannotComplete:
            return "Cannot complete operation"
        case .attributeUnsupported:
            return "Attribute unsupported"
        case .actionUnsupported:
            return "Action unsupported"
        case .notificationUnsupported:
            return "Notification unsupported"
        case .notImplemented:
            return "Not implemented"
        case .notificationAlreadyRegistered:
            return "Notification already registered"
        case .notificationNotRegistered:
            return "Notification not registered"
        case .apiDisabled:
            return "API disabled"
        case .noValue:
            return "No value"
        case .parameterizedAttributeUnsupported:
            return "Parameterized attribute unsupported"
        case .notEnoughPrecision:
            return "Not enough precision"
        @unknown default:
            return "Unknown error (\(self.rawValue))"
        }
    }
}

/// Element state for flat representation
public struct AXElementState: Codable, Sendable {
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
