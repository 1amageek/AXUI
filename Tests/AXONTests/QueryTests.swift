import Testing
@testable import AXUI

// MARK: - Query System Tests

struct QueryTests {
    
    @Test("Single condition query parsing")
    func testSingleConditionQueryParsing() {
        let query = AXQuery.parse("role=Button")
        
        #expect(query != nil)
        #expect(query?.roleQuery?.equals == .button)
        #expect(query?.andQueries == nil)
    }
    
    @Test("Flexible role matching")
    func testFlexibleRoleMatching() {
        // Test various role formats that should all map to .field
        let testCases = [
            "role=Field",
            "role=field", 
            "role=TextField",
            "role=textField",
            "role=TextArea",
            "role=input"
        ]
        
        for testCase in testCases {
            let query = AXQuery.parse(testCase)
            #expect(query != nil, "Failed to parse: \(testCase)")
            #expect(query?.roleQuery?.equals == .field, "Expected .field for: \(testCase), got: \(String(describing: query?.roleQuery?.equals))")
        }
        
        // Test button variations
        let buttonQuery = AXQuery.parse("role=btn")
        #expect(buttonQuery?.roleQuery?.equals == .button)
    }
    
    @Test("Multiple condition query parsing")
    func testMultipleConditionQueryParsing() {
        let query = AXQuery.parse("role=Button,description=Save")
        
        #expect(query != nil)
        #expect(query?.andQueries?.count == 2)
        
        // Check the first condition (role=Button)
        if let firstQuery = query?.andQueries?.first?.value {
            #expect(firstQuery.roleQuery?.equals == .button)
        }
        
        // Check the second condition (description=Save)
        if let secondQuery = query?.andQueries?.last?.value {
            #expect(secondQuery.description == "Save")
        }
    }
    
    @Test("Contains query parsing")
    func testContainsQueryParsing() {
        let query = AXQuery.parse("description*=search,identifier*=login")
        
        #expect(query != nil)
        #expect(query?.andQueries?.count == 2)
        
        // Check for description contains search
        let hasDescriptionContains = query?.andQueries?.contains { subQuery in
            subQuery.value.descriptionContains == "search"
        } ?? false
        #expect(hasDescriptionContains)
        
        // Check for identifier contains login
        let hasIdentifierContains = query?.andQueries?.contains { subQuery in
            subQuery.value.identifierContains == "login"
        } ?? false
        #expect(hasIdentifierContains)
    }
    
    @Test("Regex query parsing")
    func testRegexQueryParsing() {
        let query = AXQuery.parse("description~=.*[Ss]ave.*")
        
        #expect(query != nil)
        #expect(query?.descriptionRegex == ".*[Ss]ave.*")
    }
    
    @Test("State query parsing")
    func testStateQueryParsing() {
        let query = AXQuery.parse("enabled=true,selected=false,focused=true")
        
        #expect(query != nil)
        #expect(query?.andQueries?.count == 3)
        
        // Check that all expected state conditions are present
        let enabledQuery = query?.andQueries?.first { $0.value.enabled == true }
        let selectedQuery = query?.andQueries?.first { $0.value.selected == false }
        let focusedQuery = query?.andQueries?.first { $0.value.focused == true }
        
        #expect(enabledQuery != nil)
        #expect(selectedQuery != nil)
        #expect(focusedQuery != nil)
    }
    
    @Test("Query builder methods")
    func testQueryBuilderMethods() {
        let buttonQuery = AXQuery.button(description: "Save")
        #expect(buttonQuery.roleQuery?.equals == .button)
        #expect(buttonQuery.description == "Save")
        
        let textFieldQuery = AXQuery.textField(identifier: "username")
        #expect(textFieldQuery.roleQuery?.equals == .field)
        #expect(textFieldQuery.identifier == "username")
        
        let interactiveQuery = AXQuery.interactive()
        #expect(interactiveQuery.orQueries != nil)
        #expect(interactiveQuery.orQueries?.count ?? 0 > 0)
    }
    
    @Test("Element matching")
    func testElementMatching() {
        let element = AXElement(
            systemRole: .button,
            description: "Save",
            identifier: "save-btn",
            roleDescription: nil,
            help: nil,
            position: Point(x: 10, y: 20),
            size: Size(width: 100, height: 30),
            selected: false,
            enabled: true,
            focused: false,
            children: nil
        )
        
        // Test exact match
        let exactQuery = AXQuery.parse("role=Button,description=Save")!
        #expect(AXQueryMatcher.matches(element: element, query: exactQuery, allElements: [element]))
        
        // Test contains match
        let containsQuery = AXQuery.parse("description*=av")!
        #expect(AXQueryMatcher.matches(element: element, query: containsQuery, allElements: [element]))
        
        // Test state match
        let stateQuery = AXQuery.parse("enabled=true")!
        #expect(AXQueryMatcher.matches(element: element, query: stateQuery, allElements: [element]))
        
        // Test bounds constraints
        let boundsQuery = AXQuery.parse("width>=50,height>=20")!
        #expect(AXQueryMatcher.matches(element: element, query: boundsQuery, allElements: [element]))
        
        // Test non-matching query
        let nonMatchQuery = AXQuery.parse("role=Field")!
        #expect(!AXQueryMatcher.matches(element: element, query: nonMatchQuery, allElements: [element]))
    }
    
    @Test("AXElement state creation")
    func testElementStateCreation() {
        // Default state should be nil
        let defaultState = AXElementState.create(selected: false, enabled: true, focused: false)
        #expect(defaultState == nil)
        
        // Non-default selected
        let selectedState = AXElementState.create(selected: true, enabled: true, focused: false)
        #expect(selectedState != nil)
        #expect(selectedState?.selected == true)
        #expect(selectedState?.enabled == nil)
        #expect(selectedState?.focused == nil)
        
        // Non-default enabled
        let disabledState = AXElementState.create(selected: false, enabled: false, focused: false)
        #expect(disabledState != nil)
        #expect(disabledState?.selected == nil)
        #expect(disabledState?.enabled == false)
        #expect(disabledState?.focused == nil)
        
        // Non-default focused
        let focusedState = AXElementState.create(selected: false, enabled: true, focused: true)
        #expect(focusedState != nil)
        #expect(focusedState?.selected == nil)
        #expect(focusedState?.enabled == nil)
        #expect(focusedState?.focused == true)
    }
}
