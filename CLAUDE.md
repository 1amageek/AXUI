# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AXON is a Swift Package Manager library for converting macOS Accessibility API (AX) data into a lightweight JSON format. The project implements the "GUI ツリーデータ軽量 JSON フォーマット" specification v1.0, which serializes macOS accessibility tree dumps while preserving all information in a compact, human-readable format.

### Key Features
- Converts AX tree dumps to lightweight JSON without information loss
- Removes "AX" prefixes while preserving semantic meaning
- Supports Group element optimization for minimal representation
- Compatible with LLM prompts and Git diffs
- Implements JSON Schema validation (Draft 2020-12)

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
- **Main Library**: `Sources/AXON/AXON.swift` - implements AX to JSON conversion
- **Testing**: Uses Swift Testing framework (not XCTest) as evidenced by `import Testing` in test files
- **Swift Version**: Requires Swift 6.1 minimum as specified in Package.swift
- **Platform Requirements**: iOS 18+ and macOS 15+ as specified in Package.swift

### JSON Format Specification

The library implements a lightweight JSON format for GUI tree data with these key concepts:

#### Node Structure
- **Standard Nodes**: Objects with `role`, `bounds`, `state`, `children` etc.
- **Group Minimal (G-Minimal)**: Arrays representing AXGroup with minimal attributes
- **Group Object (G-Object)**: Standard objects with `role` key omitted for AXGroup

#### Key Node Properties
- `role`: Element type without "AX" prefix (e.g., "Button", "StaticText", "Window")
- `value`: Display text content 
- `bounds`: `[x,y,width,height]` as integers
- `state`: Object with `selected`, `enabled`, `focused` booleans (omitted if all default)
- `children`: Array of child nodes

#### Compression Rules
- JSON minified with `separators=(",",":")` 
- All bounds values as integers
- UTF-8 encoding without ASCII escaping
- Optional gzip/MessagePack compression for storage/transport

#### Document Structure
```
Window (root node, always single)
 ├ Toolbar (optional)
 └ Other nodes (recursive)
```

### Conversion Algorithm (AX Dump → JSON)

1. **Tokenization**: Parse indentation/`Child[n]:`/`Element:` to manage depth stack
2. **Property Extraction**: Extract `key: value` lines using regex 
3. **Value Normalization**: 
   - Remove "AX" prefix from Role values
   - Convert Selected/Enabled/Focused to boolean
   - Combine Position + Size into bounds array
4. **State Integration**: Merge boolean states, omit if all default values
5. **Group Optimization**: Apply G-Minimal vs G-Object rules based on attributes
6. **Recursive Construction**: Build children arrays recursively
7. **Output**: Minify JSON and optionally compress

### Implementation Guidelines

- **Swift Implementation**: Use `Codable` with `enum Node { case normal(NodeObj), case group([Node]) }`
- **JSON Schema**: Full JSON Schema (Draft 2020-12) validation available in specification
- **LLM Integration**: Add brief annotation explaining `value` field and array Group representation
- **Large Data**: Consider MessagePack + HTTP Range for 100k+ node datasets

### Design Principles

- **No Makeshift Fallbacks**: Never implement temporary workarounds or fallback mechanisms that mask underlying issues. Such approaches delay bug discovery and compromise system reliability. Always address root causes directly and fail fast when encountering invalid states or data.

## Testing Framework

This project uses the new Swift Testing framework (`import Testing`) rather than XCTest. Test functions are marked with `@Test` attribute instead of the traditional `testX()` naming convention.