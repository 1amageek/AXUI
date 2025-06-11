# AXON

AXON is a Swift Package Manager library and CLI tool for querying and extracting macOS Accessibility API (AX) data using a flat array representation. The project provides a powerful query system for identifying UI elements without relying on unique IDs and automatically filters out zero-size elements for practical use.

## Features

- 🔍 **Query-Based Element Identification**: Find UI elements using flexible conditions without unique IDs
- 📏 **Smart Size Filtering**: Automatically excludes zero-size elements (hidden menus, etc.) by default
- 🗜️ **Flat Array Output**: Preserves relationships through indices while maintaining performance
- 🎯 **Compound Matching**: Combine multiple conditions with logical operators
- 🔗 **Relationship Queries**: Search based on parent/child relationships
- 📊 **Position & Size Queries**: Filter elements by coordinates and dimensions with comparison operators
- 🚀 **CLI Tool**: Command-line interface for easy integration and automation
- 📝 **JSON Output**: Clean, standardized format for consumption by AI/LLM systems

## Installation

### Swift Package Manager

Add AXON to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/AXON.git", from: "1.0.0")
]
```

### CLI Tool

Build the CLI tool:

```bash
swift build
.build/debug/axon --help
```

## CLI Usage

AXON provides a comprehensive command-line interface for accessibility tree analysis:

### Basic Commands

```bash
# List running applications
axon list --verbose

# Dump application accessibility tree
axon app weather --pretty
axon bundle com.apple.weather --output weather.json

# List windows for an application
axon windows safari

# Query elements with conditions
axon query com.apple.weather "role=Button"
```

### Query System

The query system supports flexible element matching with multiple operators:

#### Basic Property Matching
```bash
# Exact matches
axon query safari "role=Button"
axon query finder "description=Search"
axon query notes "identifier=compose-btn"

# Partial matches
axon query safari "description*=bookmark"  # Contains
axon query notes "identifier*=edit"        # Contains

# Regex matching
axon query safari "description~=.*[Ss]ave.*"
```

#### Position & Size Queries
```bash
# Size filtering (automatically excludes zero-size by default)
axon query weather "width>100"           # Width greater than 100
axon query weather "height!=0"           # Non-zero height
axon query weather "width>=50,height>=20" # Minimum dimensions

# Position filtering
axon query weather "x=100,y=200"         # Exact position
axon query weather "x>500"               # Right side of screen
axon query weather "y<100"               # Top area

# Include zero-size elements (hidden menus, etc.)
axon query weather "role=MenuItem" --include-zero-size
```

#### State Matching
```bash
axon query safari "enabled=true,focused=false"
axon query notes "selected=true"
```

#### Complex Queries
```bash
# Multiple conditions (AND logic)
axon query safari "role=Button,enabled=true,width>50"

# Interactive elements only
axon query app "role=Button" --window 0

# Elements in specific area
axon query weather "x>100,y>200,width<500"
```

### Output Options

```bash
# Pretty-printed JSON
axon query weather "role=Button" --pretty

# Save to file
axon query weather "role=Button" --output buttons.json

# AI-optimized format
axon query weather "role=Button" --ai

# Show statistics
axon query weather "role=Button" --stats
```

## Library Usage

### Basic Element Querying

```swift
import AXUI

// Query all buttons in an application
let query = AXQuery()
query.role = "Button"
query.enabled = true

let elements = try AXDumper.dumpFlat(
    bundleIdentifier: "com.apple.weather", 
    query: query
)
```

### Advanced Queries with Comparison Operators

```swift
// Create size constraints
var sizeQuery = ComparisonQuery<Double>()
sizeQuery.greaterThan = 50.0  // Width > 50

var query = AXQuery()
query.role = "Button"
query.width = sizeQuery
query.enabled = true

let elements = try AXDumper.dumpFlat(
    bundleIdentifier: "com.apple.weather",
    query: query
)
```

### Position and Size Filtering

```swift
// Find elements in specific area
var xQuery = ComparisonQuery<Double>()
xQuery.greaterThanOrEqual = 100.0
xQuery.lessThanOrEqual = 500.0

var yQuery = ComparisonQuery<Double>()
yQuery.lessThan = 300.0

var query = AXQuery()
query.x = xQuery
query.y = yQuery

let elements = try AXDumper.dumpFlat(
    bundleIdentifier: "com.apple.finder",
    query: query
)
```

### Query Builder Patterns

```swift
// Pre-built query helpers
let buttonQuery = AXQuery.button(description: "Save")
let textFieldQuery = AXQuery.textField(identifier: "username")
let interactiveQuery = AXQuery.interactive()

// Spatial queries
let spatialQuery = AXQuery.within(rect: [0, 0, 800, 600])
let textQuery = AXQuery.containing(text: "search")
```

## Element Structure

Elements are represented as flat arrays with preserved context:

```swift
public struct AXElement {
    public let role: String?           // "Button", "Text", "Field"
    public let description: String?    // Element description/value
    public let identifier: String?     // Unique identifier
    public let position: Point?        // {x, y} coordinates
    public let size: Size?            // {width, height} dimensions
    public let state: AXElementState? // {enabled, selected, focused}
    public let children: [AXElement]? // Direct children (for interactive elements)
}
```

## Query Syntax Reference

### Comparison Operators
- `=` - Equals
- `!=` - Not equals
- `>` - Greater than
- `<` - Less than
- `>=` - Greater than or equal
- `<=` - Less than or equal

### Text Operators
- `description*=text` - Contains match
- `description~=regex` - Regex match

### Supported Properties
- `role` - Element role (Button, Text, Field, etc.)
- `description` - Element description/value
- `identifier` - Element identifier
- `enabled`, `selected`, `focused` - Boolean states
- `x`, `y` - Position coordinates
- `width`, `height` - Element dimensions

## Zero-Size Element Filtering

By default, AXON excludes elements with zero width or height (typically hidden menu items). This behavior can be controlled:

```bash
# Default: excludes zero-size elements
axon query app "role=Button"

# Include all elements (including hidden menus)
axon query app "role=MenuItem" --include-zero-size

# Explicitly query for zero-size elements
axon query app "width=0" --include-zero-size
```

## JSON Output Format

Query results are returned as flat JSON arrays:

```json
[
  {
    "role": "Button",
    "description": "Save Document",
    "position": {"x": 100, "y": 200},
    "size": {"width": 80, "height": 30},
    "state": {"enabled": true}
  },
  {
    "role": "Field", 
    "description": "Username",
    "identifier": "login-username",
    "position": {"x": 50, "y": 100},
    "size": {"width": 200, "height": 25}
  }
]
```

## Architecture

- **AXDumper**: Core accessibility API interface with query support
- **AXQuery**: Flexible query structure with comparison operators
- **AXQueryMatcher**: Element matching and filtering logic
- **ComparisonQuery**: Generic comparison operations for numeric values
- **Command**: CLI interface with comprehensive subcommands

## Requirements

- iOS 18.0+ / macOS 15.0+
- Swift 6.1+
- Accessibility permissions for CLI usage

## Accessibility Permissions

The CLI tool requires accessibility permissions:

1. Go to **System Preferences > Privacy & Security > Accessibility**
2. Add your terminal application or the built `axon` binary
3. Grant accessibility access

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

@1amageek