import Testing
import Foundation
@testable import AXUI

struct AXSnapshotServiceTests {

    @Test("Stable ID is deterministic and 12 characters")
    func stableIDDeterminism() {
        let element1 = AXElement(
            systemRole: .button,
            description: "Save",
            identifier: "save-button",
            roleDescription: "Save Button",
            help: "Save current document",
            position: Point(x: 120, y: 220),
            size: Size(width: 80, height: 30),
            selected: false,
            enabled: true,
            focused: false
        )

        let element2 = AXElement(
            systemRole: .button,
            description: "Save",
            identifier: "save-button",
            roleDescription: "Save Button",
            help: "Save current document",
            position: Point(x: 120, y: 220),
            size: Size(width: 80, height: 30),
            selected: false,
            enabled: true,
            focused: false
        )

        #expect(element1.id.count == 12)
        #expect(element1.id == element2.id)
    }

    @Test("Snapshot resolve supports exact lookup")
    func snapshotResolve() {
        let element = AXElement(
            systemRole: .field,
            description: "Search",
            identifier: "search-field",
            roleDescription: "Search Field",
            help: nil,
            position: Point(x: 50, y: 80),
            size: Size(width: 200, height: 32),
            selected: false,
            enabled: true,
            focused: true
        )

        let snapshot = AXSnapshotService.buildSnapshot(
            elements: [element],
            appContext: AppContext(bundleIdentifier: "com.example.app"),
            windowContext: WindowContext(
                selection: .index(0),
                index: 0,
                windowNumber: 123,
                title: "Main"
            ),
            capturedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let exact = AXSnapshotService.resolve(nodeID: element.id, in: snapshot)
        #expect(exact.kind == .exact)
        #expect(exact.node?.nodeID == element.id)
    }

    @Test("Inspect returns center point and actions")
    func snapshotInspect() {
        let element = AXElement(
            systemRole: .button,
            description: "Submit",
            identifier: "submit",
            roleDescription: "Submit Button",
            help: nil,
            position: Point(x: 10, y: 20),
            size: Size(width: 100, height: 40),
            selected: false,
            enabled: true,
            focused: false
        )

        let snapshot = AXSnapshotService.buildSnapshot(
            elements: [element],
            appContext: AppContext(bundleIdentifier: "com.example.app"),
            windowContext: WindowContext(
                selection: .all,
                index: nil,
                windowNumber: nil,
                title: nil
            )
        )

        let inspection = AXSnapshotService.inspect(nodeID: element.id, in: snapshot)
        #expect(inspection != nil)
        #expect(inspection?.centerPoint?.x == 60)
        #expect(inspection?.centerPoint?.y == 40)
        #expect(inspection?.actions.contains(.press) == true)
    }

    @Test("parseResult reports regex and key errors")
    func parseResultErrors() {
        let invalidRegex = AXQuery.parseResult("description~=[")
        switch invalidRegex {
        case .success:
            Issue.record("Expected invalid regex parse failure")
        case .failure(let error):
            switch error {
            case .invalidRegex(let key, _):
                #expect(key == "description")
            default:
                Issue.record("Unexpected parse error: \(error)")
            }
        }

        let unsupportedKey = AXQuery.parseResult("foo=bar")
        switch unsupportedKey {
        case .success:
            Issue.record("Expected unsupported key parse failure")
        case .failure(let error):
            #expect(error == .unsupportedKey("foo"))
        }
    }
}
