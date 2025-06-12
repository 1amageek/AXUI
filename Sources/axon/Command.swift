import Foundation
import ArgumentParser
import AXUI

// MARK: - AXON CLI Tool

@main
struct Command: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "axon",
        abstract: "macOS Accessibility Tree to JSON Converter",
        discussion: """
        AXON converts macOS accessibility tree data into a lightweight JSON format that preserves
        all semantic information while optimizing for size and readability. Perfect for LLM
        prompts, automated testing, and GUI analysis.

        Key Features:
        • Converts AX tree dumps to compact JSON without information loss
        • Removes "AX" prefixes while preserving semantic meaning (e.g., AXButton → Button)
        • Supports element querying with flexible conditions
        • Group element optimization for minimal representation
        • Pretty-printing and compression statistics
        • Per-window or full application dumping
        • Compatible with JSON Schema validation (Draft 2020-12)

        Common Use Cases:
        • GUI automation and testing scripts
        • Accessibility auditing and analysis
        • AI/LLM prompts for understanding app interfaces
        • Documentation of application UI structure
        • Git-friendly diffs of interface changes

        Example Usage:
        • axon dump finder --pretty --output finder.json
        • axon dump com.apple.weather --stats
        • axon dump safari "role=Button,description*=Save"
        • axon dump finder "role=Field,identifier*=search" --pretty
        • axon dump xcode --window 0 --stats
        • axon list --verbose
        • axon windows safari

        Requires accessibility permissions in System Preferences > Privacy & Security > Accessibility.
        """,
        version: "1.0.0",
        subcommands: [DumpCommand.self, ListCommand.self, WindowsCommand.self]
    )
}


// MARK: - Dump Command

struct DumpCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dump",
        abstract: "Dump accessibility elements with optional filtering",
        discussion: """
        Dump accessibility elements from an application with optional query filtering. 
        Returns a flat array of elements in JSON format.
        
        Usage:
        • axon dump <app> - Dump all elements
        • axon dump <app> <query> - Dump filtered elements
        
        Query Syntax:
        • Exact match: role=Button, description=Save, identifier=login-btn
        • Contains match: description*=text, identifier*=search
        • Regex match: description~=.*[Ss]ave.*
        • State match: enabled=true, selected=false, focused=true
        • Size constraints: minWidth=100, maxHeight=50
        
        Multiple conditions can be combined with commas (AND logic):
        role=Button,description*=Save,enabled=true
        
        Examples:
        • axon dump safari
        • axon dump com.apple.weather --pretty
        • axon dump safari "role=Button"
        • axon dump finder "role=Field,identifier*=search"
        • axon dump notes "description*=text,enabled=true" --window 0
        """,
        aliases: ["d"]
    )
    
    @Argument(help: "Application name or bundle identifier")
    var appIdentifier: String
    
    @Argument(help: "Query string (e.g., 'role=Button,description=Save'). Use '*' for all elements.")
    var queryString: String?
    
    @Option(name: .shortAndLong, help: "Output file path")
    var output: String?
    
    @Flag(help: "Pretty-print JSON output")
    var pretty: Bool = false
    
    @Flag(help: "Show query statistics")
    var stats: Bool = false
    
    @Flag(help: "Output in AI-optimized format")
    var ai: Bool = false
    
    @Flag(help: "Include elements with zero width or height")
    var includeZeroSize: Bool = false
    
    @Option(name: .shortAndLong, help: "Window index to query (default: all windows)")
    var window: Int?
    
    func run() throws {
        try checkPermissions()
        let bundleId = try resolveAppIdentifier(appIdentifier)
        
        // Parse query (if provided)
        let query: AXQuery?
        if let queryString = queryString, queryString != "*" && !queryString.isEmpty {
            guard let parsedQuery = AXQuery.parse(queryString) else {
                print("❌ Invalid query syntax: \(queryString)")
                print("Example: 'role=Button,description=Save' or 'description*=text,enabled=true'")
                throw ExitCode.failure
            }
            query = parsedQuery
            print("🔍 Querying \(appIdentifier) with: \(queryString)")
        } else {
            query = nil
            print("🔍 Dumping all elements from \(appIdentifier)")
        }
        
        // Execute query
        let elements: [AXElement]
        if let windowIndex = window {
            elements = try AXDumper.dumpWindow(
                bundleIdentifier: bundleId,
                windowIndex: windowIndex,
                query: query,
                includeZeroSize: includeZeroSize
            )
        } else {
            
            elements = try AXDumper.dump(
                bundleIdentifier: bundleId,
                query: query,
                includeZeroSize: includeZeroSize
            )
        }
        
        // Convert to JSON (flat array, no hierarchical structure)
        let jsonOutput: String
        if ai {
            jsonOutput = try convertToAIFormat(elements: elements, pretty: pretty)
        } else {
            let encoder = JSONEncoder()
            if pretty {
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            } else {
                encoder.outputFormatting = []
            }
            
            let jsonData = try encoder.encode(elements)
            jsonOutput = String(data: jsonData, encoding: .utf8)!
        }
        
        // Output
        if let outputFile = output {
            try writeToFile(jsonOutput, path: outputFile)
            print("✅ Results saved to: \(outputFile)")
        } else {
            print(jsonOutput)
        }
        
        // Statistics
        if stats {
            print("\n📊 Dump Results:")
            print("   Elements found: \(elements.count)")
            print("   JSON size: \(formatBytes(jsonOutput.count))")
            
            // Show breakdown by role
            let roleCount = Dictionary(grouping: elements, by: { $0.role?.rawValue ?? "Unknown" })
                .mapValues { $0.count }
                .sorted { $0.value > $1.value }
            
            if !roleCount.isEmpty {
                print("   Element types:")
                for (role, count) in roleCount {
                    print("     \(role): \(count)")
                }
            }
        }
    }
}

