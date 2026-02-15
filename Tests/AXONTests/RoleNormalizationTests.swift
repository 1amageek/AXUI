import Testing
import Foundation
@testable import AXUI

// MARK: - Role Normalization Tests (Fix #3)

struct RoleNormalizationTests {

    // MARK: - New Role cases preserve semantic meaning

    @Test("toolbar SystemRole maps to .toolbar Role, not .group")
    func toolbarPreservation() {
        let element = AXElement(
            systemRole: .toolbar,
            description: "Main Toolbar",
            identifier: "main-toolbar",
            roleDescription: nil,
            help: nil,
            position: Point(x: 0, y: 0),
            size: Size(width: 800, height: 44),
            selected: false,
            enabled: true,
            focused: false
        )
        #expect(element.role == .toolbar)
        #expect(element.role != .group)
    }

    @Test("tabGroup SystemRole maps to .tabGroup Role, not .group")
    func tabGroupPreservation() {
        let element = AXElement(
            systemRole: .tabGroup,
            description: nil,
            identifier: "tab-group",
            roleDescription: nil,
            help: nil,
            position: nil,
            size: nil,
            selected: false,
            enabled: true,
            focused: false
        )
        #expect(element.role == .tabGroup)
        #expect(element.role != .group)
    }

    @Test("menuBar SystemRole maps to .menuBar Role, not .group")
    func menuBarPreservation() {
        let element = AXElement(
            systemRole: .menuBar,
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
        #expect(element.role == .menuBar)
    }

    @Test("splitGroup SystemRole maps to .splitGroup Role, not .group")
    func splitGroupPreservation() {
        let element = AXElement(
            systemRole: .splitGroup,
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
        #expect(element.role == .splitGroup)
    }

    @Test("outline SystemRole maps to .outline Role, not .list")
    func outlinePreservation() {
        let element = AXElement(
            systemRole: .outline,
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
        #expect(element.role == .outline)
        #expect(element.role != .list)
    }

    @Test("cell, row, column SystemRoles map to distinct Role cases")
    func tableStructureRoles() {
        let cell = AXElement(
            systemRole: .cell,
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
        let row = AXElement(
            systemRole: .row,
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
        let column = AXElement(
            systemRole: .column,
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
        #expect(cell.role == .cell)
        #expect(row.role == .row)
        #expect(column.role == .column)
    }

    @Test("comboBox SystemRole maps to .comboBox, not .popUp")
    func comboBoxPreservation() {
        let element = AXElement(
            systemRole: .comboBox,
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
        #expect(element.role == .comboBox)
        #expect(element.role != .popUp)
    }

    @Test("disclosureTriangle SystemRole maps to .disclosure, not .button")
    func disclosurePreservation() {
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
        #expect(element.role == .disclosure)
        #expect(element.role != .button)
    }

    @Test("menuItem and menuBarItem SystemRoles map to .menuItem")
    func menuItemPreservation() {
        let menuItem = AXElement(
            systemRole: .menuItem,
            description: "Copy",
            identifier: nil,
            roleDescription: nil,
            help: nil,
            position: nil,
            size: nil,
            selected: false,
            enabled: true,
            focused: false
        )
        let menuBarItem = AXElement(
            systemRole: .menuBarItem,
            description: "File",
            identifier: nil,
            roleDescription: nil,
            help: nil,
            position: nil,
            size: nil,
            selected: false,
            enabled: true,
            focused: false
        )
        #expect(menuItem.role == .menuItem)
        #expect(menuBarItem.role == .menuItem)
    }

    // MARK: - isInteractive for new roles

    @Test("New interactive roles: comboBox, disclosure, menuItem")
    func newInteractiveRoles() {
        #expect(Role.comboBox.isInteractive)
        #expect(Role.disclosure.isInteractive)
        #expect(Role.menuItem.isInteractive)
    }

    @Test("Container roles are not interactive")
    func containerRolesNotInteractive() {
        #expect(!Role.toolbar.isInteractive)
        #expect(!Role.tabGroup.isInteractive)
        #expect(!Role.menuBar.isInteractive)
        #expect(!Role.splitGroup.isInteractive)
        #expect(!Role.outline.isInteractive)
    }

    // MARK: - isContainer for new roles

    @Test("New container roles: toolbar, tabGroup, menuBar, splitGroup, outline")
    func newContainerRoles() {
        #expect(Role.toolbar.isContainer)
        #expect(Role.tabGroup.isContainer)
        #expect(Role.menuBar.isContainer)
        #expect(Role.splitGroup.isContainer)
        #expect(Role.outline.isContainer)
    }

    @Test("Interactive roles are not containers")
    func interactiveRolesNotContainers() {
        #expect(!Role.comboBox.isContainer)
        #expect(!Role.disclosure.isContainer)
        #expect(!Role.menuItem.isContainer)
    }

    // MARK: - All 11 new SystemRole → Role mappings

    @Test("All new SystemRole → Role mappings produce distinct roles")
    func allNewMappingsDistinct() {
        let mappings: [(SystemRole, Role)] = [
            (.toolbar, .toolbar),
            (.tabGroup, .tabGroup),
            (.menuBar, .menuBar),
            (.splitGroup, .splitGroup),
            (.outline, .outline),
            (.cell, .cell),
            (.row, .row),
            (.column, .column),
            (.comboBox, .comboBox),
            (.disclosureTriangle, .disclosure),
            (.menuItem, .menuItem),
        ]
        for (systemRole, expectedRole) in mappings {
            #expect(systemRole.generic == expectedRole, "SystemRole.\(systemRole) should map to Role.\(expectedRole)")
        }
    }
}
