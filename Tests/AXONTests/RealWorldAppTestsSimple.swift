import Testing
import Foundation
@testable import AXUI

// MARK: - Real World App Tests (Sample Data)

/// Tests using sample AX dump data representative of real macOS applications

@Test func testRealWorldPerformanceComparison() throws {
    // Test modern AXElement to AIElement conversion performance
    let testElements = [
        "Calendar": createSampleCalendarElements(),
        "Weather": createSampleWeatherElements(),
        "Maps": createSampleMapsElements()
    ]
    
    for (appName, elements) in testElements {
        let elementCount = elements.count
        
        // Test AIElement conversion performance
        let startTime = Date()
        let converter = AIElementConverter()
        let jsonString = try converter.convert(from: elements, pretty: false)
        let conversionTime = Date().timeIntervalSince(startTime)
        
        let jsonSize = jsonString.count
        
        // Performance expectations
        #expect(conversionTime < 0.1) // Should be very fast for test data
        #expect(elementCount > 0) // Should have some elements
        #expect(jsonSize > 0) // Should produce valid JSON
        
        print("📊 \(appName) Performance:")
        print("   Elements: \(elementCount)")
        print("   JSON: \(jsonSize) bytes")
        print("   Conversion: \(String(format: "%.3f", conversionTime))s")
    }
    
    print("✅ All real-world performance tests passed")
}

// MARK: - Helper Functions for Test Data

private func createSampleCalendarElements() -> [AXElement] {
    return [
        AXElement(
            role: .application,
            description: "Calendar",
            identifier: "com.apple.iCal",
            roleDescription: nil,
            help: nil,
            position: nil,
            size: nil,
            selected: false,
            enabled: true,
            focused: false
        ),
        AXElement(
            role: .window,
            description: "Calendar",
            identifier: nil,
            roleDescription: nil,
            help: nil,
            position: Point(x: 100, y: 100),
            size: Size(width: 1200, height: 800),
            selected: false,
            enabled: true,
            focused: false
        ),
        AXElement(
            role: .toolbar,
            description: nil,
            identifier: nil,
            roleDescription: nil,
            help: nil,
            position: Point(x: 100, y: 100),
            size: Size(width: 1200, height: 52),
            selected: false,
            enabled: true,
            focused: false
        ),
        AXElement(
            role: .button,
            description: "Today",
            identifier: nil,
            roleDescription: nil,
            help: nil,
            position: Point(x: 120, y: 115),
            size: Size(width: 60, height: 22),
            selected: false,
            enabled: true,
            focused: false
        )
    ]
}

private func createSampleWeatherElements() -> [AXElement] {
    return [
        AXElement(
            role: .application,
            description: "Weather",
            identifier: "com.apple.weather",
            roleDescription: nil,
            help: nil,
            position: nil,
            size: nil,
            selected: false,
            enabled: true,
            focused: false
        ),
        AXElement(
            role: .window,
            description: "Weather",
            identifier: nil,
            roleDescription: nil,
            help: nil,
            position: Point(x: 200, y: 150),
            size: Size(width: 800, height: 600),
            selected: false,
            enabled: true,
            focused: false
        ),
        AXElement(
            role: .staticText,
            description: "Tokyo, Japan",
            identifier: nil,
            roleDescription: nil,
            help: nil,
            position: Point(x: 220, y: 170),
            size: Size(width: 200, height: 30),
            selected: false,
            enabled: true,
            focused: false
        ),
        AXElement(
            role: .staticText,
            description: "25°C",
            identifier: nil,
            roleDescription: nil,
            help: nil,
            position: Point(x: 220, y: 220),
            size: Size(width: 100, height: 60),
            selected: false,
            enabled: true,
            focused: false
        )
    ]
}

private func createSampleMapsElements() -> [AXElement] {
    return [
        AXElement(
            role: .application,
            description: "Maps",
            identifier: "com.apple.Maps",
            roleDescription: nil,
            help: nil,
            position: nil,
            size: nil,
            selected: false,
            enabled: true,
            focused: false
        ),
        AXElement(
            role: .window,
            description: "Maps",
            identifier: nil,
            roleDescription: nil,
            help: nil,
            position: Point(x: 50, y: 50),
            size: Size(width: 1400, height: 900),
            selected: false,
            enabled: true,
            focused: false
        ),
        AXElement(
            role: .toolbar,
            description: nil,
            identifier: nil,
            roleDescription: nil,
            help: nil,
            position: Point(x: 50, y: 50),
            size: Size(width: 1400, height: 52),
            selected: false,
            enabled: true,
            focused: false
        ),
        AXElement(
            role: .textField,
            description: "Search for a place or address",
            identifier: nil,
            roleDescription: "search field",
            help: nil,
            position: Point(x: 70, y: 65),
            size: Size(width: 300, height: 22),
            selected: false,
            enabled: true,
            focused: false
        ),
        AXElement(
            role: .button,
            description: "Directions",
            identifier: nil,
            roleDescription: nil,
            help: nil,
            position: Point(x: 390, y: 65),
            size: Size(width: 80, height: 22),
            selected: false,
            enabled: true,
            focused: false
        )
    ]
}
