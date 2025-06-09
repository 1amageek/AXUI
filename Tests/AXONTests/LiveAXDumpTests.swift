import Testing
import Foundation
import AppKit
@testable import AXUI

// MARK: - Live AX Dump Tests

/// Tests that actually dump from running applications
/// These tests require accessibility permissions

@Test func testListRunningApps() throws {
    let apps = AXDumper.listRunningApps()
    
    #expect(!apps.isEmpty)
    
    for app in apps.prefix(10) {
        print("  \(app.name) - \(app.bundleId ?? "no bundle ID")")
    }
    
    // Finder should always be running
    let finderExists = apps.contains { app in
        app.bundleId == "com.apple.finder"
    }
    #expect(finderExists)
}

@Test func testPerformanceWithRealApp() throws {
    // Use Finder for performance testing (always available)
    do {
        let startTime = Date()
        let axDump = try AXDumper.dump(bundleIdentifier: "com.apple.finder", maxDepth: 2, maxChildren: 8)
        let dumpTime = Date().timeIntervalSince(startTime)
        
        let parseStart = Date()
        let _ = try AXParser.parse(content: axDump)
        let parseTime = Date().timeIntervalSince(parseStart)
        
        let convertStart = Date()
        let jsonString = try AXConverter.convert(axDump: axDump)
        let convertTime = Date().timeIntervalSince(convertStart)
        
        let compressStart = Date()
        let compressedData = try AXConverter.convertToCompressed(axDump: axDump)
        let compressTime = Date().timeIntervalSince(compressStart)
        
        // Performance expectations for real apps
        #expect(dumpTime < 10.0) // AX dump should complete within 10 seconds
        #expect(parseTime < 2.0) // Parsing should be fast
        #expect(convertTime < 2.0) // Conversion should be fast
        #expect(compressTime < 3.0) // Compression should be reasonable
        
        // Size validation
        #expect(!axDump.isEmpty)
        #expect(!jsonString.isEmpty)
        #expect(compressedData.count > 0)
        
        print("🚀 Performance Results with Real App:")
        print("   AX Dump: \(String(format: "%.3f", dumpTime))s")
        print("   Parse: \(String(format: "%.3f", parseTime))s") 
        print("   Convert: \(String(format: "%.3f", convertTime))s")
        print("   Compress: \(String(format: "%.3f", compressTime))s")
        print("   Sizes: AX=\(axDump.count), JSON=\(jsonString.count), Compressed=\(compressedData.count)")
        
        let totalTime = dumpTime + parseTime + convertTime + compressTime
        print("   Total: \(String(format: "%.3f", totalTime))s")
        
    } catch AXDumperError.accessibilityPermissionDenied {
        Issue.record("Accessibility permissions required for performance testing")
        return
    } catch {
        throw error
    }
}