// MARK: - List Command

struct ListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List running applications",
        aliases: ["l"]
    )
    
    @Flag(help: "Show bundle identifiers")
    var verbose: Bool = false
    
    func run() throws {
        let apps = AXDumper.listRunningApps()
        
        if verbose {
            print("📱 Running Applications:")
            print("┌─────────────────────────────────────┬─────────────────────────────────────┐")
            print("│ Application Name                    │ Bundle Identifier                   │")
            print("├─────────────────────────────────────┼─────────────────────────────────────┤")
            
            for app in apps {
                let name = String(app.name.prefix(35)).padding(toLength: 35, withPad: " ", startingAt: 0)
                let bundleId = String((app.bundleId ?? "N/A").prefix(35)).padding(toLength: 35, withPad: " ", startingAt: 0)
                print("│ \(name) │ \(bundleId) │")
            }
            
            print("└─────────────────────────────────────┴─────────────────────────────────────┘")
        } else {
            print("📱 Running Applications:")
            for app in apps {
                print("   \(app.name)")
            }
        }
        
        print("Total: \(apps.count) applications")
    }
}

// MARK: - Windows Command

struct WindowsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "windows",
        abstract: "List windows for an application",
        aliases: ["w"]
    )
    
    @Argument(help: "Application name or bundle identifier")
    var appIdentifier: String
    
    func run() throws {
        try checkPermissions()
        let bundleId = try resolveAppIdentifier(appIdentifier)
        
        // List windows
        let windows = try AXDumper.listWindows(bundleIdentifier: bundleId)
        
        if windows.isEmpty {
            print("📭 No windows found for \(appIdentifier)")
        } else {
            print("🪟 Windows for \(appIdentifier):")
            print("┌───────┬────────────────────────────────────────┬──────────────────────┐")
            print("│ Index │ Title                                  │ Position & Size      │")
            print("├───────┼────────────────────────────────────────┼──────────────────────┤")
            
            for window in windows {
                let index = String(window.index).padding(toLength: 5, withPad: " ", startingAt: 0)
                let title = String((window.title ?? "Untitled").prefix(38)).padding(toLength: 38, withPad: " ", startingAt: 0)
                
                let posSize: String
                if let pos = window.position, let size = window.size {
                    posSize = "(\(Int(pos.x)),\(Int(pos.y))) \(Int(size.width))x\(Int(size.height))"
                } else {
                    posSize = "Unknown"
                }
                let posSizePadded = String(posSize.prefix(20)).padding(toLength: 20, withPad: " ", startingAt: 0)
                
                print("│ \(index) │ \(title) │ \(posSizePadded) │")
            }
            
            print("└───────┴────────────────────────────────────────┴──────────────────────┘")
            print("\nUse 'axon dump <name> --window <index>' to dump a specific window")
        }
    }
}


// MARK: - Helper Functions

func checkPermissions() throws {
    guard AXDumper.checkAccessibilityPermissions() else {
        print("❌ Accessibility permissions required")
        print("Please enable accessibility access in:")
        print("System Preferences > Privacy & Security > Accessibility")
        throw ExitCode.failure
    }
}

func resolveAppIdentifier(_ appIdentifier: String) throws -> String {
    if appIdentifier.contains(".") {
        // Assume it's a bundle ID
        return appIdentifier
    } else {
        // Try to find by name
        guard let bundleId = findAppBundleId(appIdentifier) else {
            print("❌ App '\(appIdentifier)' not found or not running")
            print("Use 'axon list' to see running applications")
            throw ExitCode.failure
        }
        return bundleId
    }
}

func findAppBundleId(_ appName: String) -> String? {
    let apps = AXDumper.listRunningApps()
    let lowercaseName = appName.lowercased()
    
    // First priority: Exact name match
    if let app = apps.first(where: { $0.name.lowercased() == lowercaseName }) {
        return app.bundleId
    }
    
    // Second priority: Exact bundle ID match
    if let app = apps.first(where: { $0.bundleId?.lowercased() == lowercaseName }) {
        return app.bundleId
    }
    
    return nil
}

func writeToFile(_ content: String, path: String) throws {
    let url = URL(fileURLWithPath: path)
    try content.write(to: url, atomically: true, encoding: .utf8)
}

func printStats(elementCount: Int, jsonSize: Int) {
    print("\n📊 Statistics:")
    print("   Elements found: \(elementCount)")
    print("   JSON size: \(formatBytes(jsonSize))")
}

func formatBytes(_ bytes: Int) -> String {
    let units = ["B", "KB", "MB", "GB"]
    var size = Double(bytes)
    var unitIndex = 0
    
    while size >= 1024 && unitIndex < units.count - 1 {
        size /= 1024
        unitIndex += 1
    }
    
    return String(format: "%.1f %@", size, units[unitIndex])
}

// MARK: - AI Format Conversion Functions

/// Convert AXElement array to AI format
func convertToAIFormat(elements: [AXElement], pretty: Bool = false) throws -> String {
    return try AIFormatHelpers.convertToAIFormat(elements: elements, pretty: pretty)
}
