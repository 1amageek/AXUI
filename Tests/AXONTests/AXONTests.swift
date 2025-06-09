import Testing
import Foundation
@testable import AXUI

// MARK: - Core Data Structure Tests

@Test func testUINodeStateCreation() {
    // Test default state omission
    let defaultState = UINodeState.create()
    #expect(defaultState == nil)
    
    // Test non-default state creation
    let selectedState = UINodeState.create(selected: true)
    #expect(selectedState?.selected == true)
    #expect(selectedState?.enabled == nil)
    #expect(selectedState?.focused == nil)
}

@Test func testUINodeObjectCreation() {
    let node = UINodeObject(
        role: "Button",
        value: "Click me",
        bounds: [10, 20, 100, 50],
        children: []
    )
    
    #expect(node.role == "Button")
    #expect(node.value == "Click me")
    #expect(node.bounds == [10, 20, 100, 50])
    #expect(node.children == nil)
}

// MARK: - Parser Tests

@Test func testAXParserBasicProperties() throws {
    let axDump = """
    Role: AXButton
    Value: Click me
    Position: (10, 20)
    Size: (100, 50)
    Selected: false
    Enabled: true
    Focused: false
    """
    
    let properties = try AXParser.parse(content: axDump)
    
    #expect(properties.role == "AXButton")
    #expect(properties.value == "Click me")
    #expect(properties.position?.x == 10)
    #expect(properties.position?.y == 20)
    #expect(properties.size?.width == 100)
    #expect(properties.size?.height == 50)
    #expect(properties.selected == false)
    #expect(properties.enabled == true)
    #expect(properties.focused == false)
}

@Test func testAXParserEmptyInput() {
    #expect(throws: AXParseError.emptyInput) {
        try AXParser.parse(lines: [])
    }
}

// MARK: - Conversion Tests

@Test func testAXPropertiesToUINodeConversion() {
    let axProps = AXProperties(
        role: "AXButton",
        value: "Click me",
        position: CGPoint(x: 10, y: 20),
        size: CGSize(width: 100, height: 50),
        selected: false,
        enabled: true,
        focused: false
    )
    
    let uiNode = axProps.toUINode()
    
    guard case .normal(let nodeObj) = uiNode else {
        Issue.record("Expected normal node")
        return
    }
    
    #expect(nodeObj.role == "Button") // AX prefix removed
    #expect(nodeObj.value == "Click me")
    #expect(nodeObj.bounds == [10, 20, 100, 50])
    #expect(nodeObj.state == nil) // Default state omitted
}

@Test func testGroupOptimizationMinimal() {
    let axProps = AXProperties(
        role: "AXGroup",
        children: [
            AXProperties(role: "AXStaticText", value: "Text 1"),
            AXProperties(role: "AXStaticText", value: "Text 2")
        ]
    )
    
    let uiNode = axProps.toUINode()
    
    guard case .group(let children) = uiNode else {
        Issue.record("Expected group array (G-Minimal)")
        return
    }
    
    #expect(children.count == 2)
}

@Test func testGroupOptimizationObject() {
    let axProps = AXProperties(
        role: "AXGroup",
        value: "Group Title", // Additional attribute
        children: [
            AXProperties(role: "AXStaticText", value: "Text 1")
        ]
    )
    
    let uiNode = axProps.toUINode()
    
    guard case .normal(let nodeObj) = uiNode else {
        Issue.record("Expected normal node (G-Object)")
        return
    }
    
    #expect(nodeObj.role == nil) // Group role omitted
    #expect(nodeObj.value == "Group Title")
    #expect(nodeObj.children?.count == 1)
}

// MARK: - JSON Serialization Tests

@Test func testJSONSerialization() throws {
    let node = UINode.normal(UINodeObject(
        role: "Window",
        bounds: [0, 0, 800, 600],
        children: [
            .normal(UINodeObject(
                role: "Button",
                value: "Click me",
                bounds: [10, 10, 100, 30],
                children: []
            ))
        ]
    ))
    
    let jsonString = try node.toMinifiedJSON()
    #expect(!jsonString.isEmpty)
    #expect(!jsonString.contains("\n")) // Should be minified
    
    // Test round-trip by comparing structure
    let reconstructed = try UINode.fromJSON(jsonString)
    
    guard case .normal(let originalObj) = node,
          case .normal(let reconstructedObj) = reconstructed else {
        Issue.record("Expected normal nodes")
        return
    }
    
    #expect(originalObj.role == reconstructedObj.role)
    #expect(originalObj.bounds == reconstructedObj.bounds)
    #expect(originalObj.children?.count == reconstructedObj.children?.count)
}

@Test func testJSONSerializationGroupMinimal() throws {
    let groupNode = UINode.group([
        .normal(UINodeObject(role: "StaticText", value: "Text 1", children: [])),
        .normal(UINodeObject(role: "StaticText", value: "Text 2", children: []))
    ])
    
    let jsonString = try groupNode.toMinifiedJSON()
    #expect(jsonString.hasPrefix("[")) // Should be an array
    
    // Test round-trip
    let reconstructed = try UINode.fromJSON(jsonString)
    guard case .group(let children) = reconstructed else {
        Issue.record("Expected group after round-trip")
        return
    }
    #expect(children.count == 2)
}

// MARK: - Compression Tests

@Test func testJSONCompression() throws {
    let node = UINode.normal(UINodeObject(
        role: "Window",
        value: "Large window with lots of content to compress",
        children: []
    ))
    
    let compressedData = try node.toCompressedJSON()
    #expect(compressedData.count > 0)
    
    // Test decompression by comparing structure
    let decompressed = try UINode.fromCompressedJSON(compressedData)
    
    guard case .normal(let originalObj) = node,
          case .normal(let decompressedObj) = decompressed else {
        Issue.record("Expected normal nodes")
        return
    }
    
    #expect(originalObj.role == decompressedObj.role)
    #expect(originalObj.value == decompressedObj.value)
    #expect(originalObj.children?.count == decompressedObj.children?.count)
}

// MARK: - Integration Tests

@Test func testConvenienceAPIs() throws {
    let axDump = """
    Role: AXButton
    Value: Test Button
    """
    
    // Test minified conversion
    let minified = try AXConverter.convert(axDump: axDump)
    #expect(!minified.contains("\n"))
    #expect(minified.contains("Button")) // Should contain role without AX prefix
    #expect(minified.contains("Test Button")) // Should contain value
    
    // Test pretty conversion
    let pretty = try AXConverter.convertToPrettyJSON(axDump: axDump)
    #expect(pretty.contains("\n"))
    
    // Test compressed conversion
    let compressed = try AXConverter.convertToCompressed(axDump: axDump)
    #expect(compressed.count > 0)
}
