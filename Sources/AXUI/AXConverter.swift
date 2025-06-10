import Foundation

// MARK: - Core Data Structures

/// Represents a UI tree node in the lightweight JSON format
public enum UINode: Codable {
    case normal(UINodeObject)
    case group([UINode])
    
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .normal(let object):
            try object.encode(to: encoder)
        case .group(let children):
            var container = encoder.unkeyedContainer()
            for child in children {
                try container.encode(child)
            }
        }
    }
    
    public init(from decoder: Decoder) throws {
        if let container = try? decoder.unkeyedContainer() {
            var children: [UINode] = []
            var mutableContainer = container
            while !mutableContainer.isAtEnd {
                children.append(try mutableContainer.decode(UINode.self))
            }
            self = .group(children)
        } else {
            let object = try UINodeObject(from: decoder)
            self = .normal(object)
        }
    }
}

/// Standard UI node object representation
public struct UINodeObject: Codable {
    public let role: String?
    public let roleDescription: String?
    public let identifier: String?
    public let value: String?
    public let help: String?
    public let bounds: [Int]?
    public let state: UINodeState?
    public let children: [UINode]?
    
    enum CodingKeys: String, CodingKey {
        case role
        case roleDescription
        case identifier
        case value
        case help
        case bounds
        case state
        case children
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        // Encode in specific order with children last
        if let role = role { try container.encode(role, forKey: .role) }
        if let roleDescription = roleDescription { try container.encode(roleDescription, forKey: .roleDescription) }
        if let identifier = identifier { try container.encode(identifier, forKey: .identifier) }
        if let value = value { try container.encode(value, forKey: .value) }
        if let help = help { try container.encode(help, forKey: .help) }
        if let bounds = bounds { try container.encode(bounds, forKey: .bounds) }
        if let state = state { try container.encode(state, forKey: .state) }
        // children always last
        if let children = children { try container.encode(children, forKey: .children) }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        role = try container.decodeIfPresent(String.self, forKey: .role)
        roleDescription = try container.decodeIfPresent(String.self, forKey: .roleDescription)
        identifier = try container.decodeIfPresent(String.self, forKey: .identifier)
        value = try container.decodeIfPresent(String.self, forKey: .value)
        help = try container.decodeIfPresent(String.self, forKey: .help)
        bounds = try container.decodeIfPresent([Int].self, forKey: .bounds)
        state = try container.decodeIfPresent(UINodeState.self, forKey: .state)
        children = try container.decodeIfPresent([UINode].self, forKey: .children)
    }
    
    public init(
        role: String? = nil,
        roleDescription: String? = nil,
        identifier: String? = nil,
        value: String? = nil,
        help: String? = nil,
        bounds: [Int]? = nil,
        state: UINodeState? = nil,
        children: [UINode] = []
    ) {
        self.role = role
        self.roleDescription = roleDescription
        self.identifier = identifier
        self.value = value
        self.help = help
        self.bounds = bounds
        self.state = state
        self.children = children.isEmpty ? nil : children
    }
}

/// UI node state representation
public struct UINodeState: Codable, Equatable {
    public let selected: Bool?
    public let enabled: Bool?
    public let focused: Bool?
    
    public init(selected: Bool? = nil, enabled: Bool? = nil, focused: Bool? = nil) {
        self.selected = selected
        self.enabled = enabled
        self.focused = focused
    }
    
    /// Check if all state values are in their default state
    public var isDefault: Bool {
        selected == false && enabled == true && focused == false
    }
    
    /// Create state with only non-default values
    public static func create(selected: Bool = false, enabled: Bool = true, focused: Bool = false) -> UINodeState? {
        // Only include non-default values to minimize tokens
        let state = UINodeState(
            selected: selected ? true : nil,
            enabled: !enabled ? false : nil,  // Only include when false (non-default)
            focused: focused ? true : nil
        )
        return state.selected == nil && state.enabled == nil && state.focused == nil ? nil : state
    }
}

// MARK: - AX Property Types

/// Raw AX dump properties extracted from text format
public struct AXProperties {
    public let role: String?
    public let roleDescription: String?
    public let identifier: String?
    public let value: String?
    public let help: String?
    public let position: CGPoint?
    public let size: CGSize?
    public let selected: Bool?
    public let enabled: Bool?
    public let focused: Bool?
    public let children: [AXProperties]
    
    public init(
        role: String? = nil,
        roleDescription: String? = nil,
        identifier: String? = nil,
        value: String? = nil,
        help: String? = nil,
        position: CGPoint? = nil,
        size: CGSize? = nil,
        selected: Bool? = nil,
        enabled: Bool? = nil,
        focused: Bool? = nil,
        children: [AXProperties] = []
    ) {
        self.role = role
        self.roleDescription = roleDescription
        self.identifier = identifier
        self.value = value
        self.help = help
        self.position = position
        self.size = size
        self.selected = selected
        self.enabled = enabled
        self.focused = focused
        self.children = children
    }
}

// MARK: - Conversion Extensions

extension AXProperties {
    
