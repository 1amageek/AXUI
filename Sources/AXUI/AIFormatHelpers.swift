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

// MARK: - Role Description Filter (shared between AIElementConverter and AIElementEncoder)

/// Filters out redundant role descriptions that don't add meaningful information.
/// Shared implementation to avoid duplication across converter and encoder.
public enum RoleDescriptionFilter {
    /// Redundant role description patterns keyed by role name (multilingual)
    static let redundantDescriptions: [String: Set<String>] = [
        "Application": [
            "アプリケーション",
            "Application",
            "应用程序",
            "應用程式",
            "애플리케이션"
        ],
        "Window": [
            "標準ウインドウ", "ウインドウ", "ウィンドウ",
            "Window", "Standard Window",
            "窗口", "标准窗口",
            "視窗", "標準視窗",
            "윈도우", "창"
        ],
        "MenuItem": [
            "メニュー項目", "メニューアイテム",
            "Menu Item", "MenuItem",
            "菜单项",
            "選單項目",
            "메뉴 항목"
        ],
        "MenuBarItem": [
            "メニューバー項目", "メニューバーアイテム",
            "Menu Bar Item", "MenuBar Item",
            "菜单栏项",
            "選單列項目",
            "메뉴 바 항목"
        ],
        "Menu": [
            "メニュー",
            "Menu",
            "菜单",
            "選單",
            "메뉴"
        ],
        "Toolbar": [
            "ツールバー",
            "Toolbar", "Tool Bar",
            "工具栏",
            "工具列",
            "툴바", "도구 모음"
        ],
        "MenuBar": [
            "メニューバー",
            "Menu Bar", "MenuBar",
            "菜单栏",
            "選單列",
            "메뉴 바"
        ],
        "Button": [
            "ボタン",
            "Button",
            "按钮",
            "按鈕",
            "버튼"
        ],
        "Text": [
            "テキスト", "静的テキスト",
            "Text", "Static Text",
            "文本", "静态文本",
            "文字", "靜態文字",
            "텍스트", "정적 텍스트"
        ],
        "Image": [
            "イメージ", "画像",
            "Image",
            "图像",
            "圖像",
            "이미지"
        ],
        "Field": [
            "テキストフィールド", "フィールド",
            "Text Field", "TextField", "Field",
            "文本框", "文本字段",
            "文字欄位", "文字框",
            "텍스트 필드", "필드"
        ],
        "Check": [
            "チェックボックス",
            "Check Box", "Checkbox", "CheckBox",
            "复选框",
            "核取方塊",
            "체크박스", "체크 박스"
        ],
        "Radio": [
            "ラジオボタン",
            "Radio Button", "RadioButton",
            "单选按钮",
            "單選按鈕",
            "라디오 버튼"
        ],
        "Slider": [
            "スライダー",
            "Slider",
            "滑块",
            "滑桿",
            "슬라이더"
        ],
        "PopUp": [
            "ポップアップボタン", "ポップアップ",
            "Pop Up Button", "PopUp Button", "Popup Button",
            "弹出按钮",
            "彈出按鈕",
            "팝업 버튼"
        ],
        "Tab": [
            "タブ",
            "Tab",
            "标签",
            "標籤",
            "탭"
        ],
        "Link": [
            "リンク",
            "Link",
            "链接",
            "連結",
            "링크"
        ],
        "Scroll": [
            "スクロールエリア", "スクロール領域",
            "Scroll Area", "ScrollArea",
            "滚动区域",
            "捲動區域",
            "스크롤 영역"
        ],
        "ComboBox": [
            "コンボボックス",
            "Combo Box", "ComboBox",
            "组合框",
            "組合框",
            "콤보 박스"
        ],
        "Disclosure": [
            "ディスクロージャー三角形",
            "Disclosure Triangle", "DisclosureTriangle",
            "展开三角",
            "展開三角形",
            "펼침 삼각형"
        ],
        "Outline": [
            "アウトライン",
            "Outline",
            "大纲",
            "大綱",
            "아웃라인"
        ],
        "TabGroup": [
            "タブグループ",
            "Tab Group", "TabGroup",
            "标签组",
            "標籤群組",
            "탭 그룹"
        ],
        "SplitGroup": [
            "スプリットグループ",
            "Split Group", "SplitGroup",
            "拆分组",
            "分隔群組",
            "분할 그룹"
        ],
        "Cell": [
            "セル",
            "Cell",
            "单元格",
            "儲存格",
            "셀"
        ],
        "Row": [
            "行",
            "Row",
            "행"
        ],
        "Column": [
            "列",
            "Column",
            "열"
        ]
    ]

    /// Filter out redundant role descriptions.
    /// Returns nil if the description is redundant for the given role, otherwise returns the description.
    public static func filter(role: String?, roleDescription: String?) -> String? {
        guard let roleDescription = roleDescription?.trimmingCharacters(in: .whitespaces),
              !roleDescription.isEmpty,
              let role = role else {
            return nil
        }

        if let redundantSet = redundantDescriptions[role],
           redundantSet.contains(roleDescription) {
            return nil
        }

        return roleDescription
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
