import Foundation

// MARK: - AX Dump Parser

public struct AXParser {
    
    /// Parse AX dump from string lines
    public static func parse(lines: [String]) throws -> AXProperties {
        guard !lines.isEmpty else {
            throw AXParseError.emptyInput
        }
        
        var index = 0
        return try parseNode(lines: lines, index: &index, depth: 0)
    }
    
    /// Parse AX dump from string content
    public static func parse(content: String) throws -> AXProperties {
        let lines = content.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return try parse(lines: lines)
    }
    
    // MARK: - Private Implementation
    
    private static func parseNode(lines: [String], index: inout Int, depth: Int) throws -> AXProperties {
        guard index < lines.count else {
            throw AXParseError.unexpectedEndOfInput
        }
        
        var properties = [String: String]()
        var children: [AXProperties] = []
        
        // Parse current node properties and children
        while index < lines.count {
            let line = lines[index]
            let currentDepth = getDepth(line)
            
            // If we've gone back to a shallower depth, we're done with this node
            if currentDepth < depth {
                break
            }
            
            // If this is a child element marker, start parsing child
            if line.contains("Child[") || line.contains("Element:") {
                index += 1 // Skip the child marker line
                // Parse the child node starting from the next line
                if index < lines.count {
                    let child = try parseNode(lines: lines, index: &index, depth: getDepth(lines[index]))
                    children.append(child)
                }
                continue
            }
            
            // If this line is deeper than our current node, it belongs to a child
            if currentDepth > depth {
                // This shouldn't happen with proper Child[] markers, but handle gracefully
                let child = try parseNode(lines: lines, index: &index, depth: currentDepth)
                children.append(child)
                continue
            }
            
            // Parse property line at current depth
            if currentDepth == depth {
                if let (key, value) = parsePropertyLine(line) {
                    properties[key] = value
                }
                index += 1
            } else {
                // Different depth, stop parsing this node
                break
            }
        }
        
        return try createAXProperties(from: properties, children: children)
    }
    
    private static func getDepth(_ line: String) -> Int {
        return line.prefix(while: { $0 == " " || $0 == "\t" }).count
    }
    
    private static func parsePropertyLine(_ line: String) -> (String, String)? {
        // Match pattern: "Key: Value" with optional whitespace and indentation
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Skip child/element markers
        if trimmed.contains("Child[") || trimmed.contains("Element:") {
            return nil
        }
        
        // Find first colon that's not inside parentheses or brackets
        guard let colonIndex = findColonIndex(in: trimmed) else {
            return nil
        }
        
        let key = String(trimmed[..<colonIndex]).trimmingCharacters(in: .whitespaces)
        let value = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
        
        guard !key.isEmpty else { return nil }
        
        return (key, value)
    }
    
    private static func findColonIndex(in string: String) -> String.Index? {
        var parenCount = 0
        var bracketCount = 0
        
        for index in string.indices {
            let char = string[index]
            switch char {
            case "(": parenCount += 1
            case ")": parenCount -= 1
            case "[": bracketCount += 1
            case "]": bracketCount -= 1
            case ":" where parenCount == 0 && bracketCount == 0:
                return index
            default: break
            }
        }
        return nil
    }
    
    private static func createAXProperties(from properties: [String: String], children: [AXProperties]) throws -> AXProperties {
        // Parse position and size
        let position = parsePosition(properties["Position"])
        let size = parseSize(properties["Size"])
        
        // Parse boolean values
        let selected = parseBool(properties["Selected"])
        let enabled = parseBool(properties["Enabled"])
        let focused = parseBool(properties["Focused"])
        
        return AXProperties(
            role: properties["Role"],
            roleDescription: properties["RoleDescription"],
            identifier: properties["Identifier"],
            value: properties["Value"] ?? properties["Title"] ?? properties["Label"],
            help: properties["Help"],
            position: position,
            size: size,
            selected: selected,
            enabled: enabled,
            focused: focused,
            children: children
        )
    }
    
    private static func parsePosition(_ string: String?) -> CGPoint? {
        guard let string = string else { return nil }
        return parsePoint(from: string)
    }
    
    private static func parseSize(_ string: String?) -> CGSize? {
        guard let string = string else { return nil }
        if let point = parsePoint(from: string) {
            return CGSize(width: point.x, height: point.y)
        }
        return nil
    }
    
    private static func parsePoint(from string: String) -> CGPoint? {
        // Parse formats like "(123, 456)" or "123, 456"
        let cleaned = string.trimmingCharacters(in: CharacterSet(charactersIn: "(){}[] "))
        let components = cleaned.components(separatedBy: ",")
        
        guard components.count == 2,
              let x = Double(components[0].trimmingCharacters(in: .whitespaces)),
              let y = Double(components[1].trimmingCharacters(in: .whitespaces)) else {
            return nil
        }
        
        return CGPoint(x: x, y: y)
    }
    
    private static func parseBool(_ string: String?) -> Bool? {
        guard let string = string?.lowercased() else { return nil }
        switch string {
        case "true", "yes", "1": return true
        case "false", "no", "0": return false
        default: return nil
        }
    }
}

// MARK: - Parse Errors

public enum AXParseError: Error, LocalizedError, Equatable {
    case emptyInput
    case unexpectedEndOfInput
    case invalidFormat(line: String)
    case invalidPropertyValue(key: String, value: String)
    
    public var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "Input is empty"
        case .unexpectedEndOfInput:
            return "Unexpected end of input while parsing"
        case .invalidFormat(let line):
            return "Invalid format in line: \(line)"
        case .invalidPropertyValue(let key, let value):
            return "Invalid value '\(value)' for property '\(key)'"
        }
    }
}