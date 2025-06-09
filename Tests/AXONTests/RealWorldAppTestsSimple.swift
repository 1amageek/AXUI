import Testing
import Foundation
@testable import AXUI

// MARK: - Real World App Tests (Sample Data)

/// Tests using sample AX dump data representative of real macOS applications

@Test func testRealWorldPerformanceComparison() throws {
    let sampleDumps = [
        "Calendar": getRealCalendarDump(),
        "Weather": getRealWeatherDump(),
        "Maps": getRealMapsDump()
    ]
    
    for (appName, dump) in sampleDumps {
        let originalSize = dump.count
        
        // Test conversion performance
        let startTime = Date()
        let jsonString = try AXConverter.convert(axDump: dump)
        let conversionTime = Date().timeIntervalSince(startTime)
        
        // Test compression
        let compressStart = Date()
        let compressedData = try AXConverter.convertToCompressed(axDump: dump)
        let compressionTime = Date().timeIntervalSince(compressStart)
        
        let jsonSize = jsonString.count
        let compressedSize = compressedData.count
        
        // Performance expectations
        #expect(conversionTime < 0.1) // Should be very fast for test data
        #expect(compressionTime < 0.5) // Compression should be reasonable
        
        // Size expectations
        #expect(jsonSize < originalSize) // JSON should be smaller than AX dump
        #expect(compressedSize < jsonSize) // Compressed should be smaller than JSON
        
        let jsonRatio = Double(jsonSize) / Double(originalSize)
        let compressionRatio = Double(compressedSize) / Double(originalSize)
        
        print("📊 \(appName) Performance:")
        print("   Original: \(originalSize) bytes")
        print("   JSON: \(jsonSize) bytes (ratio: \(String(format: "%.2f", jsonRatio)))")
        print("   Compressed: \(compressedSize) bytes (ratio: \(String(format: "%.2f", compressionRatio)))")
        print("   Conversion: \(String(format: "%.3f", conversionTime))s")
        print("   Compression: \(String(format: "%.3f", compressionTime))s")
    }
    
    print("✅ All real-world performance tests passed")
}

@Test func testRealWorldGroupOptimization() throws {
    // Test case with nested groups that should be optimized
    let nestedGroupDump = """
    Role: AXApplication
    Value: TestApp
      Child[0]:
        Role: AXWindow
        Value: Main Window
          Child[0]:
            Role: AXGroup
              Child[0]:
                Role: AXStaticText
                Value: Simple text 1
              Child[1]:
                Role: AXStaticText
                Value: Simple text 2
          Child[1]:
            Role: AXGroup
            Value: Titled Group
              Child[0]:
                Role: AXStaticText
                Value: Text in titled group
    """
    
    let jsonString = try AXConverter.convert(axDump: nestedGroupDump)
    let node = try UINode.fromJSON(jsonString)
    
    guard case .normal(let app) = node,
          let children = app.children,
          case .normal(let window) = children.first else {
        Issue.record("Expected app and window nodes")
        return
    }
    
    guard let windowChildren = window.children else {
        Issue.record("Expected window to have children")
        return
    }
    
    #expect(windowChildren.count == 2)
    
    // First group should be G-Minimal (array)
    guard case .group(let simpleGroup) = windowChildren[0] else {
        Issue.record("Expected G-Minimal group (array)")
        return
    }
    #expect(simpleGroup.count == 2)
    
    // Second group should be G-Object (has value)
    guard case .normal(let titledGroup) = windowChildren[1] else {
        Issue.record("Expected G-Object group (normal node)")
        return
    }
    #expect(titledGroup.role == nil) // Group role omitted
    #expect(titledGroup.value == "Titled Group")
    #expect(titledGroup.children?.count == 1)
}

// MARK: - Helper Functions for Test Data

private func getRealCalendarDump() -> String {
    return """
    Role: AXApplication
    Value: Calendar
    Identifier: com.apple.iCal
      Child[0]:
        Role: AXWindow
        Value: Calendar
        Position: (100, 100)
        Size: (1200, 800)
          Child[0]:
            Role: AXToolbar
            Position: (100, 100)
            Size: (1200, 52)
              Child[0]:
                Role: AXButton
                Value: Today
                Position: (120, 115)
                Size: (60, 22)
          Child[1]:
            Role: AXScrollArea
            Position: (100, 152)
            Size: (1200, 648)
              Child[0]:
                Role: AXTable
                Position: (100, 152)
                Size: (1180, 628)
    """
}

private func getRealWeatherDump() -> String {
    return """
    Role: AXApplication
    Value: Weather
    Identifier: com.apple.weather
      Child[0]:
        Role: AXWindow
        Value: Weather
        Position: (200, 150)
        Size: (800, 600)
          Child[0]:
            Role: AXGroup
            Position: (200, 150)
            Size: (800, 600)
              Child[0]:
                Role: AXStaticText
                Value: Tokyo, Japan
                Position: (220, 170)
                Size: (200, 30)
              Child[1]:
                Role: AXStaticText
                Value: 25°C
                Position: (220, 220)
                Size: (100, 60)
    """
}

private func getRealMapsDump() -> String {
    return """
    Role: AXApplication
    Value: Maps
    Identifier: com.apple.Maps
      Child[0]:
        Role: AXWindow
        Value: Maps
        Position: (50, 50)
        Size: (1400, 900)
          Child[0]:
            Role: AXToolbar
            Position: (50, 50)
            Size: (1400, 52)
              Child[0]:
                Role: AXTextField
                RoleDescription: search field
                Value: Search for a place or address
                Position: (70, 65)
                Size: (300, 22)
              Child[1]:
                Role: AXButton
                Value: Directions
                Position: (390, 65)
                Size: (80, 22)
    """
}
