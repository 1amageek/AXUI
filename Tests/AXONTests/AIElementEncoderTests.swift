import Testing
import Foundation
@testable import AXUI

@Test func testAIElementEncoderGeneratesIDs() throws {
    let encoder = AIElementEncoder()
    
    // Create an AXElement with known properties
    let axElement = AXElement(
        role: .button,
        description: "Save",
        identifier: "save-button",
        roleDescription: "Save Button",
        help: nil,
        position: Point(x: 100, y: 200),
        size: Size(width: 80, height: 30),
        selected: false,
        enabled: true,
        focused: false
    )
    
    // Convert to AIElement
    let aiElement = encoder.convert(from: axElement)
    
    // Verify the AIElement has an ID
    #expect(aiElement.id.count == 4)
    #expect(aiElement.id == axElement.id) // Should use the original AXElement ID
    
    // Verify other properties
    #expect(aiElement.role == .button)
    #expect(aiElement.value == "Save")
    #expect(aiElement.desc == "Save Button")
}

@Test func testAIElementEncoderWithChildren() throws {
    let encoder = AIElementEncoder()
    
    // Create parent element
    let child1 = AXElement(
        role: .text,
        description: "Child 1",
        identifier: nil,
        roleDescription: nil,
        help: nil,
        position: Point(x: 10, y: 10),
        size: Size(width: 50, height: 20),
        selected: false,
        enabled: true,
        focused: false
    )
    
    let child2 = AXElement(
        role: .button,
        description: "Child 2",
        identifier: "child2",
        roleDescription: nil,
        help: nil,
        position: Point(x: 70, y: 10),
        size: Size(width: 50, height: 20),
        selected: false,
        enabled: true,
        focused: false
    )
    
    let parent = AXElement(
        role: .group,
        description: nil,
        identifier: "parent",
        roleDescription: nil,
        help: nil,
        position: Point(x: 0, y: 0),
        size: Size(width: 200, height: 100),
        selected: false,
        enabled: true,
        focused: false,
        children: [child1, child2]
    )
    
    // Convert to AIElement
    let aiParent = encoder.convert(from: parent)
    
    // Verify parent has ID
    #expect(aiParent.id.count == 4)
    
    // Verify children have IDs
    if let children = aiParent.children {
        #expect(children.count == 2)
        
        if case .normal(let aiChild1) = children[0] {
            #expect(aiChild1.id.count == 4)
            #expect(aiChild1.id == child1.id)
            #expect(aiChild1.role == .text) // StaticText is normalized to Text
        }
        
        if case .normal(let aiChild2) = children[1] {
            #expect(aiChild2.id.count == 4)
            #expect(aiChild2.id == child2.id)
            #expect(aiChild2.role == .button)
        }
    }
}

@Test func testAIElementEncoderGroupOptimization() throws {
    let encoder = AIElementEncoder()
    
    // Create a group with only children (should use minimal representation)
    let child = AXElement(
        role: .button,
        description: "Test",
        identifier: "test-btn",
        roleDescription: nil,
        help: nil,
        position: nil,
        size: nil,
        selected: false,
        enabled: true,
        focused: false
    )
    
    let group = AXElement(
        role: .group,
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
    
    // Convert to AIElement
    let aiGroup = encoder.convert(from: group)
    
    // Group should still have an ID
    #expect(aiGroup.id.count == 4)
    
    // Group should have nil role (optimization)
    #expect(aiGroup.role == nil)
    
    // Should use minimal representation
    #expect(aiGroup.shouldUseGroupArrayRepresentation)
}

@Test func testAIElementEncoderJSONOutput() throws {
    let encoder = AIElementEncoder()
    
    let axElement = AXElement(
        role: .button,
        description: "Click Me",
        identifier: "click-button",
        roleDescription: nil,
        help: nil,
        position: Point(x: 50, y: 100),
        size: Size(width: 100, height: 40),
        selected: false,
        enabled: true,
        focused: false
    )
    
    let aiElement = encoder.convert(from: axElement)
    let json = try encoder.encode(aiElement, pretty: false)
    
    // JSON should contain the ID
    #expect(json.contains("\"id\":"))
    #expect(json.contains("\"\(aiElement.id)\""))
    
    // Verify JSON structure
    #expect(json.contains("\"role\":\"Button\""))
    #expect(json.contains("\"value\":\"Click Me\""))
    #expect(json.contains("\"bounds\":[50,100,100,40]"))
}

@Test func testAIElementEncoderIDConsistency() throws {
    let encoder = AIElementEncoder()
    
    // Create identical elements to test ID generation consistency
    let axElement1 = AXElement(
        role: .field,
        description: "Username",
        identifier: "username",
        roleDescription: nil,
        help: nil,
        position: Point(x: 0, y: 0),
        size: Size(width: 200, height: 30),
        selected: false,
        enabled: true,
        focused: false
    )
    
    let axElement2 = AXElement(
        role: .field,
        description: "Username",
        identifier: "username",
        roleDescription: nil,
        help: nil,
        position: Point(x: 0, y: 0),
        size: Size(width: 200, height: 30),
        selected: false,
        enabled: true,
        focused: false
    )
    
    let aiElement1 = encoder.convert(from: axElement1)
    let aiElement2 = encoder.convert(from: axElement2)
    
    // Should produce the same ID since they use the AXElement's ID
    #expect(aiElement1.id == aiElement2.id)
    #expect(aiElement1.id == axElement1.id)
    #expect(aiElement2.id == axElement2.id)
}
