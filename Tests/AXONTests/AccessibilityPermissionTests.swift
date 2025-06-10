import Testing
import Foundation
@testable import AXUI

// MARK: - Accessibility Permission Tests

@Test func testAccessibilityPermissionCheck() throws {
    let hasPermissions = AXDumper.checkAccessibilityPermissions()
    
    print("🔐 Accessibility Permissions: \(hasPermissions ? "✅ Granted" : "❌ Not Granted")")
    
    if !hasPermissions {
        print("📝 To grant permissions:")
        print("   1. Open System Preferences/Settings")
        print("   2. Go to Privacy & Security > Accessibility")
        print("   3. Add this test application to the list")
        print("   4. Or run tests with sudo (not recommended)")
        
        Issue.record("Accessibility permissions not granted. Some tests will be skipped.")
    }
    
    // This test should always pass, just informational
    #expect(true)
}

@Test func testAccessibilityPermissionWithFallback() throws {
    let hasPermissions = AXDumper.checkAccessibilityPermissions()
    
    if hasPermissions {
        print("✅ Testing with accessibility permissions...")
        
        // Test actual dumping
        do {
            let apps = AXDumper.listRunningApps()
            #expect(!apps.isEmpty)
            
            // Try to dump Finder (always available)
            let finderDump = try AXDumper.dump(bundleIdentifier: "com.apple.finder")
            #expect(!finderDump.isEmpty)
            #expect(finderDump.contains("Role: AXApplication"))
            
            print("🗂️ Successfully dumped Finder app")
            print("   Size: \(finderDump.count) bytes")
            
            // Test JSON conversion
            let jsonString = try AXConverter.convert(axDump: finderDump)
            #expect(!jsonString.isEmpty)
            
            print("   JSON Size: \(jsonString.count) bytes")
            print("   Compression Ratio: \(String(format: "%.2f", Double(jsonString.count) / Double(finderDump.count)))")
            
        } catch AXDumperError.accessibilityPermissionDenied {
            Issue.record("Permission check passed but dumping failed - possible race condition")
        }
        
    } else {
        print("⚠️ No accessibility permissions - testing fallback behavior...")
        
        // Test that errors are properly thrown
        #expect(throws: AXDumperError.accessibilityPermissionDenied) {
            try AXDumper.dump(bundleIdentifier: "com.apple.finder")
        }
        
        // Note: dumpFrontmost() method doesn't exist in AXDumper
        // #expect(throws: AXDumperError.accessibilityPermissionDenied) {
        //     try AXDumper.dumpFrontmost()
        // }
        
        print("✅ Error handling works correctly without permissions")
    }
}

@Test func testSimpleAppListWithoutPermissions() throws {
    // This should work without accessibility permissions
    let apps = AXDumper.listRunningApps()
    
    #expect(!apps.isEmpty)
    
    print("📱 Running Apps (no permissions needed):")
    for app in apps.prefix(5) {
        print("   \(app.name) - \(app.bundleId ?? "no bundle ID")")
    }
    
    // Finder should always be in the list
    let finderExists = apps.contains { $0.bundleId == "com.apple.finder" }
    #expect(finderExists)
}

@Test func testPermissionRequestFlow() throws {
    let initialPermissions = AXDumper.checkAccessibilityPermissions()
    
    print("🔐 Initial permissions: \(initialPermissions)")
    
    if !initialPermissions {
        print("📋 Would show permission request dialog...")
        // Note: We don't actually call requestAccessibilityPermissions() 
        // because it shows a system dialog during tests
        
        print("💡 In a real app, you would call:")
        print("   let granted = AXDumper.requestAccessibilityPermissions()")
        print("   This shows the system permission dialog")
    }
    
    // Test error messages
    do {
        _ = try AXDumper.dump(bundleIdentifier: "com.apple.finder")
        if !initialPermissions {
            Issue.record("Expected permission error but dump succeeded")
        }
    } catch AXDumperError.accessibilityPermissionDenied {
        #expect(!initialPermissions) // Should only get this error if no permissions
        print("✅ Correctly threw permission denied error")
    } catch {
        throw error // Re-throw unexpected errors
    }
}

@Test func testErrorMessagesAreHelpful() throws {
    let permissionError = AXDumperError.accessibilityPermissionDenied
    let appNotFoundError = AXDumperError.applicationNotFound("com.nonexistent.app")
    let noFrontmostError = AXDumperError.noFrontmostApp
    let noBundleIdError = AXDumperError.noBundleIdentifier
    
    // Test that error descriptions are helpful
    #expect(permissionError.errorDescription?.contains("Accessibility permission") == true)
    #expect(permissionError.errorDescription?.contains("System Preferences") == true)
    
    #expect(appNotFoundError.errorDescription?.contains("com.nonexistent.app") == true)
    #expect(appNotFoundError.errorDescription?.contains("not found") == true)
    
    #expect(noFrontmostError.errorDescription?.contains("frontmost") == true)
    #expect(noBundleIdError.errorDescription?.contains("bundle identifier") == true)
    
    print("✅ All error messages are descriptive and helpful")
}
