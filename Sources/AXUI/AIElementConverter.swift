import Foundation

/// Converter for transforming various input formats to AI-optimized elements
public struct AIElementConverter: Sendable {
    private let encoder: AIElementEncoder

    public init() {
        self.encoder = AIElementEncoder()
    }

    // MARK: - Flat Array Conversion

    /// Convert flat AXElement array to AI format (preserves flat structure)
    public func convert(from axElements: [AXElement], pretty: Bool = false) throws -> String {
        // For flat arrays, we convert each element individually without nested children
        let aiElements = axElements.map { axElement in
            convertToAIElement(from: axElement)
        }
        return try encoder.encode(aiElements, pretty: pretty)
    }

    // MARK: - Private Conversion Methods

    /// Convert AXElement to flat AI element (without nested children structure)
    private func convertToAIElement(from axElement: AXElement) -> AIElement {
        let normalizedRole = axElement.role.rawValue
        let value = axElement.value
        let name = axElement.identifier
        let desc = RoleDescriptionFilter.filter(role: normalizedRole, roleDescription: axElement.roleDescription)
        let bounds = axElement.bounds
        let state = convertState(from: axElement.state)

        // For flat representation, we don't include children structure
        return AIElement(
            id: axElement.id,
            role: axElement.role,
            value: value,
            name: name,
            desc: desc,
            bounds: bounds,
            state: state?.isDefault == false ? state : nil,
            children: nil
        )
    }

    /// Convert AXElementState to AIElementState
    private func convertState(from axState: AXElementState?) -> AIElementState? {
        guard let axState = axState else { return nil }

        return AIElementState(
            selected: axState.selected,
            enabled: axState.enabled,
            focused: axState.focused
        )
    }
}
