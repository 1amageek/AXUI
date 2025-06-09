import Testing
import Foundation
@testable import AXUI

// MARK: - Comprehensive State Handling Tests

@Test func testStateCreationWithAllCombinations() {
    // Test 1: All default values - should return nil
    let defaultState = UINodeState.create(selected: false, enabled: true, focused: false)
    #expect(defaultState == nil)
    
    // Test 2: Only selected is non-default
    let selectedState = UINodeState.create(selected: true, enabled: true, focused: false)
    #expect(selectedState?.selected == true)
    #expect(selectedState?.enabled == nil)
    #expect(selectedState?.focused == nil)
    
    // Test 3: Only enabled is non-default (disabled)
    let disabledState = UINodeState.create(selected: false, enabled: false, focused: false)
    #expect(disabledState?.selected == nil)
    #expect(disabledState?.enabled == false)
    #expect(disabledState?.focused == nil)
    
    // Test 4: Only focused is non-default
    let focusedState = UINodeState.create(selected: false, enabled: true, focused: true)
    #expect(focusedState?.selected == nil)
    #expect(focusedState?.enabled == nil)
    #expect(focusedState?.focused == true)
    
    // Test 5: Multiple non-default values
    let multiState = UINodeState.create(selected: true, enabled: false, focused: true)
    #expect(multiState?.selected == true)
    #expect(multiState?.enabled == false)
    #expect(multiState?.focused == true)
    
    // Test 6: Selected and focused (enabled is default)
    let selectedFocusedState = UINodeState.create(selected: true, enabled: true, focused: true)
    #expect(selectedFocusedState?.selected == true)
    #expect(selectedFocusedState?.enabled == nil)
    #expect(selectedFocusedState?.focused == true)
}

@Test func testStateIsDefaultMethod() {
    // Test default state
    let defaultState = UINodeState(selected: false, enabled: true, focused: false)
    #expect(defaultState.isDefault == true)
    
    // Test non-default states
    let selectedState = UINodeState(selected: true, enabled: true, focused: false)
    #expect(selectedState.isDefault == false)
    
    let disabledState = UINodeState(selected: false, enabled: false, focused: false)
    #expect(disabledState.isDefault == false)
    
    let focusedState = UINodeState(selected: false, enabled: true, focused: true)
    #expect(focusedState.isDefault == false)
    
    // Test with nil values (should not be considered default)
    let partialState = UINodeState(selected: true, enabled: nil, focused: nil)
    #expect(partialState.isDefault == false)
}

@Test func testAXPropertiesToUINodeStateConversion() {
    // Test 1: All default values
    let defaultProps = AXProperties(
        role: "AXButton",
        selected: false,
        enabled: true,
        focused: false
    )
    let defaultNode = defaultProps.toUINode()
    guard case .normal(let defaultObj) = defaultNode else {
        Issue.record("Expected normal node")
        return
    }
    #expect(defaultObj.state == nil)
    
    // Test 2: Selected button
    let selectedProps = AXProperties(
        role: "AXButton",
        selected: true,
        enabled: true,
        focused: false
    )
    let selectedNode = selectedProps.toUINode()
    guard case .normal(let selectedObj) = selectedNode else {
        Issue.record("Expected normal node")
        return
    }
    #expect(selectedObj.state?.selected == true)
    #expect(selectedObj.state?.enabled == nil)
    #expect(selectedObj.state?.focused == nil)
    
    // Test 3: Disabled and focused button
    let disabledFocusedProps = AXProperties(
        role: "AXButton",
        selected: false,
        enabled: false,
        focused: true
    )
    let disabledFocusedNode = disabledFocusedProps.toUINode()
    guard case .normal(let disabledFocusedObj) = disabledFocusedNode else {
        Issue.record("Expected normal node")
        return
    }
    #expect(disabledFocusedObj.state?.selected == nil)
    #expect(disabledFocusedObj.state?.enabled == false)
    #expect(disabledFocusedObj.state?.focused == true)
}

@Test func testStateJSONSerialization() throws {
    // Test 1: Node with default state (should not include state in JSON)
    let nodeWithDefaultState = UINode.normal(UINodeObject(
        role: "Button",
        value: "Click me",
        state: nil
    ))
    
    let defaultJSON = try nodeWithDefaultState.toMinifiedJSON()
    #expect(!defaultJSON.contains("\"state\""))
    
    // Test 2: Node with selected state
    let selectedState = UINodeState(selected: true, enabled: nil, focused: nil)
    let nodeWithSelectedState = UINode.normal(UINodeObject(
        role: "Button",
        value: "Click me",
        state: selectedState
    ))
    
    let selectedJSON = try nodeWithSelectedState.toMinifiedJSON()
    #expect(selectedJSON.contains("\"state\""))
    #expect(selectedJSON.contains("\"selected\":true"))
    #expect(!selectedJSON.contains("\"enabled\""))
    #expect(!selectedJSON.contains("\"focused\""))
    
    // Test 3: Node with multiple state values
    let multiState = UINodeState(selected: true, enabled: false, focused: true)
    let nodeWithMultiState = UINode.normal(UINodeObject(
        role: "Button",
        value: "Click me",
        state: multiState
    ))
    
    let multiJSON = try nodeWithMultiState.toMinifiedJSON()
    #expect(multiJSON.contains("\"selected\":true"))
    #expect(multiJSON.contains("\"enabled\":false"))
    #expect(multiJSON.contains("\"focused\":true"))
}