    /// Convert AX properties to UI node
    public func toUINode() -> UINode {
        var normalizedRole = role?.hasPrefix("AX") == true ? String(role!.dropFirst(2)) : role
        
        // Further normalize common roles
        if normalizedRole == "StaticText" {
            normalizedRole = "Text"
        }
        
        
        // Create bounds from position and size
        let bounds: [Int]? = {
            guard let position = position, let size = size else { return nil }
            return [Int(position.x), Int(position.y), Int(size.width), Int(size.height)]
        }()
        
        // Create state only if not default
        let state = UINodeState.create(
            selected: selected ?? false,
            enabled: enabled ?? true,
            focused: focused ?? false
        )
        
        let convertedChildren = children.map { $0.toUINode() }
        
        // Apply Group optimization rules
        if normalizedRole == "Group" {
            return optimizeGroup(
                value: value,
                help: help,
                roleDescription: roleDescription,
                identifier: identifier,
                bounds: bounds,
                state: state,
                children: convertedChildren
            )
        }
        
        let nodeObject = UINodeObject(
            role: normalizedRole,
            roleDescription: roleDescription,
            identifier: identifier,
            value: value,
            help: help,
            bounds: bounds,
            state: state,
            children: convertedChildren
        )
        
        return .normal(nodeObject)
    }
    
    /// Apply Group optimization rules (G-Minimal vs G-Object)
    private func optimizeGroup(
        value: String?,
        help: String?,
        roleDescription: String?,
        identifier: String?,
        bounds: [Int]?,
        state: UINodeState?,
        children: [UINode]
    ) -> UINode {
        // Check if we can use G-Minimal format
        let hasAdditionalAttributes = value != nil || help != nil || roleDescription != nil || identifier != nil
        let hasNonDefaultState = state != nil
        
        if !hasAdditionalAttributes && !hasNonDefaultState {
            // Use G-Minimal format (array only)
            return .group(children)
        } else {
            // Use G-Object format (object without role, no bounds for groups)
            let nodeObject = UINodeObject(
                role: nil, // Group role is omitted
                roleDescription: roleDescription,
                identifier: identifier,
                value: value,
                help: help,
                bounds: nil, // Groups never include bounds
                state: state,
                children: children
            )
            return .normal(nodeObject)
        }
    }
}

// MARK: - JSON Serialization

extension UINode {
    
    /// Serialize to minified JSON string according to specification
    public func toMinifiedJSON() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = []
        encoder.keyEncodingStrategy = .useDefaultKeys
        if #available(macOS 10.15, iOS 13.0, *) {
            encoder.outputFormatting.insert(.withoutEscapingSlashes)
        }
        let data = try encoder.encode(self)
        return String(data: data, encoding: .utf8)!
    }
    
    /// Serialize to pretty-printed JSON for debugging
    public func toPrettyJSON() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.keyEncodingStrategy = .useDefaultKeys
        let data = try encoder.encode(self)
        return String(data: data, encoding: .utf8)!
    }
    
    /// Serialize to compressed data
    public func toCompressedJSON() throws -> Data {
        let jsonString = try toMinifiedJSON()
        let jsonData = jsonString.data(using: .utf8)!
        return try jsonData.compressed()
    }
    
    /// Create UINode from JSON string
    public static func fromJSON(_ jsonString: String) throws -> UINode {
        guard let data = jsonString.data(using: .utf8) else {
            throw AXSerializationError.invalidJSONString
        }
        return try fromJSONData(data)
    }
    
    /// Create UINode from JSON data
    public static func fromJSONData(_ data: Data) throws -> UINode {
        let decoder = JSONDecoder()
        return try decoder.decode(UINode.self, from: data)
    }
    
    /// Create UINode from compressed JSON data
    public static func fromCompressedJSON(_ compressedData: Data) throws -> UINode {
        let decompressedData = try compressedData.decompressed()
        return try fromJSONData(decompressedData)
    }
}

// MARK: - Serialization Errors

public enum AXSerializationError: Error, LocalizedError {
    case invalidJSONString
    case compressionFailed
    case decompressionFailed
    
    public var errorDescription: String? {
        switch self {
        case .invalidJSONString:
            return "Invalid JSON string encoding"
        case .compressionFailed:
            return "Failed to compress data"
        case .decompressionFailed:
            return "Failed to decompress data"
        }
    }
}

// MARK: - Data Compression Extension

extension Data {
    func compressed() throws -> Data {
        guard !isEmpty else { return Data() }
        do {
            return try (self as NSData).compressed(using: .lzfse) as Data
        } catch {
            throw AXSerializationError.compressionFailed
        }
    }
    
    func decompressed() throws -> Data {
        guard !isEmpty else { return Data() }
        do {
            return try (self as NSData).decompressed(using: .lzfse) as Data
        } catch {
            throw AXSerializationError.decompressionFailed
        }
    }
}

// MARK: - Convenience API

public struct AXConverter {
    
    /// Convert AX dump string to lightweight JSON
    public static func convert(axDump: String) throws -> String {
        let axProperties = try AXParser.parse(content: axDump)
        let uiNode = axProperties.toUINode()
        return try uiNode.toMinifiedJSON()
    }
    
    /// Convert AX dump to pretty JSON for debugging
    public static func convertToPrettyJSON(axDump: String) throws -> String {
        let axProperties = try AXParser.parse(content: axDump)
        let uiNode = axProperties.toUINode()
        return try uiNode.toPrettyJSON()
    }
    
    /// Convert AX dump to compressed JSON data
    public static func convertToCompressed(axDump: String) throws -> Data {
        let axProperties = try AXParser.parse(content: axDump)
        let uiNode = axProperties.toUINode()
        return try uiNode.toCompressedJSON()
    }
}