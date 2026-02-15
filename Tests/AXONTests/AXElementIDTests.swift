import Testing
import Foundation
@testable import AXUI

@Test func testAXElementIDGeneration() {
    // Test basic ID generation
    let element = AXElement(
        systemRole: .button,
        description: "Test Button",
        identifier: "test-btn",
        roleDescription: nil,
        help: nil,
        position: Point(x: 100, y: 200),
        size: Size(width: 50, height: 30),
        selected: false,
        enabled: true,
        focused: false
    )
    
    #expect(element.id.count == 12)
    #expect(element.id.allSatisfy { char in
        let alphanumeric = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
        return alphanumeric.contains(char)
    })
}

@Test func testAXElementIDConsistency() {
    // Create two elements with identical properties
    let element1 = AXElement(
        systemRole: .textField,
        description: "Username",
        identifier: "username-field",
        roleDescription: nil,
        help: nil,
        position: Point(x: 50, y: 100),
        size: Size(width: 200, height: 30),
        selected: false,
        enabled: true,
        focused: false
    )
    
    let element2 = AXElement(
        systemRole: .textField,
        description: "Username",
        identifier: "username-field",
        roleDescription: nil,
        help: nil,
        position: Point(x: 50, y: 100),
        size: Size(width: 200, height: 30),
        selected: false,
        enabled: true,
        focused: false
    )
    
    // IDs should be the same for identical elements
    #expect(element1.id == element2.id)
}

@Test func testAXElementIDUniqueness() {
    // Create elements with different properties
    let element1 = AXElement(
        systemRole: .button,
        description: "Save",
        identifier: "save-btn",
        roleDescription: nil,
        help: nil,
        position: Point(x: 100, y: 200),
        size: Size(width: 80, height: 30),
        selected: false,
        enabled: true,
        focused: false
    )
    
    let element2 = AXElement(
        systemRole: .button,
        description: "Cancel",
        identifier: "cancel-btn",
        roleDescription: nil,
        help: nil,
        position: Point(x: 200, y: 200),
        size: Size(width: 80, height: 30),
        selected: false,
        enabled: true,
        focused: false
    )
    
    // IDs should be different for different elements
    #expect(element1.id != element2.id)
}

@Test func testAXElementIDSerialization() throws {
    let element = AXElement(
        systemRole: .button,
        description: "Test",
        identifier: "test",
        roleDescription: nil,
        help: nil,
        position: Point(x: 10, y: 20),
        size: Size(width: 100, height: 50),
        selected: false,
        enabled: true,
        focused: false
    )
    
    // Encode to JSON
    let encoder = JSONEncoder()
    let data = try encoder.encode(element)
    let json = String(data: data, encoding: .utf8)!
    
    // Check that ID is in JSON
    #expect(json.contains("\"id\":"))
    #expect(json.contains("\"\(element.id)\""))
    
    // Decode from JSON
    let decoder = JSONDecoder()
    let decoded = try decoder.decode(AXElement.self, from: data)
    
    // ID should be preserved
    #expect(decoded.id == element.id)
}
