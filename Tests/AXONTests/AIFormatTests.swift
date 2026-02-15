import Testing
import Foundation
@testable import AXUI

// MARK: - AI Format Tests (Fixes #14, #15, #7 in AI layer)

struct AIFormatTests {

    // MARK: - RoleDescriptionFilter (Fix #14)

    @Test("Redundant English role descriptions are filtered out")
    func filterEnglishRedundant() {
        #expect(RoleDescriptionFilter.filter(role: "Button", roleDescription: "Button") == nil)
        #expect(RoleDescriptionFilter.filter(role: "Text", roleDescription: "Static Text") == nil)
        #expect(RoleDescriptionFilter.filter(role: "Text", roleDescription: "Text") == nil)
        #expect(RoleDescriptionFilter.filter(role: "Field", roleDescription: "Text Field") == nil)
        #expect(RoleDescriptionFilter.filter(role: "Image", roleDescription: "Image") == nil)
        #expect(RoleDescriptionFilter.filter(role: "Link", roleDescription: "Link") == nil)
        #expect(RoleDescriptionFilter.filter(role: "Slider", roleDescription: "Slider") == nil)
    }

    @Test("Redundant Japanese role descriptions are filtered out")
    func filterJapaneseRedundant() {
        #expect(RoleDescriptionFilter.filter(role: "Button", roleDescription: "ボタン") == nil)
        #expect(RoleDescriptionFilter.filter(role: "Text", roleDescription: "テキスト") == nil)
        #expect(RoleDescriptionFilter.filter(role: "Text", roleDescription: "静的テキスト") == nil)
        #expect(RoleDescriptionFilter.filter(role: "Field", roleDescription: "テキストフィールド") == nil)
        #expect(RoleDescriptionFilter.filter(role: "Image", roleDescription: "イメージ") == nil)
        #expect(RoleDescriptionFilter.filter(role: "Window", roleDescription: "標準ウインドウ") == nil)
    }

    @Test("Non-redundant descriptions are preserved")
    func preserveNonRedundant() {
        #expect(RoleDescriptionFilter.filter(role: "Button", roleDescription: "Toggle Button") == "Toggle Button")
        #expect(RoleDescriptionFilter.filter(role: "Button", roleDescription: "Close") == "Close")
        #expect(RoleDescriptionFilter.filter(role: "Field", roleDescription: "Search field") == "Search field")
        #expect(RoleDescriptionFilter.filter(role: "Text", roleDescription: "Heading Level 2") == "Heading Level 2")
    }

    @Test("Nil and empty descriptions return nil")
    func nilAndEmptyDescriptions() {
        #expect(RoleDescriptionFilter.filter(role: "Button", roleDescription: nil) == nil)
        #expect(RoleDescriptionFilter.filter(role: "Button", roleDescription: "") == nil)
        #expect(RoleDescriptionFilter.filter(role: "Button", roleDescription: "  ") == nil)
        #expect(RoleDescriptionFilter.filter(role: nil, roleDescription: "Button") == nil)
    }

    @Test("New role types have filter entries")
    func newRoleFilters() {
        // New roles should have their standard descriptions filtered
        #expect(RoleDescriptionFilter.filter(role: "ComboBox", roleDescription: "Combo Box") == nil)
        #expect(RoleDescriptionFilter.filter(role: "ComboBox", roleDescription: "コンボボックス") == nil)
        #expect(RoleDescriptionFilter.filter(role: "Disclosure", roleDescription: "Disclosure Triangle") == nil)
        #expect(RoleDescriptionFilter.filter(role: "Outline", roleDescription: "Outline") == nil)
        #expect(RoleDescriptionFilter.filter(role: "TabGroup", roleDescription: "Tab Group") == nil)
        #expect(RoleDescriptionFilter.filter(role: "SplitGroup", roleDescription: "Split Group") == nil)
        #expect(RoleDescriptionFilter.filter(role: "Cell", roleDescription: "Cell") == nil)
        #expect(RoleDescriptionFilter.filter(role: "Row", roleDescription: "Row") == nil)
        #expect(RoleDescriptionFilter.filter(role: "Column", roleDescription: "Column") == nil)
    }

    // MARK: - Group encoding as object (Fix #15)

