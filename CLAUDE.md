# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Developer Information

- Developer's name is 1amageek

## Project Overview

AXON is a Swift Package Manager library for querying and extracting macOS Accessibility API (AX) data using a flat array representation. The project provides a powerful query system for identifying UI elements without relying on unique IDs.

### Key Features
- Query-based element identification without unique IDs
- Flat array output of UI elements with preserved context
- Compound matching conditions for precise element selection
- Maintains relationships through indices (depth, parent/child)
- Removes "AX" prefixes while preserving semantic meaning
- Optimized for element interaction and automation

## Development Commands

### Building
```bash
swift build
```

### Running Tests
```bash
swift test
```

### Running a Single Test
```bash
swift test --filter <test-name>
```

## Architecture

- **Package Structure**: Standard Swift Package Manager layout
- **Main Library**: Core accessibility functionality in `Sources/AXUI/`
- **Testing**: Uses Swift Testing framework (not XCTest) as evidenced by `import Testing` in test files
- **Swift Version**: Requires Swift 6.1 minimum as specified in Package.swift
- **Platform Requirements**: iOS 18+ and macOS 15+ as specified in Package.swift


### Design Principles

- **No Makeshift Fallbacks**: Never implement temporary workarounds or fallback mechanisms that mask underlying issues. Such approaches delay bug discovery and compromise system reliability. Always address root causes directly and fail fast when encountering invalid states or data.

## Query-Based Element Identification System

The library now includes a powerful query system for identifying UI elements without relying on unique IDs. This system addresses the challenge that AXUIElement instances don't have persistent identifiers.

### Query System Architecture

#### AXQuery Structure
A flexible query structure that supports multiple matching conditions:

```swift
public struct AXQuery {
    // Basic property matching
    public var role: String?              // Exact role match
    public var value: String?             // Exact value match
    public var identifier: String?        // Exact identifier match
    public var roleDescription: String?   // Exact role description match
    public var help: String?              // Exact help text match
    
    // State matching
    public var selected: Bool?
    public var enabled: Bool?
    public var focused: Bool?
    
    // Spatial queries
    public var boundsContains: CGPoint?   // Element contains this point
    public var boundsIntersects: CGRect?  // Element intersects this rectangle
    public var minWidth: Int?             // Minimum width constraint
    public var minHeight: Int?            // Minimum height constraint
    
    // Text pattern matching
    public var valueContains: String?     // Substring match in value
    public var valueRegex: String?        // Regex pattern for value
    
    // Relationship matching (uses flat array indices)
    public var parent: AXQuery?           // Parent must match this query
    public var hasChild: AXQuery?         // At least one child must match
    
    // Logical operators
    public var and: [AXQuery]?            // All conditions must match
    public var or: [AXQuery]?             // At least one condition must match
}
```

#### Flat Element Representation
Elements are represented in a flat array structure with context information:

```swift
public struct AXElement {
    // Core properties
    public let role: String?
    public let value: String?
    public let identifier: String?
    public let roleDescription: String?
    public let help: String?
    public let bounds: CGRect?
    public let selected: Bool
    public let enabled: Bool
    public let focused: Bool
    
    // Context information (preserves relationships in flat array)
    public let depth: Int                 // Nesting level from root
    public let index: Int                 // Unique index in flat array
    public let parentIndex: Int?          // Index of parent element
    public let childIndices: [Int]        // Indices of child elements
    
    // Native element reference
    public let axElement: AXUIElement     // Original AX element
}
```

### Query API

New methods for querying elements:

```swift
// Query all elements in an application
AXDumper.queryElements(bundleIdentifier: String, query: AXQuery) throws -> [AXElement]

// Dump flat array with optional filtering
AXDumper.dump(bundleIdentifier: String, query: AXQuery? = nil) throws -> [AXElement]

// Query specific window
AXDumper.dumpWindow(bundleIdentifier: String, windowIndex: Int, query: AXQuery? = nil) throws -> [AXElement]
```

### Query Examples

```swift
// Find all save buttons
let query = AXQuery(role: "Button", valueContains: "Save", enabled: true)

// Find text fields in specific area
let query = AXQuery(
    role: "Field",
    boundsIntersects: CGRect(x: 0, y: 0, width: 500, height: 300)
)

// Complex relationship query
let query = AXQuery(
    role: "Button",
    parent: AXQuery(role: "Toolbar"),
    enabled: true
)

// Logical operators
let query = AXQuery(
    or: [
        AXQuery(role: "Button", value: "OK"),
        AXQuery(role: "Button", value: "Accept")
    ]
)
```

### Command Line Usage

The CLI supports query syntax:

```bash
# Simple role query
axon dump com.example.app --query role=Button

# Multiple conditions (comma-separated)
axon dump com.example.app --query 'role=Button,value=Save,enabled=true'

# Text matching
axon dump com.example.app --query 'role=Field,value.contains=user'

# Spatial query
axon dump com.example.app --query 'bounds.contains=100,200'

# Output flat JSON array
axon dump com.example.app --query role=Button --format flat
```

### JSON Output Format

Query results are returned as a flat JSON array:

```json
[
  {
    "role": "Button",
    "value": "Save",
    "bounds": [100, 200, 80, 30],
    "state": {"enabled": true},
    "depth": 3,
    "index": 42
  },
  {
    "role": "Field", 
    "value": "Username",
    "identifier": "login-username",
    "bounds": [50, 100, 200, 25],
    "depth": 2,
    "index": 15
  }
]
```

### Query Implementation Guidelines

- **Performance**: Queries traverse elements once and build the flat array in a single pass
- **Memory**: Large result sets are handled efficiently with streaming where possible
- **Accuracy**: Spatial queries use integer bounds for consistency with the JSON format
- **Extensibility**: Query structure is designed to be extended with new matching conditions

## Testing Framework

This project uses the new Swift Testing framework (`import Testing`) rather than XCTest. Test functions are marked with `@Test` attribute instead of the traditional `testX()` naming convention.
```
