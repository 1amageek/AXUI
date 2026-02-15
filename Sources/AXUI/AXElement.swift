import Foundation
@preconcurrency import ApplicationServices
import CryptoKit


public struct AXElement: Codable, Sendable {
    /// Stable 12-character alphanumeric ID (primary identifier)
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
    public let value: String?
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

    /// Human-readable system role name
    public var systemRoleName: String {
        systemRole.rawValue
    }

    private enum CodingKeys: String, CodingKey, Sendable {
        case id, systemRole, role, description, identifier, roleDescription, help, value, position, size, state, children
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(systemRole.rawValue, forKey: .systemRole)
        try container.encode(role.rawValue, forKey: .role)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(identifier, forKey: .identifier)
        try container.encodeIfPresent(roleDescription, forKey: .roleDescription)
        try container.encodeIfPresent(help, forKey: .help)
        try container.encodeIfPresent(value, forKey: .value)
        try container.encodeIfPresent(position, forKey: .position)
        try container.encodeIfPresent(size, forKey: .size)
        try container.encodeIfPresent(state, forKey: .state)
        try container.encodeIfPresent(children, forKey: .children)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Decode systemRole first (new format) or fall back to role-based reverse mapping
        if let systemRoleString = try container.decodeIfPresent(String.self, forKey: .systemRole),
           let decodedSystemRole = SystemRole(rawValue: systemRoleString) {
            systemRole = decodedSystemRole
        } else {
            let roleString = try container.decodeIfPresent(String.self, forKey: .role)
            if let roleString = roleString, let role = Role(rawValue: roleString) {
                systemRole = role.possibleSystemRoles.first ?? .unknown
            } else {
                systemRole = .unknown
            }
        }

        description = try container.decodeIfPresent(String.self, forKey: .description)
        identifier = try container.decodeIfPresent(String.self, forKey: .identifier)
        roleDescription = try container.decodeIfPresent(String.self, forKey: .roleDescription)
        help = try container.decodeIfPresent(String.self, forKey: .help)
        value = try container.decodeIfPresent(String.self, forKey: .value)
        position = try container.decodeIfPresent(Point.self, forKey: .position)
        size = try container.decodeIfPresent(Size.self, forKey: .size)
        state = try container.decodeIfPresent(AXElementState.self, forKey: .state)
        children = try container.decodeIfPresent([AXElement].self, forKey: .children)

        // Decode id: try new format first, then fall back to stableID key (migration), then generate
        if let decodedID = try container.decodeIfPresent(String.self, forKey: .id) {
            // If the decoded ID is 4 characters (legacy format), regenerate stable ID
            if decodedID.count == 4 {
                id = Self.generateStableID(
                    role: systemRole.rawValue,
                    identifier: identifier,
                    description: description,
                    roleDescription: roleDescription,
                    help: help,
                    position: position,
                    size: size
                )
            } else {
                id = decodedID
            }
        } else {
            id = Self.generateStableID(
                role: systemRole.rawValue,
                identifier: identifier,
                description: description,
                roleDescription: roleDescription,
                help: help,
                position: position,
                size: size
            )
        }
    }

    internal init(
        systemRole: SystemRole,
        description: String?,
        identifier: String?,
        roleDescription: String?,
        help: String?,
        value: String? = nil,
        position: Point?,
        size: Size?,
        selected: Bool,
        enabled: Bool,
        focused: Bool,
        children: [AXElement]? = nil
    ) {
        self.systemRole = systemRole
        self.description = description
        self.identifier = identifier
        self.roleDescription = roleDescription
        self.help = help
        self.value = value
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

        // Generate stable 12-character ID
        self.id = Self.generateStableID(
            role: systemRole.rawValue,
            identifier: identifier,
            description: description,
            roleDescription: roleDescription,
            help: help,
            position: position,
            size: size
        )
    }

    /// Generates a stable 12-character alphanumeric ID based on element properties.
    /// Internal access for AXDumper.elementRef() to match IDs during live traversal.
    internal static func stableID(
        role: String?,
        identifier: String?,
        description: String?,
        roleDescription: String?,
        help: String?,
        position: Point?,
        size: Size?
    ) -> String {
        generateStableID(
            role: role,
            identifier: identifier,
            description: description,
            roleDescription: roleDescription,
            help: help,
            position: position,
            size: size
        )
    }

    private static func generateStableID(
        role: String?,
        identifier: String?,
        description: String?,
        roleDescription: String?,
        help: String?,
        position: Point?,
        size: Size?
    ) -> String {
        var hashInput = ""
        if let role = role {
            hashInput += "r:\(role)|"
        }
        if let identifier = identifier {
            hashInput += "i:\(identifier)|"
        }
        if let description = description {
            hashInput += "d:\(description)|"
        }
        if let roleDescription = roleDescription {
            hashInput += "rd:\(roleDescription)|"
        }
        if let help = help {
            hashInput += "h:\(help)|"
        }
        if let position = position {
            hashInput += "p:\(position.x),\(position.y)|"
        }
        if let size = size {
            hashInput += "s:\(size.width),\(size.height)|"
        }

        let data = hashInput.data(using: .utf8) ?? Data()
        let hash = SHA256.hash(data: data)

        let alphanumeric = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
        let hashBytes = Array(hash)
        var id = ""
        for i in 0..<12 {
            let index = Int(hashBytes[i]) % alphanumeric.count
            let charIndex = alphanumeric.index(alphanumeric.startIndex, offsetBy: index)
            id.append(alphanumeric[charIndex])
        }
        return id
    }
}

// MARK: - AXElement Errors

public enum AXElementError: Error, LocalizedError {
    case noElementReference
    case setValueFailed(AXError)
    case getValueFailed(AXError)
    case actionFailed(String, AXError)

    public var errorDescription: String? {
        switch self {
        case .noElementReference:
            return "No accessibility element reference available for this element"
        case .setValueFailed(let axError):
            return "Failed to set value: \(axError.description)"
        case .getValueFailed(let axError):
            return "Failed to get value: \(axError.description)"
        case .actionFailed(let action, let axError):
            return "Failed to perform action '\(action)': \(axError.description)"
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
