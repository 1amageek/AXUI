import Testing
import Foundation
@testable import AXUI

// MARK: - Query Matcher Advanced Tests (Fixes #5, #6, #16)

struct QueryMatcherAdvancedTests {

    // MARK: - Helpers

    private func makeElement(
        role: SystemRole = .button,
        description: String? = nil,
        identifier: String? = nil,
        position: Point? = nil,
        size: Size? = nil,
        selected: Bool = false,
        enabled: Bool = true,
        focused: Bool = false
    ) -> AXElement {
        AXElement(
            systemRole: role,
            description: description,
            identifier: identifier,
            roleDescription: nil,
            help: nil,
            position: position,
            size: size,
            selected: selected,
            enabled: enabled,
            focused: focused
        )
    }

    // MARK: - AND/OR/NOT priority (Fix #5)

    @Test("AND query combined with direct role field matches correctly")
    func andWithDirectRole() {
        let saveButton = makeElement(role: .button, description: "Save", identifier: "save-btn")
        let cancelButton = makeElement(role: .button, description: "Cancel", identifier: "cancel-btn")
        let saveField = makeElement(role: .textField, description: "Save", identifier: "save-field")

        // role=Button AND description=Save — should only match saveButton
        let query = AXQuery.parse("role=Button,description=Save")!
        let all = [saveButton, cancelButton, saveField]

        #expect(AXQueryMatcher.matches(element: saveButton, query: query, allElements: all))
        #expect(!AXQueryMatcher.matches(element: cancelButton, query: query, allElements: all))
        #expect(!AXQueryMatcher.matches(element: saveField, query: query, allElements: all))
    }

    @Test("OR query matches any of the alternatives")
    func orQueryMatching() {
        let button = makeElement(role: .button, description: "Save")
        let field = makeElement(role: .textField, description: "Name")
        let text = makeElement(role: .staticText, description: "Label")

        var orQ1 = AXQuery()
        orQ1.roleQuery = RoleQuery()
        orQ1.roleQuery?.equals = .button
        var orQ2 = AXQuery()
        orQ2.roleQuery = RoleQuery()
        orQ2.roleQuery?.equals = .field

        var query = AXQuery()
        query.orQueries = [Box(orQ1), Box(orQ2)]

        let all = [button, field, text]
        #expect(AXQueryMatcher.matches(element: button, query: query, allElements: all))
        #expect(AXQueryMatcher.matches(element: field, query: query, allElements: all))
        #expect(!AXQueryMatcher.matches(element: text, query: query, allElements: all))
    }

    @Test("NOT query excludes matching elements")
    func notQueryExclusion() {
        let enabledButton = makeElement(role: .button, description: "Save", enabled: true)
        let disabledButton = makeElement(role: .button, description: "Delete", enabled: false)

        // Match buttons that are NOT disabled (enabled=false)
        var notQ = AXQuery()
        notQ.enabled = false

        var query = AXQuery()
        query.roleQuery = RoleQuery()
        query.roleQuery?.equals = .button
        query.negatedQuery = Box(notQ)

        let all = [enabledButton, disabledButton]
        #expect(AXQueryMatcher.matches(element: enabledButton, query: query, allElements: all))
        #expect(!AXQueryMatcher.matches(element: disabledButton, query: query, allElements: all))
    }

    @Test("AND + direct fields: both must be satisfied")
    func andPlusDirectFields() {
        let element = makeElement(
            role: .button,
            description: "Submit",
            identifier: "submit-btn",
            position: Point(x: 100, y: 200),
            size: Size(width: 80, height: 30),
            enabled: true
        )

        var q1 = AXQuery()
        q1.roleQuery = RoleQuery()
        q1.roleQuery?.equals = .button
        var q2 = AXQuery()
        q2.description = "Submit"

        var query = AXQuery()
        query.enabled = true
        query.andQueries = [Box(q1), Box(q2)]

        #expect(AXQueryMatcher.matches(element: element, query: query, allElements: [element]))

        // Change enabled to false — should not match
        let disabledElement = makeElement(
            role: .button,
            description: "Submit",
            identifier: "submit-btn",
            enabled: false
        )
        #expect(!AXQueryMatcher.matches(element: disabledElement, query: query, allElements: [disabledElement]))
    }

