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

