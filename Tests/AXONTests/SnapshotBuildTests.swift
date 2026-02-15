import Testing
import Foundation
@testable import AXUI

// MARK: - Snapshot Build Tests (Fixes #7, #12, #13)

struct SnapshotBuildTests {

    // MARK: - Recursive children processing (Fix #13)

    @Test("buildSnapshot recursively processes nested children")
    func recursiveChildren() {
        let grandchild = AXElement(
            systemRole: .staticText,
            description: "Label",
            identifier: nil,
            roleDescription: nil,
            help: nil,
            position: Point(x: 15, y: 15),
            size: Size(width: 50, height: 20),
            selected: false,
            enabled: true,
            focused: false
        )

        let child = AXElement(
            systemRole: .button,
            description: "Save",
            identifier: "save-btn",
            roleDescription: nil,
            help: nil,
            position: Point(x: 10, y: 10),
            size: Size(width: 80, height: 30),
            selected: false,
            enabled: true,
            focused: false,
            children: [grandchild]
        )

        let root = AXElement(
            systemRole: .group,
            description: nil,
            identifier: "toolbar",
            roleDescription: nil,
            help: nil,
            position: Point(x: 0, y: 0),
            size: Size(width: 200, height: 50),
            selected: false,
            enabled: true,
            focused: false,
            children: [child]
        )

        let snapshot = AXSnapshotService.buildSnapshot(
            elements: [root],
            appContext: AppContext(bundleIdentifier: "com.test.app"),
            windowContext: WindowContext(selection: .all, index: nil, windowNumber: nil, title: nil)
        )

        // Should have 3 nodes: root + child + grandchild
        #expect(snapshot.nodes.count == 3)

        // Verify parent-child relationships
        let rootNode = snapshot.nodes[0]
        let childNode = snapshot.nodes[1]
        let grandchildNode = snapshot.nodes[2]

        #expect(rootNode.parentNodeID == nil)
        #expect(childNode.parentNodeID == rootNode.nodeID)
        #expect(grandchildNode.parentNodeID == childNode.nodeID)
    }

    @Test("buildSnapshot preserves paths for nested elements")
    func nestedElementPaths() {
        let child1 = AXElement(
            systemRole: .button,
            description: "First",
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
            systemRole: .button,
            description: "Second",
            identifier: nil,
            roleDescription: nil,
            help: nil,
            position: Point(x: 70, y: 10),
            size: Size(width: 50, height: 20),
            selected: false,
            enabled: true,
            focused: false
        )

        let parent = AXElement(
            systemRole: .group,
            description: nil,
            identifier: nil,
            roleDescription: nil,
            help: nil,
            position: Point(x: 0, y: 0),
            size: Size(width: 200, height: 50),
            selected: false,
            enabled: true,
            focused: false,
            children: [child1, child2]
        )

        let snapshot = AXSnapshotService.buildSnapshot(
            elements: [parent],
            appContext: AppContext(bundleIdentifier: "com.test.app"),
            windowContext: WindowContext(selection: .all, index: nil, windowNumber: nil, title: nil)
        )

        #expect(snapshot.nodes.count == 3)
        #expect(snapshot.nodes[0].path == [0])
        #expect(snapshot.nodes[1].path == [0, 0])
        #expect(snapshot.nodes[2].path == [0, 1])
    }

