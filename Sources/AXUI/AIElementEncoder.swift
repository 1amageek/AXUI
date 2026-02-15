import Foundation
import CryptoKit

/// Encoder for converting AX elements to AI-optimized format
public final class AIElementEncoder: Sendable {
    private let minifiedEncoder: JSONEncoder
    private let prettyEncoder: JSONEncoder

    public init() {
        self.minifiedEncoder = JSONEncoder()
        self.minifiedEncoder.outputFormatting = []

        self.prettyEncoder = JSONEncoder()
        self.prettyEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    // MARK: - Public Encoding Methods

    /// Encode AIElement to JSON string
    internal func encode(_ element: AIElement, pretty: Bool = false) throws -> String {
        let encoder = pretty ? prettyEncoder : minifiedEncoder
        let data = try encoder.encode(element)
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// Encode AIElement array to JSON string
    internal func encode(_ elements: [AIElement], pretty: Bool = false) throws -> String {
        let encoder = pretty ? prettyEncoder : minifiedEncoder
        let data = try encoder.encode(elements)
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// Encode AIElement to JSON data
    internal func encodeToData(_ element: AIElement, pretty: Bool = false) throws -> Data {
        let encoder = pretty ? prettyEncoder : minifiedEncoder
        return try encoder.encode(element)
    }

    /// Encode AIElement array to JSON data
    internal func encodeToData(_ elements: [AIElement], pretty: Bool = false) throws -> Data {
        let encoder = pretty ? prettyEncoder : minifiedEncoder
        return try encoder.encode(elements)
    }

    // MARK: - AXElement to AIElement Conversion

    /// Convert AXElement to AIElement
    internal func convert(from axElement: AXElement) -> AIElement {
        return convert(from: axElement, parentPath: [])
    }

    /// Convert AXElement to AIElement with hierarchical path tracking
    private func convert(from axElement: AXElement, parentPath: [Int]) -> AIElement {
        let id = axElement.id
        let normalizedRole = axElement.role.rawValue
        let value = axElement.value
        let name = axElement.identifier
        let desc = RoleDescriptionFilter.filter(role: normalizedRole, roleDescription: axElement.roleDescription)
        let bounds = axElement.bounds
        let state = convertState(from: axElement.state)
        let children = convertChildren(from: axElement.children, parentPath: parentPath)

        // Groups keep their ID and are always encoded as objects (no array optimization)
        if normalizedRole == "Group" {
            return AIElement(
                id: id,
                role: nil, // Group role is omitted in AI format
                value: value,
                name: name,
                desc: desc,
                bounds: bounds,
                state: state?.isDefault == false ? state : nil,
                children: children
            )
        }

        return AIElement(
            id: id,
            role: axElement.role,
            value: value,
            name: name,
            desc: desc,
            bounds: bounds,
            state: state?.isDefault == false ? state : nil,
            children: children
        )
    }

    /// Convert array of AXElements to AIElements
    internal func convert(from axElements: [AXElement]) -> [AIElement] {
        return axElements.map { convert(from: $0) }
    }

    // MARK: - Private Conversion Methods

    private func convertState(from axState: AXElementState?) -> AIElementState? {
        guard let axState = axState else { return nil }

        let state = AIElementState(
            selected: axState.selected,
            enabled: axState.enabled,
            focused: axState.focused
        )

        return state.isDefault ? nil : state
    }

    private func convertChildren(from axChildren: [AXElement]?, parentPath: [Int]) -> [AIElement.Node]? {
        guard let axChildren = axChildren, !axChildren.isEmpty else { return nil }

        return axChildren.enumerated().map { index, child in
            let childPath = parentPath + [index]
            let aiChild = convert(from: child, parentPath: childPath)
            return .normal(aiChild)
        }
    }
}

// MARK: - Custom Encoding for AIElement

extension AIElement {
    public func encode(to encoder: Encoder) throws {
        // Always encode as object to preserve ID
        var container = encoder.container(keyedBy: AIElementCodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(role, forKey: .role)
        try container.encodeIfPresent(value, forKey: .value)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(desc, forKey: .desc)
        try container.encodeIfPresent(bounds, forKey: .bounds)
        try container.encodeIfPresent(state, forKey: .state)
        try container.encodeIfPresent(children, forKey: .children)
    }
}

private enum AIElementCodingKeys: String, CodingKey, Sendable {
    case id, role, value, name, desc, bounds, state, children
}
