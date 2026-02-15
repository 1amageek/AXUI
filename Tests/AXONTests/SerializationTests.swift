import Testing
import Foundation
@testable import AXUI

// MARK: - Serialization Tests (Fixes #8, #9, #17)

struct SerializationTests {

    // MARK: - SystemRole round-trip (Fix #9)

    @Test("SystemRole survives encode/decode round-trip")
    func systemRoleRoundTrip() throws {
        let element = AXElement(
            systemRole: .toolbar,
            description: "Main Toolbar",
            identifier: "toolbar-1",
            roleDescription: nil,
            help: nil,
            position: Point(x: 0, y: 0),
            size: Size(width: 800, height: 44),
            selected: false,
            enabled: true,
            focused: false
        )

        let data = try JSONEncoder().encode(element)
        let decoded = try JSONDecoder().decode(AXElement.self, from: data)

        #expect(decoded.systemRoleName == "Toolbar")
        #expect(decoded.role == .toolbar)
    }

    @Test("All new SystemRoles survive round-trip")
    func allNewSystemRolesRoundTrip() throws {
        let systemRoles: [SystemRole] = [
            .toolbar, .tabGroup, .menuBar, .splitGroup,
            .outline, .cell, .row, .column,
            .comboBox, .disclosureTriangle, .menuItem
        ]

        for systemRole in systemRoles {
            let element = AXElement(
                systemRole: systemRole,
                description: nil,
                identifier: "test-\(systemRole.rawValue)",
                roleDescription: nil,
                help: nil,
                position: Point(x: 10, y: 20),
                size: Size(width: 100, height: 50),
                selected: false,
                enabled: true,
                focused: false
            )

            let data = try JSONEncoder().encode(element)
            let decoded = try JSONDecoder().decode(AXElement.self, from: data)

            #expect(decoded.systemRoleName == systemRole.rawValue,
                    "SystemRole.\(systemRole) lost after round-trip: got \(decoded.systemRoleName)")
            #expect(decoded.role == element.role,
                    "Role mismatch after round-trip for SystemRole.\(systemRole)")
        }
    }

    @Test("Decode from legacy JSON without systemRole key falls back to role")
    func legacyDecodeWithoutSystemRole() throws {
        // Simulate old JSON format that only has "role" but not "systemRole"
        let json = """
        {
            "id": "abcdefghijkl",
            "role": "Button",
            "description": "Save"
        }
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AXElement.self, from: data)

        #expect(decoded.role == .button)
        #expect(decoded.description == "Save")
    }

    // MARK: - Legacy 4-char ID migration (Fix #8)

    @Test("4-char legacy ID triggers regeneration to 12-char")
    func legacyIDMigration() throws {
        let json = """
        {
            "id": "Ab1X",
            "systemRole": "Button",
            "role": "Button",
            "description": "Test",
            "identifier": "test-btn",
            "position": {"x": 100, "y": 200},
            "size": {"width": 80, "height": 30}
        }
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AXElement.self, from: data)

        #expect(decoded.id.count == 12, "Legacy 4-char ID should be regenerated to 12-char")
        #expect(decoded.id != "Ab1X", "Should not keep the legacy 4-char ID")
    }

    @Test("12-char ID is preserved as-is during decode")
    func stableIDPreserved() throws {
        let element = AXElement(
            systemRole: .button,
            description: "Test",
            identifier: "test-btn",
            roleDescription: nil,
            help: nil,
            position: Point(x: 100, y: 200),
            size: Size(width: 80, height: 30),
            selected: false,
            enabled: true,
            focused: false
        )

        let originalID = element.id
        #expect(originalID.count == 12)

        let data = try JSONEncoder().encode(element)
        let decoded = try JSONDecoder().decode(AXElement.self, from: data)

        #expect(decoded.id == originalID, "12-char ID should be preserved through encode/decode")
    }

    // MARK: - Value property (Fix #17)

    @Test("AXElement preserves value through encode/decode")
    func valuePropertyRoundTrip() throws {
        let element = AXElement(
            systemRole: .textField,
            description: "Username",
            identifier: "username-field",
            roleDescription: nil,
            help: nil,
            value: "john_doe",
            position: Point(x: 50, y: 100),
            size: Size(width: 200, height: 30),
            selected: false,
            enabled: true,
            focused: false
        )

        #expect(element.value == "john_doe")
        #expect(element.description == "Username")

        let data = try JSONEncoder().encode(element)
        let decoded = try JSONDecoder().decode(AXElement.self, from: data)

        #expect(decoded.value == "john_doe")
        #expect(decoded.description == "Username")
    }

    @Test("Value and description are independent properties")
    func valueAndDescriptionIndependent() {
        let element = AXElement(
            systemRole: .slider,
            description: "Volume",
            identifier: "volume-slider",
            roleDescription: nil,
            help: nil,
            value: "75",
            position: nil,
            size: nil,
            selected: false,
            enabled: true,
            focused: false
        )

        #expect(element.value == "75")
        #expect(element.description == "Volume")
        #expect(element.value != element.description)
    }

    @Test("Value defaults to nil when not provided")
    func valueDefaultsToNil() {
        let element = AXElement(
            systemRole: .button,
            description: "Save",
            identifier: nil,
            roleDescription: nil,
            help: nil,
            position: nil,
            size: nil,
            selected: false,
            enabled: true,
            focused: false
        )

        #expect(element.value == nil)
    }

    // MARK: - JSON contains systemRole key

    @Test("Encoded JSON contains systemRole key")
    func jsonContainsSystemRole() throws {
        let element = AXElement(
            systemRole: .disclosureTriangle,
            description: nil,
            identifier: nil,
            roleDescription: nil,
            help: nil,
            position: nil,
            size: nil,
            selected: false,
            enabled: true,
            focused: false
        )

        let data = try JSONEncoder().encode(element)
        let jsonString = String(data: data, encoding: .utf8)!

        #expect(jsonString.contains("\"systemRole\":\"DisclosureTriangle\""))
        #expect(jsonString.contains("\"role\":\"Disclosure\""))
    }
}