    @Test("Group elements are always encoded as JSON objects with ID")
    func groupAlwaysEncodedAsObject() throws {
        let child = AXElement(
            systemRole: .button,
            description: "Click",
            identifier: nil,
            roleDescription: nil,
            help: nil,
            position: Point(x: 10, y: 10),
            size: Size(width: 50, height: 20),
            selected: false,
            enabled: true,
            focused: false
        )

        let group = AXElement(
            systemRole: .group,
            description: nil,
            identifier: nil,
            roleDescription: nil,
            help: nil,
            position: nil,
            size: nil,
            selected: false,
            enabled: true,
            focused: false,
            children: [child]
        )

        let encoder = AIElementEncoder()
        let aiGroup = encoder.convert(from: group)
        let json = try encoder.encode(aiGroup, pretty: false)

        // Must contain "id" — proving it's an object, not an array
        #expect(json.contains("\"id\":\""))
        // Must contain the group's ID
        #expect(json.contains(aiGroup.id))
    }

    @Test("Group without children still has ID in JSON")
    func emptyGroupHasID() throws {
        let group = AXElement(
            systemRole: .group,
            description: nil,
            identifier: "empty-group",
            roleDescription: nil,
            help: nil,
            position: Point(x: 0, y: 0),
            size: Size(width: 100, height: 100),
            selected: false,
            enabled: true,
            focused: false
        )

        let encoder = AIElementEncoder()
        let aiGroup = encoder.convert(from: group)
        let json = try encoder.encode(aiGroup, pretty: false)

        #expect(json.contains("\"id\":\""))
        #expect(json.contains(aiGroup.id))
    }

    // MARK: - AIElement value mapping (Fix #7 in AI layer)

    @Test("AIElement value comes from AXElement.value, not description")
    func aiElementValueFromValue() {
        let element = AXElement(
            systemRole: .textField,
            description: "Username Label",
            identifier: "username",
            roleDescription: nil,
            help: nil,
            value: "john_doe",
            position: Point(x: 10, y: 10),
            size: Size(width: 200, height: 30),
            selected: false,
            enabled: true,
            focused: false
        )

        let encoder = AIElementEncoder()
        let aiElement = encoder.convert(from: element)

        #expect(aiElement.value == "john_doe")
        #expect(aiElement.value != "Username Label")
    }

    @Test("AIElement value is nil when AXElement.value is nil")
    func aiElementNilValue() {
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

        let encoder = AIElementEncoder()
        let aiElement = encoder.convert(from: element)

        #expect(aiElement.value == nil)
    }

    @Test("AIElementConverter value comes from AXElement.value")
    func converterValueFromValue() throws {
        let element = AXElement(
            systemRole: .slider,
            description: "Volume",
            identifier: "volume",
            roleDescription: nil,
            help: nil,
            value: "75",
            position: Point(x: 10, y: 10),
            size: Size(width: 200, height: 20),
            selected: false,
            enabled: true,
            focused: false
        )

        let converter = AIElementConverter()
        let json = try converter.convert(from: [element], pretty: false)

        // JSON should contain the value "75"
        #expect(json.contains("\"value\":\"75\""))
        // JSON should NOT have description as value
        #expect(!json.contains("\"value\":\"Volume\""))
    }

    // MARK: - AI export from snapshot

    @Test("exportAI includes value from element.value")
    func exportAIValue() throws {
        let element = AXElement(
            systemRole: .textField,
            description: "Email",
            identifier: "email-field",
            roleDescription: nil,
            help: nil,
            value: "test@example.com",
            position: Point(x: 50, y: 100),
            size: Size(width: 200, height: 30),
            selected: false,
            enabled: true,
            focused: false
        )

        let snapshot = AXSnapshotService.buildSnapshot(
            elements: [element],
            appContext: AppContext(bundleIdentifier: "com.test.app"),
            windowContext: WindowContext(selection: .all, index: nil, windowNumber: nil, title: nil)
        )

        let aiJSON = try AXSnapshotService.exportAI(snapshot: snapshot, pretty: false)

        #expect(aiJSON.contains("\"value\":\"test@example.com\""))
    }

    // MARK: - AIElement name mapping

    @Test("AIElement name comes from AXElement.identifier")
    func aiElementNameFromIdentifier() {
        let element = AXElement(
            systemRole: .button,
            description: "Save Button",
            identifier: "save-action-btn",
            roleDescription: nil,
            help: nil,
            position: Point(x: 10, y: 10),
            size: Size(width: 80, height: 30),
            selected: false,
            enabled: true,
            focused: false
        )

        let encoder = AIElementEncoder()
        let aiElement = encoder.convert(from: element)

        #expect(aiElement.name == "save-action-btn")
    }
}