@Test func testStateRoundTripSerialization() throws {
    // Create a complex node with various state combinations
    let complexNode = UINode.normal(UINodeObject(
        role: "Window",
        children: [
            .normal(UINodeObject(
                role: "Button",
                value: "Selected Button",
                state: UINodeState(selected: true, enabled: nil, focused: nil)
            )),
            .normal(UINodeObject(
                role: "Button",
                value: "Disabled Button",
                state: UINodeState(selected: nil, enabled: false, focused: nil)
            )),
            .normal(UINodeObject(
                role: "TextField",
                value: "Focused Field",
                state: UINodeState(selected: nil, enabled: nil, focused: true)
            )),
            .normal(UINodeObject(
                role: "Button",
                value: "Normal Button",
                state: nil // Default state
            ))
        ]
    ))
    
    // Serialize to JSON
    let json = try complexNode.toMinifiedJSON()
    
    // Deserialize back
    let reconstructed = try UINode.fromJSON(json)
    
    // Verify structure
    guard case .normal(let rootObj) = reconstructed,
          let children = rootObj.children else {
        Issue.record("Expected normal node with children")
        return
    }
    
    #expect(children.count == 4)
    
    // Check each child's state
    if case .normal(let child0) = children[0] {
        #expect(child0.state?.selected == true)
        #expect(child0.state?.enabled == nil)
        #expect(child0.state?.focused == nil)
    }
    
    if case .normal(let child1) = children[1] {
        #expect(child1.state?.selected == nil)
        #expect(child1.state?.enabled == false)
        #expect(child1.state?.focused == nil)
    }
    
    if case .normal(let child2) = children[2] {
        #expect(child2.state?.selected == nil)
        #expect(child2.state?.enabled == nil)
        #expect(child2.state?.focused == true)
    }
    
    if case .normal(let child3) = children[3] {
        #expect(child3.state == nil)
    }
}

@Test func testAXParserStateHandling() throws {
    // Test parsing various state combinations from AX dump
    let axDump = """
    Role: AXWindow
      Child[0]:
        Role: AXButton
        Value: Selected and Disabled
        Selected: true
        Enabled: false
        Focused: false
      Child[1]:
        Role: AXTextField
        Value: Focused Field
        Selected: false
        Enabled: true
        Focused: true
      Child[2]:
        Role: AXButton
        Value: Normal Button
        Selected: false
        Enabled: true
        Focused: false
    """
    
    let properties = try AXParser.parse(content: axDump)
    
    // Check root window
    #expect(properties.role == "AXWindow")
    #expect(properties.children.count == 3)
    
    // Check first child (selected and disabled)
    let child0 = properties.children[0]
    #expect(child0.selected == true)
    #expect(child0.enabled == false)
    #expect(child0.focused == false)
    
    // Check second child (focused)
    let child1 = properties.children[1]
    #expect(child1.selected == false)
    #expect(child1.enabled == true)
    #expect(child1.focused == true)
    
    // Check third child (all defaults)
    let child2 = properties.children[2]
    #expect(child2.selected == false)
    #expect(child2.enabled == true)
    #expect(child2.focused == false)
    
    // Convert to UI nodes and verify state handling
    let uiNode = properties.toUINode()
    guard case .normal(let windowObj) = uiNode,
          let uiChildren = windowObj.children else {
        Issue.record("Expected window with children")
        return
    }
    
    // First child should have both selected and enabled in state
    if case .normal(let uiChild0) = uiChildren[0] {
        #expect(uiChild0.state?.selected == true)
        #expect(uiChild0.state?.enabled == false)
        #expect(uiChild0.state?.focused == nil)
    }
    
    // Second child should only have focused in state
    if case .normal(let uiChild1) = uiChildren[1] {
        #expect(uiChild1.state?.selected == nil)
        #expect(uiChild1.state?.enabled == nil)
        #expect(uiChild1.state?.focused == true)
    }
    
    // Third child should have no state (all defaults)
    if case .normal(let uiChild2) = uiChildren[2] {
        #expect(uiChild2.state == nil)
    }
}