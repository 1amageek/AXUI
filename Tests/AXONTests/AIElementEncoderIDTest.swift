import Testing
import Foundation
@testable import AXUI

@Test func testAIElementEncoderIDGeneration() throws {
    // Create test AXElements
    let child1 = AXElement(
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
    
    let child2 = AXElement(
        systemRole: .button,
        description: "Cancel",
        identifier: "cancel-btn",
        roleDescription: "Cancel Button",
        help: nil,
        position: Point(x: 200, y: 200),
        size: Size(width: 80, height: 30),
        selected: false,
        enabled: true,
        focused: false
    )
    
    let parent = AXElement(
        systemRole: .group,
        description: nil,
        identifier: "button-group",
        roleDescription: nil,
        help: nil,
        position: Point(x: 50, y: 150),
        size: Size(width: 300, height: 100),
        selected: false,
        enabled: true,
        focused: false,
        children: [child1, child2]
    )
    
    // Create encoder and convert
    let encoder = AIElementEncoder()
    let aiElement = encoder.convert(from: parent)
    
    // Verify parent has ID
    #expect(aiElement.id.count == 4)
    #expect(aiElement.id == parent.id) // Should use the AXElement's ID
    
    // Verify children have IDs
    #expect(aiElement.children != nil)
    if let children = aiElement.children {
        #expect(children.count == 2)
        
        if case .normal(let aiChild1) = children[0] {
            #expect(aiChild1.id.count == 4)
            #expect(aiChild1.id == child1.id)
            #expect(aiChild1.role == .button)
            #expect(aiChild1.value == "Save")
        }
        
        if case .normal(let aiChild2) = children[1] {
            #expect(aiChild2.id.count == 4)
            #expect(aiChild2.id == child2.id)
            #expect(aiChild2.role == .button)
            #expect(aiChild2.value == "Cancel")
        }
    }
    
    // Test JSON encoding includes IDs
    let jsonString = try encoder.encode(aiElement, pretty: false)
    #expect(jsonString.contains("\"id\":"))
    #expect(jsonString.contains("\"\(aiElement.id)\""))
    
    // Pretty print for verification
    let prettyJSON = try encoder.encode(aiElement, pretty: true)
    print("AIElement with IDs:")
    print(prettyJSON)
}