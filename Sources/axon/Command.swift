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
        • Supports element filtering by type or interaction capability
        • Group element optimization for minimal representation
        • Pretty-printing and compression statistics
        • Per-window or full application dumping
        • Compatible with JSON Schema validation (Draft 2020-12)

        Filtering Options:
        • button - Button elements
        • textfield - Text fields and text areas
        • checkbox - Checkbox elements
        • radiobutton - Radio button elements
        • slider - Slider elements
        • popupbutton - Popup button elements
        • tab - Tab elements
        • menuitem - Menu item elements
        • link - Link elements
        • interactive - All interactive elements (buttons, fields, checkboxes, etc.)
        • all - No filtering (default)

        Common Use Cases:
        • GUI automation and testing scripts
        • Accessibility auditing and analysis
        • AI/LLM prompts for understanding app interfaces
        • Documentation of application UI structure
        • Git-friendly diffs of interface changes

        Example Usage:
        • axon app finder --pretty --output finder.json
        • axon bundle com.apple.weather --filter interactive
        • axon app xcode --window 0 --stats
        • axon query safari "role=Button,description*=Save"
        • axon query finder "role=Field,identifier*=search" --pretty
        • axon list --verbose
        • axon windows safari

        Requires accessibility permissions in System Preferences > Privacy & Security > Accessibility.
        """,
        version: "1.0.0",
        subcommands: [AppCommand.self, BundleCommand.self, QueryCommand.self, ListCommand.self, WindowsCommand.self]
    )
}

// MARK: - App Command

struct AppCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "app",
        abstract: "Dump specified application"
    )
    
    @Argument(help: "Application name (e.g., 'weather', 'calendar', 'finder')")
    var appName: String
    
    @Option(name: .shortAndLong, help: "Output file path")
    var output: String?
    
    
    @Flag(help: "Pretty-print JSON output")
    var pretty: Bool = false
    
    @Flag(help: "Show size statistics")
    var stats: Bool = false
    
    @Option(name: .shortAndLong, help: "Window index to dump (default: all windows)")
    var window: Int?
    
    @Option(help: "Filter by element type. Multiple filters can be comma-separated. Available types: button, textfield, checkbox, radiobutton, slider, popupbutton, tab, menuitem, link, interactive (all interactive elements), all (no filtering). Example: --filter button,textfield")
    var filter: String?
    
    func run() throws {
        // Check accessibility permissions
        guard AXDumper.checkAccessibilityPermissions() else {
            print("❌ Accessibility permissions required")
            print("Please enable accessibility access in:")
            print("System Preferences > Privacy & Security > Accessibility")
            throw ExitCode.failure
        }
        
        // Find app bundle identifier
        guard let bundleId = findAppBundleId(appName) else {
            print("❌ App '\(appName)' not found or not running")
            print("Use 'axon list' to see running applications")
            throw ExitCode.failure
        }
        
        print("🔍 Dumping \(appName) (\(bundleId))...")
        
        // Dump AX tree
        let axDump: String
        if let windowIndex = window {
            // Dump specific window
            if let filter = filter {
                axDump = try AXDumper.dumpWindow(
                    bundleIdentifier: bundleId,
                    windowIndex: windowIndex,
                    filter: filter
                )
            } else {
                axDump = try AXDumper.dumpWindow(
                    bundleIdentifier: bundleId,
                    windowIndex: windowIndex
                )
            }
        } else {
            // Dump entire app
            if let filter = filter {
                axDump = try AXDumper.dump(
                    bundleIdentifier: bundleId,
                    filter: filter
                )
            } else {
                axDump = try AXDumper.dump(
                    bundleIdentifier: bundleId
                )
            }
        }
        
        // Convert to JSON
        let jsonOutput: String
        if pretty {
            jsonOutput = try AXConverter.convertToPrettyJSON(axDump: axDump)
        } else {
            jsonOutput = try AXConverter.convert(axDump: axDump)
        }
        
        // Output
        if let outputFile = output {
            try writeToFile(jsonOutput, path: outputFile)
            print("✅ JSON saved to: \(outputFile)")
        } else {
            print(jsonOutput)
        }
        
        // Statistics
        if stats {
            let compressedData = try AXConverter.convertToCompressed(axDump: axDump)
            printStats(
                originalSize: axDump.count,
                jsonSize: jsonOutput.count,
                compressedSize: compressedData.count
            )
        }
    }
}

// MARK: - Bundle Command

struct BundleCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "bundle",
        abstract: "Dump application by bundle identifier",
        aliases: ["i"]
    )
    
    @Argument(help: "Bundle identifier (e.g., 'com.apple.weather', 'com.apple.iCal')")
    var bundleId: String
    
    @Option(name: .shortAndLong, help: "Output file path")
    var output: String?
    
    
    @Flag(help: "Pretty-print JSON output")
    var pretty: Bool = false
    
    @Flag(help: "Show size statistics")
    var stats: Bool = false
    
    @Option(name: .shortAndLong, help: "Window index to dump (default: all windows)")
    var window: Int?
    
    @Option(help: "Filter by element type. Multiple filters can be comma-separated. Available types: button, textfield, checkbox, radiobutton, slider, popupbutton, tab, menuitem, link, interactive (all interactive elements), all (no filtering). Example: --filter button,textfield")
    var filter: String?
    
    func run() throws {
        // Check accessibility permissions
        guard AXDumper.checkAccessibilityPermissions() else {
            print("❌ Accessibility permissions required")
            print("Please enable accessibility access in:")
            print("System Preferences > Privacy & Security > Accessibility")
            throw ExitCode.failure
        }
        
        // Check if app is running
        let apps = AXDumper.listRunningApps()
        guard apps.contains(where: { $0.bundleId == bundleId }) else {
            print("❌ App with bundle ID '\(bundleId)' not found or not running")
            print("Use 'axon list --verbose' to see running applications and their bundle IDs")
            throw ExitCode.failure
        }
        
        print("🔍 Dumping \(bundleId)...")
        
        // Dump AX tree
        let axDump: String
        if let windowIndex = window {
            // Dump specific window
            if let filter = filter {
                axDump = try AXDumper.dumpWindow(
                    bundleIdentifier: bundleId,
                    windowIndex: windowIndex,
                    filter: filter
                )
            } else {
                axDump = try AXDumper.dumpWindow(
                    bundleIdentifier: bundleId,
                    windowIndex: windowIndex
                )
            }
        } else {
            // Dump entire app
            if let filter = filter {
                axDump = try AXDumper.dump(
                    bundleIdentifier: bundleId,
                    filter: filter
                )
            } else {
                axDump = try AXDumper.dump(
                    bundleIdentifier: bundleId
                )
            }
        }
        
        // Convert to JSON
        let jsonOutput: String
        if pretty {
            jsonOutput = try AXConverter.convertToPrettyJSON(axDump: axDump)
        } else {
            jsonOutput = try AXConverter.convert(axDump: axDump)
        }
        
        // Output
        if let outputFile = output {
            try writeToFile(jsonOutput, path: outputFile)
            print("✅ JSON saved to: \(outputFile)")
        } else {
            print(jsonOutput)
        }
        
        // Statistics
        if stats {
            let compressedData = try AXConverter.convertToCompressed(axDump: axDump)
            printStats(
                originalSize: axDump.count,
                jsonSize: jsonOutput.count,
                compressedSize: compressedData.count
            )
        }
    }
}

// MARK: - Query Command

struct QueryCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "query",
        abstract: "Query elements using flexible conditions",
        discussion: """
        Query elements using a flexible condition syntax. Returns a flat array of matching elements.
        
        Query Syntax:
        • Exact match: role=Button, description=Save, identifier=login-btn
        • Contains match: description*=text, identifier*=search
        • Regex match: description~=.*[Ss]ave.*
        • State match: enabled=true, selected=false, focused=true
        • Size constraints: minWidth=100, maxHeight=50
        
        Multiple conditions can be combined with commas (AND logic):
        role=Button,description*=Save,enabled=true
        
        Examples:
        • axon query safari "role=Button"
        • axon query finder "role=Field,identifier*=search"
        • axon query notes "description*=text,enabled=true"
        • axon query app --window 0 "role=Button,minWidth=50"
        """,
        aliases: ["q"]
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
    
    @Option(name: .shortAndLong, help: "Window index to query (default: all windows)")
    var window: Int?
    
    func run() throws {
        // Check accessibility permissions
        guard AXDumper.checkAccessibilityPermissions() else {
            print("❌ Accessibility permissions required")
            print("Please enable accessibility access in:")
            print("System Preferences > Privacy & Security > Accessibility")
            throw ExitCode.failure
        }
        
        // Find app bundle identifier
        let bundleId: String
        if appIdentifier.contains(".") {
            bundleId = appIdentifier
        } else {
            guard let foundBundleId = findAppBundleId(appIdentifier) else {
                print("❌ App '\(appIdentifier)' not found or not running")
                print("Use 'axon list' to see running applications")
                throw ExitCode.failure
            }
            bundleId = foundBundleId
        }
        
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
            elements = try AXDumper.dumpWindowFlat(
                bundleIdentifier: bundleId,
                windowIndex: windowIndex,
                query: query
            )
        } else {
            elements = try AXDumper.dumpFlat(
                bundleIdentifier: bundleId,
                query: query
            )
        }
        
        // Convert to JSON (flat array, no hierarchical structure)
        let encoder = JSONEncoder()
        if pretty {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        } else {
            encoder.outputFormatting = []
        }
        
        let jsonData = try encoder.encode(elements)
        let jsonOutput = String(data: jsonData, encoding: .utf8)!
        
        // Output
        if let outputFile = output {
            try writeToFile(jsonOutput, path: outputFile)
            print("✅ Results saved to: \(outputFile)")
        } else {
            print(jsonOutput)
        }
        
        // Statistics
        if stats {
            print("\n📊 Query Results:")
            print("   Elements found: \(elements.count)")
            print("   JSON size: \(formatBytes(jsonOutput.count))")
            
            // Show breakdown by role
            let roleCount = Dictionary(grouping: elements, by: { $0.role ?? "Unknown" })
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
        // Check accessibility permissions
        guard AXDumper.checkAccessibilityPermissions() else {
            print("❌ Accessibility permissions required")
            print("Please enable accessibility access in:")
            print("System Preferences > Privacy & Security > Accessibility")
            throw ExitCode.failure
        }
        
        // Find app bundle identifier
        let bundleId: String
        if appIdentifier.contains(".") {
            // Assume it's a bundle ID
            bundleId = appIdentifier
        } else {
            // Try to find by name
            guard let foundBundleId = findAppBundleId(appIdentifier) else {
                print("❌ App '\(appIdentifier)' not found or not running")
                print("Use 'axon list' to see running applications")
                throw ExitCode.failure
            }
            bundleId = foundBundleId
        }
        
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
            print("\nUse 'axon app <name> --window <index>' to dump a specific window")
        }
    }
}


// MARK: - Helper Functions

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

func printStats(originalSize: Int, jsonSize: Int, compressedSize: Int) {
    let jsonRatio = Double(jsonSize) / Double(originalSize)
    let compressRatio = Double(compressedSize) / Double(originalSize)
    
    print("\n📊 Size Statistics:")
    print("   Original AX Dump: \(formatBytes(originalSize))")
    print("   JSON Output:      \(formatBytes(jsonSize)) (\(String(format: "%.1f", jsonRatio * 100))%)")
    print("   Compressed:       \(formatBytes(compressedSize)) (\(String(format: "%.1f", compressRatio * 100))%)")
    print("   Space Saved:      \(formatBytes(originalSize - jsonSize)) JSON, \(formatBytes(originalSize - compressedSize)) compressed")
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