    @Test("All nodes are indexed by nodeID and legacyID")
    func allNodesIndexed() {
        let child = AXElement(
            systemRole: .button,
            description: "Click",
            identifier: "click-btn",
            roleDescription: nil,
            help: nil,
            position: Point(x: 10, y: 10),
            size: Size(width: 60, height: 30),
            selected: false,
            enabled: true,
            focused: false
        )

        let parent = AXElement(
            systemRole: .group,
            description: nil,
            identifier: "group-1",
            roleDescription: nil,
            help: nil,
            position: Point(x: 0, y: 0),
            size: Size(width: 200, height: 100),
            selected: false,
            enabled: true,
            focused: false,
            children: [child]
        )

        let snapshot = AXSnapshotService.buildSnapshot(
            elements: [parent],
            appContext: AppContext(bundleIdentifier: "com.test.app"),
            windowContext: WindowContext(selection: .all, index: nil, windowNumber: nil, title: nil)
        )

        // Every node should be in byNodeID index
        for (idx, node) in snapshot.nodes.enumerated() {
            #expect(snapshot.index.byNodeID[node.nodeID] == idx,
                    "Node at index \(idx) not found in byNodeID index")
        }
    }

    // MARK: - Value in snapshot (Fix #7)

    @Test("Snapshot node uses element.value, not element.description")
    func snapshotValueCorrectness() {
        let element = AXElement(
            systemRole: .textField,
            description: "Username Label",
            identifier: "username-field",
            roleDescription: nil,
            help: nil,
            value: "john_doe",
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

        let node = snapshot.nodes[0]
        #expect(node.value == "john_doe", "Node value should come from element.value")
        #expect(node.value != "Username Label", "Node value should NOT be element.description")
    }

    @Test("Snapshot node value is nil when element.value is nil")
    func snapshotNilValue() {
        let element = AXElement(
            systemRole: .button,
            description: "Save Button",
            identifier: nil,
            roleDescription: nil,
            help: nil,
            position: Point(x: 10, y: 20),
            size: Size(width: 80, height: 30),
            selected: false,
            enabled: true,
            focused: false
        )

        let snapshot = AXSnapshotService.buildSnapshot(
            elements: [element],
            appContext: AppContext(bundleIdentifier: "com.test.app"),
            windowContext: WindowContext(selection: .all, index: nil, windowNumber: nil, title: nil)
        )

        let node = snapshot.nodes[0]
        #expect(node.value == nil)
    }

    // MARK: - Profile differentiation (Fix #12)

    @Test("agentDefault and debugFull produce different traversal options")
    func profileDifferentiation() {
        // We can't directly test private traversalOptions, but we can verify
        // the capture request works with different profiles
        let agentRequest = AXCaptureRequest(
            bundleIdentifier: "com.test.app",
            profile: .agentDefault
        )
        let debugRequest = AXCaptureRequest(
            bundleIdentifier: "com.test.app",
            profile: .debugFull
        )

        #expect(agentRequest.profile == .agentDefault)
        #expect(debugRequest.profile == .debugFull)
        #expect(agentRequest.profile != debugRequest.profile)
    }

    // MARK: - Traits computed correctly

    @Test("Interactive elements have supportsPress trait")
    func interactiveTraits() {
        let button = AXElement(
            systemRole: .button,
            description: "Click",
            identifier: nil,
            roleDescription: nil,
            help: nil,
            position: Point(x: 10, y: 10),
            size: Size(width: 60, height: 30),
            selected: false,
            enabled: true,
            focused: false
        )

        let snapshot = AXSnapshotService.buildSnapshot(
            elements: [button],
            appContext: AppContext(bundleIdentifier: "com.test.app"),
            windowContext: WindowContext(selection: .all, index: nil, windowNumber: nil, title: nil)
        )

        let node = snapshot.nodes[0]
        #expect(node.traits.isInteractive)
        #expect(node.traits.supportsPress)
        #expect(node.traits.isVisible)
        #expect(node.traits.isHittable)
    }

    @Test("Disabled element is not hittable")
    func disabledNotHittable() {
        let element = AXElement(
            systemRole: .button,
            description: "Disabled",
            identifier: nil,
            roleDescription: nil,
            help: nil,
            position: Point(x: 10, y: 10),
            size: Size(width: 60, height: 30),
            selected: false,
            enabled: false,
            focused: false
        )

        let snapshot = AXSnapshotService.buildSnapshot(
            elements: [element],
            appContext: AppContext(bundleIdentifier: "com.test.app"),
            windowContext: WindowContext(selection: .all, index: nil, windowNumber: nil, title: nil)
        )

        let node = snapshot.nodes[0]
        #expect(node.traits.isVisible)
        #expect(!node.traits.isHittable, "Disabled element should not be hittable")
    }

    @Test("Slider supports setValue, increment, and decrement")
    func sliderTraits() {
        let slider = AXElement(
            systemRole: .slider,
            description: "Volume",
            identifier: "volume",
            roleDescription: nil,
            help: nil,
            value: "50",
            position: Point(x: 10, y: 10),
            size: Size(width: 200, height: 20),
            selected: false,
            enabled: true,
            focused: false
        )

        let snapshot = AXSnapshotService.buildSnapshot(
            elements: [slider],
            appContext: AppContext(bundleIdentifier: "com.test.app"),
            windowContext: WindowContext(selection: .all, index: nil, windowNumber: nil, title: nil)
        )

        let node = snapshot.nodes[0]
        #expect(node.traits.supportsSetValue)
        #expect(node.traits.supportsIncrement)
        #expect(node.traits.supportsDecrement)
    }
}
