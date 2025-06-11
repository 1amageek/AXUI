import Foundation

/// Helper functions for CLI to convert various formats to AI-optimized JSON
public struct AIFormatHelpers {
    private static let converter = AIElementConverter()
    
    // MARK: - CLI Helper Functions
    
    /// Convert flat AXElement array to AI format (used by CLI query commands)
    public static func convertToAIFormat(elements: [AXElement], pretty: Bool = false) throws -> String {
        return try converter.convert(from: elements, pretty: pretty)
    }    
    
    // MARK: - Statistics and Analysis
    
    /// Get conversion statistics
    public static func getConversionStats(
        originalSize: Int,
        aiSize: Int,
        compressionEnabled: Bool = false
    ) -> ConversionStats {
        let compressionRatio = Double(aiSize) / Double(originalSize)
        let spaceSaved = originalSize - aiSize
        let spaceSavedPercentage = (Double(spaceSaved) / Double(originalSize)) * 100
        
        return ConversionStats(
            originalSize: originalSize,
            aiSize: aiSize,
            compressionRatio: compressionRatio,
            spaceSaved: spaceSaved,
            spaceSavedPercentage: spaceSavedPercentage,
            compressionEnabled: compressionEnabled
        )
    }
    
    /// Validate AI format output
    public static func validateAIFormat(_ jsonString: String) throws -> Bool {
        guard let data = jsonString.data(using: .utf8) else {
            throw ValidationError.invalidUTF8String
        }
        
        do {
            // Try to decode as AIElement
            _ = try JSONDecoder().decode(AIElement.self, from: data)
            return true
        } catch {
            // Try to decode as array of AIElements
            do {
                _ = try JSONDecoder().decode([AIElement].self, from: data)
                return true
            } catch {
                throw ValidationError.invalidAIFormatJSON(error.localizedDescription)
            }
        }
    }
}

// MARK: - Supporting Types

/// Validation errors for AI format helpers
public enum ValidationError: Error, LocalizedError {
    case invalidUTF8String
    case invalidAIFormatJSON(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidUTF8String:
            return "Invalid UTF-8 string"
        case .invalidAIFormatJSON(let details):
            return "Invalid AI format JSON: \(details)"
        }
    }
}

/// Conversion statistics
public struct ConversionStats {
    public let originalSize: Int
    public let aiSize: Int
    public let compressionRatio: Double
    public let spaceSaved: Int
    public let spaceSavedPercentage: Double
    public let compressionEnabled: Bool
    
    public var formattedCompressionRatio: String {
        return String(format: "%.1f%%", compressionRatio * 100)
    }
    
    public var formattedSpaceSaved: String {
        return String(format: "%.1f%%", spaceSavedPercentage)
    }
}

/// Batch conversion result
public struct BatchConversionResult {
    public let results: [String]
    public let errors: [Error]
    public let successCount: Int
    public let totalCount: Int
    
    public var hasErrors: Bool {
        return !errors.isEmpty
    }
    
    public var successRate: Double {
        return Double(successCount) / Double(totalCount)
    }
    
    public var formattedSuccessRate: String {
        return String(format: "%.1f%%", successRate * 100)
    }
}

/// Batch conversion errors
public enum BatchConversionError: Error, LocalizedError {
    case itemFailed(index: Int, error: Error)
    
    public var errorDescription: String? {
        switch self {
        case .itemFailed(let index, let error):
            return "Item at index \(index) failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Format Utilities

extension AIFormatHelpers {
    /// Format bytes for human-readable display
    public static func formatBytes(_ bytes: Int) -> String {
        let units = ["B", "KB", "MB", "GB"]
        var size = Double(bytes)
        var unitIndex = 0
        
        while size >= 1024 && unitIndex < units.count - 1 {
            size /= 1024
            unitIndex += 1
        }
        
        return String(format: "%.1f %@", size, units[unitIndex])
    }
    
    /// Pretty print conversion statistics
    public static func printConversionStats(_ stats: ConversionStats) {
        print("\n📊 AI Conversion Statistics:")
        print("   Original Size:    \(formatBytes(stats.originalSize))")
        print("   AI Format Size:   \(formatBytes(stats.aiSize)) (\(stats.formattedCompressionRatio))")
        print("   Space Saved:      \(formatBytes(stats.spaceSaved)) (\(stats.formattedSpaceSaved))")
        if stats.compressionEnabled {
            print("   Compression:      Enabled")
        }
    }
    
    /// Pretty print batch conversion results
    public static func printBatchResults(_ result: BatchConversionResult) {
        print("\n📋 Batch Conversion Results:")
        print("   Total Items:      \(result.totalCount)")
        print("   Successful:       \(result.successCount)")
        print("   Failed:           \(result.errors.count)")
        print("   Success Rate:     \(result.formattedSuccessRate)")
        
        if result.hasErrors {
            print("\n❌ Errors:")
            for error in result.errors {
                print("   • \(error.localizedDescription)")
            }
        }
    }
}
