import Foundation

/// Helper functions for CLI to convert various formats to AI-optimized JSON
public struct AIFormatHelpers {
    private static let converter = AIElementConverter()
    
    // MARK: - CLI Helper Functions
    
    /// Convert AX dump string to AI format (used by CLI commands)
    public static func convertToAIFormat(axDump: String, pretty: Bool = false) throws -> String {
        do {
            return try converter.convertFromAXDump(axDump, pretty: pretty)
        } catch let parseError as AXParseError {
            throw AIConversionError.invalidAXDump("AX parse failed: \(parseError.localizedDescription)")
        } catch {
            throw AIConversionError.encodingFailed("Conversion failed: \(error.localizedDescription)")
        }
    }
    
    /// Convert flat AXElement array to AI format (used by CLI query commands)
    public static func convertFlatToAIFormat(elements: [AXElement], pretty: Bool = false) throws -> String {
        do {
            return try converter.convertFlat(from: elements, pretty: pretty)
        } catch {
            throw AIConversionError.encodingFailed("Flat conversion failed: \(error.localizedDescription)")
        }
    }
    
    /// Convert hierarchical AXElement to AI format
    public static func convertHierarchicalToAIFormat(element: AXElement, pretty: Bool = false) throws -> String {
        do {
            return try converter.convertHierarchical(from: element, pretty: pretty)
        } catch {
            throw AIConversionError.encodingFailed("Hierarchical conversion failed: \(error.localizedDescription)")
        }
    }
    
    /// Convert hierarchical AXElement array to AI format
    public static func convertHierarchicalToAIFormat(elements: [AXElement], pretty: Bool = false) throws -> String {
        do {
            return try converter.convertHierarchical(from: elements, pretty: pretty)
        } catch {
            throw AIConversionError.encodingFailed("Hierarchical array conversion failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Format Detection and Auto-Conversion
    
    /// Auto-detect input format and convert to AI format
    public static func autoConvertToAIFormat(input: Any, pretty: Bool = false) throws -> String {
        switch input {
        case let axDump as String:
            return try convertToAIFormat(axDump: axDump, pretty: pretty)
        case let elements as [AXElement]:
            // Determine if it's hierarchical or flat based on children presence
            let hasChildren = elements.contains { $0.children != nil && !$0.children!.isEmpty }
            if hasChildren {
                return try convertHierarchicalToAIFormat(elements: elements, pretty: pretty)
            } else {
                return try convertFlatToAIFormat(elements: elements, pretty: pretty)
            }
        case let element as AXElement:
            return try convertHierarchicalToAIFormat(element: element, pretty: pretty)
        default:
            throw AIConversionError.unsupportedFormat("Unsupported input type: \(type(of: input))")
        }
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
            throw AIConversionError.encodingFailed("Invalid UTF-8 string")
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
                throw AIConversionError.encodingFailed("Invalid AI format JSON: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Batch Processing
    
    /// Convert multiple inputs in batch
    public static func batchConvert(
        inputs: [Any],
        pretty: Bool = false,
        continueOnError: Bool = true
    ) -> BatchConversionResult {
        var results: [String] = []
        var errors: [Error] = []
        
        for (index, input) in inputs.enumerated() {
            do {
                let converted = try autoConvertToAIFormat(input: input, pretty: pretty)
                results.append(converted)
            } catch {
                errors.append(BatchConversionError.itemFailed(index: index, error: error))
                if !continueOnError {
                    break
                }
                results.append("") // Placeholder for failed conversion
            }
        }
        
        return BatchConversionResult(
            results: results,
            errors: errors,
            successCount: results.filter { !$0.isEmpty }.count,
            totalCount: inputs.count
        )
    }
}

// MARK: - Supporting Types

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