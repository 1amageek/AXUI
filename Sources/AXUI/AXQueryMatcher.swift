import Foundation

// MARK: - Query Matching Logic

public struct AXQueryMatcher {
    
    /// Match an element against a query
    public static func matches(element: AXElement, query: AXQuery, allElements: [AXElement]) -> Bool {
        // Handle logical operators first
        if let andQueries = query.andQueries {
            return andQueries.allSatisfy { matches(element: element, query: $0.value, allElements: allElements) }
        }
        
        if let orQueries = query.orQueries {
            return orQueries.contains { matches(element: element, query: $0.value, allElements: allElements) }
        }
        
        if let notQuery = query.negatedQuery {
            return !matches(element: element, query: notQuery.value, allElements: allElements)
        }
        
        // Basic property matching
        if let roleQuery = query.roleQuery {
            let elementRole = element.role
            if !roleQuery.matches(elementRole) { return false }
        }
        
        if let description = query.description {
            if element.description != description { return false }
        }
        
        if let identifier = query.identifier {
            if element.identifier != identifier { return false }
        }
        
        if let roleDescription = query.roleDescription {
            if element.roleDescription != roleDescription { return false }
        }
        
        if let help = query.help {
            if element.help != help { return false }
        }
        
        // State matching
        if let selected = query.selected {
            let elementSelected = element.state?.selected ?? false
            if elementSelected != selected { return false }
        }
        
        if let enabled = query.enabled {
            let elementEnabled = element.state?.enabled ?? true
            if elementEnabled != enabled { return false }
        }
        
        if let focused = query.focused {
            let elementFocused = element.state?.focused ?? false
            if elementFocused != focused { return false }
        }
        
        // Text matching
        if let descriptionContains = query.descriptionContains {
            guard let elementDescription = element.description,
                  elementDescription.lowercased().contains(descriptionContains.lowercased()) else {
                return false
            }
        }
        
        if let descriptionRegex = query.descriptionRegex {
            guard let elementDescription = element.description,
                  let regex = try? NSRegularExpression(pattern: descriptionRegex, options: []),
                  regex.firstMatch(in: elementDescription, options: [], range: NSRange(location: 0, length: elementDescription.utf16.count)) != nil else {
                return false
            }
        }
        
        if let identifierContains = query.identifierContains {
            guard let elementIdentifier = element.identifier,
                  elementIdentifier.lowercased().contains(identifierContains.lowercased()) else {
                return false
            }
        }
        
        if let identifierRegex = query.identifierRegex {
            guard let elementIdentifier = element.identifier,
                  let regex = try? NSRegularExpression(pattern: identifierRegex, options: []),
                  regex.firstMatch(in: elementIdentifier, options: [], range: NSRange(location: 0, length: elementIdentifier.utf16.count)) != nil else {
                return false
            }
        }
        
        // Position matching
        if let position = element.position {
            if let xQuery = query.x, !xQuery.matches(position.x) { return false }
            if let yQuery = query.y, !yQuery.matches(position.y) { return false }
        } else {
            // If element has no position but query requires position matching, fail
            if query.x != nil || query.y != nil {
                return false
            }
        }
        
        // Size matching
        if let size = element.size {
            if let widthQuery = query.width, !widthQuery.matches(size.width) { return false }
            if let heightQuery = query.height, !heightQuery.matches(size.height) { return false }
        } else {
            // If element has no size but query requires size matching, fail
            if query.width != nil || query.height != nil {
                return false
            }
        }
        
        // Legacy spatial matching (for backward compatibility)
        if let bounds = element.bounds, bounds.count == 4 {
            if let boundsContains = query.boundsContains {
                let contains = boundsContains.x >= Double(bounds[0]) && 
                              boundsContains.y >= Double(bounds[1]) &&
                              boundsContains.x <= Double(bounds[0] + bounds[2]) &&
                              boundsContains.y <= Double(bounds[1] + bounds[3])
                if !contains { return false }
            }
            
            if let boundsIntersects = query.boundsIntersects, boundsIntersects.count == 4 {
                let intersects = !(bounds[0] >= Int(boundsIntersects[0] + boundsIntersects[2]) ||
                                  Int(boundsIntersects[0]) >= bounds[0] + bounds[2] ||
                                  bounds[1] >= Int(boundsIntersects[1] + boundsIntersects[3]) ||
                                  Int(boundsIntersects[1]) >= bounds[1] + bounds[3])
                if !intersects { return false }
            }
        } else {
            // If element has no bounds but query requires spatial matching, fail
            if query.boundsContains != nil || query.boundsIntersects != nil {
                return false
            }
        }
        
        // Hierarchical matching (simplified - only direct children)
        if let hasChildQuery = query.hasChildQuery {
            guard let children = element.children else { return false }
            let hasMatchingChild = children.contains { child in
                return matches(element: child, query: hasChildQuery.value, allElements: allElements)
            }
            if !hasMatchingChild { return false }
        }
        
        if let childCount = query.childCount {
            let actualChildCount = element.children?.count ?? 0
            if actualChildCount != childCount { return false }
        }
        
        if let minChildCount = query.minChildCount {
            let actualChildCount = element.children?.count ?? 0
            if actualChildCount < minChildCount { return false }
        }
        
        return true
    }
    
    /// Filter elements based on query
    public static func filter(elements: [AXElement], query: AXQuery) -> [AXElement] {
        return elements.filter { matches(element: $0, query: query, allElements: elements) }
    }
}

// MARK: - Query Extensions

extension AXQuery {
    /// Combine queries with AND logic
    public func and(_ other: AXQuery) -> AXQuery {
        var combined = AXQuery()
        combined.andQueries = [Box(self), Box(other)]
        return combined
    }
    
    /// Combine queries with OR logic
    public func or(_ other: AXQuery) -> AXQuery {
        var combined = AXQuery()
        combined.orQueries = [Box(self), Box(other)]
        return combined
    }
    
    /// Negate a query
    public func negated() -> AXQuery {
        var negated = AXQuery()
        negated.negatedQuery = Box(self)
        return negated
    }
    
    /// Add a child constraint
    public func withChild(_ childQuery: AXQuery) -> AXQuery {
        var copy = self
        copy.hasChildQuery = Box(childQuery)
        return copy
    }
}