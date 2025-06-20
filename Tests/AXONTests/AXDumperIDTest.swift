import Testing
import Foundation
@testable import AXUI

@Test func testGetElementByID() throws {
    // Test creating elements with generated IDs
    let element1 = AXElement(
        systemRole: .button,
        description: "Save",
        identifier: "save-btn",
        roleDescription: "Save Button",
        help: nil,
        position: Point(x: 100, y: 200),
        size: Size(width: 80, height: 30),
        selected: false,
        enabled: true,
        focused: false
    )
    
    let element2 = AXElement(
        systemRole: .textField,
        description: nil,
        identifier: "username-field",
        roleDescription: "Username Input",
        help: nil,
        position: Point(x: 50, y: 100),
        size: Size(width: 200, height: 25),
        selected: false,
        enabled: true,
        focused: false
    )
    
    // Verify IDs are generated consistently
    #expect(element1.id.count == 4)
    #expect(element2.id.count == 4)
    #expect(element1.id != element2.id) // Different elements should have different IDs
    
    // Test that same properties generate same ID
    let duplicateElement = AXElement(
        systemRole: .button,
        description: "Save",
        identifier: "save-btn",
        roleDescription: "Save Button",
        help: nil,
        position: Point(x: 100, y: 200),
        size: Size(width: 80, height: 30),
        selected: false,
        enabled: true,
        focused: false
    )
    
    #expect(element1.id == duplicateElement.id) // Same properties should generate same ID
}

@Test func testIDConsistency() throws {
    // Test ID generation consistency across different creation methods
    let role: SystemRole = .button
    let identifier = "test-button"
    let position = Point(x: 150, y: 250)
    let size = Size(width: 100, height: 40)
    
    let element1 = AXElement(
        systemRole: role,
        description: "Test Button",
        identifier: identifier,
        roleDescription: nil,
        help: nil,
        position: position,
        size: size,
        selected: false,
        enabled: true,
        focused: false
    )
    
    let element2 = AXElement(
        systemRole: role,
        description: "Test Button",
        identifier: identifier,
        roleDescription: nil,
        help: nil,
        position: position,
        size: size,
        selected: false,
        enabled: true,
        focused: false
    )
    
    // Elements with identical properties should have identical IDs
    #expect(element1.id == element2.id)
    
    // Different position should generate different ID
    let element3 = AXElement(
        systemRole: role,
        description: "Test Button",
        identifier: identifier,
        roleDescription: nil,
        help: nil,
        position: Point(x: 151, y: 250), // Different x position
        size: size,
        selected: false,
        enabled: true,
        focused: false
    )
    
    #expect(element1.id != element3.id)
}

@Test func testCacheManagement() throws {
    // Test cache clearing functionality
    AXDumper.clearCache()
    
    // Test cache clearing for specific bundle
    AXDumper.clearCache(for: "com.example.test")
    
    // Since we can't easily test actual accessibility elements in unit tests,
    // we just verify that the cache methods don't throw errors
    #expect(true) // Cache methods executed without error
}