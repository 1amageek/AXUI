import Testing
import Foundation
@testable import AXUI

@Test func testDumpIDConsistency() throws {
    // Create test elements with consistent properties
    let element1 = AXElement(
        systemRole: .button,
        description: "Save Button",
        identifier: "save-btn",
        roleDescription: "Button",
        help: nil,
        position: Point(x: 100, y: 200),
        size: Size(width: 80, height: 30),
        selected: false,
        enabled: true,
        focused: false
    )
    
    let element2 = AXElement(
        systemRole: .textField,
        description: "Username Field",
        identifier: "username-input",
        roleDescription: "Text Field",
        help: nil,
        position: Point(x: 50, y: 150),
        size: Size(width: 200, height: 25),
        selected: false,
        enabled: true,
        focused: false
    )
    
    // Create the same elements again to test consistency
    let duplicateElement1 = AXElement(
        systemRole: .button,
        description: "Save Button",
        identifier: "save-btn",
        roleDescription: "Button",
        help: nil,
        position: Point(x: 100, y: 200),
        size: Size(width: 80, height: 30),
        selected: false,
        enabled: true,
        focused: false
    )
    
    let duplicateElement2 = AXElement(
        systemRole: .textField,
        description: "Username Field",
        identifier: "username-input",
        roleDescription: "Text Field",
        help: nil,
        position: Point(x: 50, y: 150),
        size: Size(width: 200, height: 25),
        selected: false,
        enabled: true,
        focused: false
    )
    
    // Test ID consistency across multiple creations
    #expect(element1.id == duplicateElement1.id, "Same properties should generate same ID")
    #expect(element2.id == duplicateElement2.id, "Same properties should generate same ID")
    #expect(element1.id != element2.id, "Different elements should have different IDs")
    
    // Test that IDs are 4 characters long and alphanumeric
    #expect(element1.id.count == 12)
    #expect(element2.id.count == 12)
    #expect(element1.id.allSatisfy { $0.isLetter || $0.isNumber })
    #expect(element2.id.allSatisfy { $0.isLetter || $0.isNumber })
}

@Test func testDumpIDStabilityAcrossMultipleRuns() throws {
    // Test that creating elements with identical properties multiple times
    // always produces the same ID
    
    let role: SystemRole = .button
    let description = "Test Button"
    let identifier = "test-btn"
    let position = Point(x: 150, y: 300)
    let size = Size(width: 100, height: 35)
    
    var generatedIDs: [String] = []
    
    // Generate the same element 10 times
    for _ in 0..<10 {
        let element = AXElement(
            systemRole: role,
            description: description,
            identifier: identifier,
            roleDescription: "Button",
            help: nil,
            position: position,
            size: size,
            selected: false,
            enabled: true,
            focused: false
        )
        generatedIDs.append(element.id)
    }
    
    // All IDs should be identical
    let firstID = generatedIDs[0]
    for id in generatedIDs {
        #expect(id == firstID, "ID generation should be deterministic across multiple runs")
    }
    
    // Verify ID format
    #expect(firstID.count == 12)
    #expect(firstID.allSatisfy { $0.isLetter || $0.isNumber })
}

@Test func testDumpIDUniquenessWithVariations() throws {
    // Test that small changes in properties produce different IDs
    
    let baseElement = AXElement(
        systemRole: .button,
        description: "Base Button",
        identifier: "base-btn",
        roleDescription: "Button",
        help: nil,
        position: Point(x: 100, y: 200),
        size: Size(width: 80, height: 30),
        selected: false,
        enabled: true,
        focused: false
    )
    
    // Different role
    let differentRole = AXElement(
        systemRole: .textField, // Changed from .button
        description: "Base Button",
        identifier: "base-btn",
        roleDescription: "Button",
        help: nil,
        position: Point(x: 100, y: 200),
        size: Size(width: 80, height: 30),
        selected: false,
        enabled: true,
        focused: false
    )
    
    // Different identifier
    let differentIdentifier = AXElement(
        systemRole: .button,
        description: "Base Button",
        identifier: "different-btn", // Changed identifier
        roleDescription: "Button",
        help: nil,
        position: Point(x: 100, y: 200),
        size: Size(width: 80, height: 30),
        selected: false,
        enabled: true,
        focused: false
    )
    
    // Different position
    let differentPosition = AXElement(
        systemRole: .button,
        description: "Base Button",
        identifier: "base-btn",
        roleDescription: "Button",
        help: nil,
        position: Point(x: 101, y: 200), // Changed x position
        size: Size(width: 80, height: 30),
        selected: false,
        enabled: true,
        focused: false
    )
    
    // Different size
    let differentSize = AXElement(
        systemRole: .button,
        description: "Base Button",
        identifier: "base-btn",
        roleDescription: "Button",
        help: nil,
        position: Point(x: 100, y: 200),
        size: Size(width: 81, height: 30), // Changed width
        selected: false,
        enabled: true,
        focused: false
    )
    
    // All elements should have different IDs
    let allElements = [baseElement, differentRole, differentIdentifier, differentPosition, differentSize]
    let allIDs = allElements.map { $0.id }
    
    for i in 0..<allIDs.count {
        for j in (i+1)..<allIDs.count {
            #expect(allIDs[i] != allIDs[j], "Elements with different properties should have different IDs")
        }
    }
    
    // All IDs should be properly formatted
    for id in allIDs {
        #expect(id.count == 12)
        #expect(id.allSatisfy { $0.isLetter || $0.isNumber })
    }
}

@Test func testDumpIDWithNilValues() throws {
    // Test ID generation when some properties are nil
    
    let elementWithNils = AXElement(
        systemRole: .button,
        description: nil, // nil description
        identifier: nil,  // nil identifier
        roleDescription: "Button",
        help: nil,
        position: Point(x: 100, y: 200),
        size: Size(width: 80, height: 30),
        selected: false,
        enabled: true,
        focused: false
    )
    
    let anotherElementWithNils = AXElement(
        systemRole: .button,
        description: nil,
        identifier: nil,
        roleDescription: "Button",
        help: nil,
        position: Point(x: 100, y: 200),
        size: Size(width: 80, height: 30),
        selected: false,
        enabled: true,
        focused: false
    )
    
    // Same nil properties should produce same ID
    #expect(elementWithNils.id == anotherElementWithNils.id)
    
    // ID should still be properly formatted
    #expect(elementWithNils.id.count == 12)
    #expect(elementWithNils.id.allSatisfy { $0.isLetter || $0.isNumber })
    
    // Different from element with non-nil values
    let elementWithValues = AXElement(
        systemRole: .button,
        description: "Save",
        identifier: "save-btn",
        roleDescription: "Button",
        help: nil,
        position: Point(x: 100, y: 200),
        size: Size(width: 80, height: 30),
        selected: false,
        enabled: true,
        focused: false
    )
    
    #expect(elementWithNils.id != elementWithValues.id)
}