import Testing
import Foundation
@testable import AXUI

@Test func testAXElementIDGeneration() {
    // Test basic ID generation
    let element = AXElement(
        role: .button,
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
    
    #expect(element.id.count == 4)
    #expect(element.id.allSatisfy { char in
        let alphanumeric = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
        return alphanumeric.contains(char)
    })
}

@Test func testAXElementIDConsistency() {
    // Create two elements with identical properties
    let element1 = AXElement(
        role: .textField,
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
        role: .textField,
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
        role: .button,
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
        role: .button,
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

@Test func testAXElementIDWithMissingProperties() {
    // Test with minimal properties
    let element1 = AXElement(
        role: .staticText,
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
    
    // Test with no properties (should generate random ID)
    let element2 = AXElement(
        role: nil,
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
    
    // Both should have 4-character IDs
    #expect(element1.id.count == 4)
    #expect(element2.id.count == 4)
    
    // Elements with no properties will have random IDs, so they should be different
    let element3 = AXElement(
        role: nil,
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
    
    #expect(element2.id != element3.id)
}

@Test func testAXElementIDSerialization() throws {
    let element = AXElement(
        role: .button,
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