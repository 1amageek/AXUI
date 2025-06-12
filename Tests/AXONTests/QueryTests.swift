import Testing
@testable import AXUI

// MARK: - Query System Tests

struct QueryTests {
    
    @Test("Basic query parsing")
    func testBasicQueryParsing() {
        let query = AXQuery.parse("role=Button,description=Save")
        
        #expect(query != nil)
        #expect(query?.role == "Button")
        #expect(query?.description == "Save")
    }
    
    @Test("Contains query parsing")
    func testContainsQueryParsing() {
        let query = AXQuery.parse("description*=search,identifier*=login")
        
        #expect(query != nil)
        #expect(query?.descriptionContains == "search")
        #expect(query?.identifierContains == "login")
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
        #expect(query?.enabled == true)
        #expect(query?.selected == false)
        #expect(query?.focused == true)
    }
    
    @Test("Query builder methods")
    func testQueryBuilderMethods() {
        let buttonQuery = AXQuery.button(description: "Save")
        #expect(buttonQuery.role == "Button")
        #expect(buttonQuery.description == "Save")
        
        let textFieldQuery = AXQuery.textField(identifier: "username")
        #expect(textFieldQuery.role == "Field")
        #expect(textFieldQuery.identifier == "username")
        
        let interactiveQuery = AXQuery.interactive()
        #expect(interactiveQuery.orQueries != nil)
        #expect(interactiveQuery.orQueries?.count ?? 0 > 0)
    }
    
    @Test("Element matching")
    func testElementMatching() {
        let element = AXElement(
            role: "Button",
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
        let boundsQuery = AXQuery.parse("minWidth=50,minHeight=20")!
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
