import Foundation
@preconcurrency import ApplicationServices

/// Non-Sendable wrapper for AXUIElement references.
/// Provides value operations (getValue/setValue/performAction) against live accessibility elements.
public struct AXElementRef {
    internal let axElement: AXUIElement
    public let elementID: String

    public init(axElement: AXUIElement, elementID: String) {
        self.axElement = axElement
        self.elementID = elementID
    }

    /// Get the current value of this element
    public func getValue() throws -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(axElement, kAXValueAttribute as CFString, &value)

        guard result == .success else {
            if result == .noValue || result == .attributeUnsupported {
                return nil
            }
            throw AXElementError.getValueFailed(result)
        }

        return value as? String
    }

    /// Set the value of this element
    public func setValue(_ newValue: String) throws {
        let result = AXUIElementSetAttributeValue(axElement, kAXValueAttribute as CFString, newValue as CFString)

        guard result == .success else {
            throw AXElementError.setValueFailed(result)
        }
    }

    /// Perform an accessibility action on this element
    public func performAction(_ action: String) throws {
        let result = AXUIElementPerformAction(axElement, action as CFString)

        guard result == .success else {
            throw AXElementError.actionFailed(action, result)
        }
    }
}