    @Test("OR combined with direct description: both must hold")
    func orPlusDirectDescription() {
        // OR says role=Button or role=Field, direct says description=Save
        // Only an element with (role=Button OR role=Field) AND description=Save should match
        let saveButton = makeElement(role: .button, description: "Save")
        let saveField = makeElement(role: .textField, description: "Save")
        let cancelButton = makeElement(role: .button, description: "Cancel")
        let saveText = makeElement(role: .staticText, description: "Save")

        var orQ1 = AXQuery()
        orQ1.roleQuery = RoleQuery()
        orQ1.roleQuery?.equals = .button
        var orQ2 = AXQuery()
        orQ2.roleQuery = RoleQuery()
        orQ2.roleQuery?.equals = .field

        var query = AXQuery()
        query.description = "Save"
        query.orQueries = [Box(orQ1), Box(orQ2)]

        let all = [saveButton, saveField, cancelButton, saveText]
        #expect(AXQueryMatcher.matches(element: saveButton, query: query, allElements: all))
        #expect(AXQueryMatcher.matches(element: saveField, query: query, allElements: all))
        #expect(!AXQueryMatcher.matches(element: cancelButton, query: query, allElements: all),
                "Cancel does not match description=Save")
        #expect(!AXQueryMatcher.matches(element: saveText, query: query, allElements: all),
                "StaticText is neither Button nor Field")
    }

    // MARK: - Bounds precision (Fix #6)

    @Test("boundsIntersects uses Double precision, no Int truncation")
    func boundsIntersectsDoublePrecision() {
        // Element at fractional position
        let element = makeElement(
            role: .button,
            description: "Test",
            position: Point(x: 100.7, y: 200.3),
            size: Size(width: 50.5, height: 30.9)
        )

        // Element covers x: 100.7..151.2, y: 200.3..231.2
        // Query rect: x: 150..160, y: 230..240
        // Int truncation would give x: 100..150, y: 200..230 — no intersection
        // Double precision: x: 100.7..151.2 ∩ 150..160 = 150..151.2 — intersects!
        var query = AXQuery()
        query.boundsIntersects = [150, 230, 10, 10]

        #expect(AXQueryMatcher.matches(element: element, query: query, allElements: [element]))
    }

    @Test("boundsIntersects rejects non-overlapping rects")
    func boundsIntersectsNoOverlap() {
        let element = makeElement(
            role: .button,
            description: "Test",
            position: Point(x: 100, y: 200),
            size: Size(width: 50, height: 30)
        )

        // Element covers 100..150, 200..230
        // Query rect: 200..250, 300..330 — no overlap
        var query = AXQuery()
        query.boundsIntersects = [200, 300, 50, 30]

        #expect(!AXQueryMatcher.matches(element: element, query: query, allElements: [element]))
    }

    @Test("boundsContains point inside element")
    func boundsContainsPointInside() {
        let element = makeElement(
            role: .button,
            description: "Test",
            position: Point(x: 10, y: 20),
            size: Size(width: 100, height: 50)
        )

        // Point inside: (50, 40)
        var query = AXQuery()
        query.boundsContains = Point(x: 50, y: 40)

        #expect(AXQueryMatcher.matches(element: element, query: query, allElements: [element]))
    }

    @Test("boundsContains point outside element")
    func boundsContainsPointOutside() {
        let element = makeElement(
            role: .button,
            description: "Test",
            position: Point(x: 10, y: 20),
            size: Size(width: 100, height: 50)
        )

        // Point outside: (200, 200)
        var query = AXQuery()
        query.boundsContains = Point(x: 200, y: 200)

        #expect(!AXQueryMatcher.matches(element: element, query: query, allElements: [element]))
    }

    @Test("boundsContains uses Double precision at boundaries")
    func boundsContainsDoublePrecision() {
        let element = makeElement(
            role: .button,
            description: "Test",
            position: Point(x: 10.5, y: 20.5),
            size: Size(width: 100.5, height: 50.5)
        )

        // Point at right edge (10.5 + 100.5 = 111.0): should be on boundary
        var query = AXQuery()
        query.boundsContains = Point(x: 110, y: 40)

        #expect(AXQueryMatcher.matches(element: element, query: query, allElements: [element]))
    }

    // MARK: - Comma escape (Fix #16)

    @Test("Escaped comma in query value is treated as literal")
    func escapedCommaInValue() {
        let query = AXQuery.parse("description=Hello\\, World")
        #expect(query != nil)
        #expect(query?.description == "Hello, World")
    }

    @Test("Unescaped comma splits into multiple conditions")
    func unescapedCommaSplits() {
        let query = AXQuery.parse("role=Button,description=Save")
        #expect(query != nil)
        #expect(query?.andQueries?.count == 2)
    }

    @Test("Mixed escaped and unescaped commas")
    func mixedCommaHandling() {
        // "description=A\\, B,role=Button" → two conditions: description="A, B" AND role=Button
        let query = AXQuery.parse("description=A\\, B,role=Button")
        #expect(query != nil)
        #expect(query?.andQueries?.count == 2)
    }

    // MARK: - Size constraints with new query system

    @Test("Width and height constraints work with element properties")
    func sizeConstraints() {
        let element = makeElement(
            role: .button,
            description: "Test",
            position: Point(x: 0, y: 0),
            size: Size(width: 100, height: 40)
        )

        let queryMatch = AXQuery.parse("width>=80,height>=30")!
        #expect(AXQueryMatcher.matches(element: element, query: queryMatch, allElements: [element]))

        let queryNoMatch = AXQuery.parse("width>=200")!
        #expect(!AXQueryMatcher.matches(element: element, query: queryNoMatch, allElements: [element]))
    }
}
