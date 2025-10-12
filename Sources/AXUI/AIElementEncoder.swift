import Foundation
import CryptoKit

/// Encoder for converting AX elements to AI-optimized format
public final class AIElementEncoder: Sendable {
    private let minifiedEncoder: JSONEncoder
    private let prettyEncoder: JSONEncoder
    
    public init() {
        self.minifiedEncoder = JSONEncoder()
        self.minifiedEncoder.outputFormatting = []
        
        self.prettyEncoder = JSONEncoder()
        self.prettyEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }
    
    // MARK: - Public Encoding Methods
    
    /// Encode AIElement to JSON string
    internal func encode(_ element: AIElement, pretty: Bool = false) throws -> String {
        let encoder = pretty ? prettyEncoder : minifiedEncoder
        let data = try encoder.encode(element)
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    /// Encode AIElement array to JSON string
    internal func encode(_ elements: [AIElement], pretty: Bool = false) throws -> String {
        let encoder = pretty ? prettyEncoder : minifiedEncoder
        let data = try encoder.encode(elements)
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    /// Encode AIElement to JSON data
    internal func encodeToData(_ element: AIElement, pretty: Bool = false) throws -> Data {
        let encoder = pretty ? prettyEncoder : minifiedEncoder
        return try encoder.encode(element)
    }
    
    /// Encode AIElement array to JSON data
    internal func encodeToData(_ elements: [AIElement], pretty: Bool = false) throws -> Data {
        let encoder = pretty ? prettyEncoder : minifiedEncoder
        return try encoder.encode(elements)
    }
    
    // MARK: - AXElement to AIElement Conversion
    
    /// Convert AXElement to AIElement
    internal func convert(from axElement: AXElement) -> AIElement {
        return convert(from: axElement, parentPath: [])
    }
    
    /// Convert AXElement to AIElement with hierarchical path tracking
    private func convert(from axElement: AXElement, parentPath: [Int]) -> AIElement {
        // Use the AXElement's existing ID
        let id = axElement.id
        
        // Normalize role (remove AX prefix if present)
        let normalizedRole = axElement.role.rawValue
        
        // Map description to value for AI clarity
        let value = axElement.description

        // Map identifier to name for brevity
        let name = axElement.identifier

        // Map roleDescription to desc, but filter out redundant descriptions
        let desc = filterRedundantDescription(role: normalizedRole, roleDescription: axElement.roleDescription)

        // Convert bounds
        let bounds = axElement.bounds

        // Convert state
        let state = convertState(from: axElement.state)

        // Convert children with path tracking
        let children = convertChildren(from: axElement.children, parentPath: parentPath)
        
        // Apply Group optimization rules
        if normalizedRole == "Group" {
            return applyGroupOptimization(
                id: id,
                value: value,
                name: name,
                desc: desc,
                bounds: bounds,
                state: state,
                children: children
            )
        }
        
        return AIElement(
            id: id,
            role: axElement.role,
            value: value,
            name: name,
            desc: desc,
            bounds: bounds,
            state: state?.isDefault == false ? state : nil,
            children: children
        )
    }
    
    /// Convert array of AXElements to AIElements
    internal func convert(from axElements: [AXElement]) -> [AIElement] {
        return axElements.map { convert(from: $0) }
    }
    
    // MARK: - Private Conversion Methods
    
    
    /// Filter out redundant role descriptions that don't add meaningful information
    private func filterRedundantDescription(role: String?, roleDescription: String?) -> String? {
        guard let roleDescription = roleDescription?.trimmingCharacters(in: .whitespaces),
              !roleDescription.isEmpty,
              let role = role else {
            return nil
        }
        
        // Define truly redundant role description patterns (multilingual support)
        let redundantDescriptions: [String: Set<String>] = [
            "Application": [
                // Japanese
                "アプリケーション",
                // English
                "Application",
                // Chinese (Simplified)
                "应用程序",
                // Chinese (Traditional)
                "應用程式",
                // Korean
                "애플리케이션"
            ],
            "Window": [
                // Japanese
                "標準ウインドウ", "ウインドウ", "ウィンドウ",
                // English
                "Window", "Standard Window",
                // Chinese (Simplified)
                "窗口", "标准窗口",
                // Chinese (Traditional)
                "視窗", "標準視窗",
                // Korean
                "윈도우", "창"
            ],
            "MenuItem": [
                // Japanese
                "メニュー項目", "メニューアイテム",
                // English
                "Menu Item", "MenuItem",
                // Chinese (Simplified)
                "菜单项",
                // Chinese (Traditional)
                "選單項目",
                // Korean
                "메뉴 항목"
            ],
            "MenuBarItem": [
                // Japanese
                "メニューバー項目", "メニューバーアイテム",
                // English
                "Menu Bar Item", "MenuBar Item",
                // Chinese (Simplified)
                "菜单栏项",
                // Chinese (Traditional)
                "選單列項目",
                // Korean
                "메뉴 바 항목"
            ],
            "Menu": [
                // Japanese
                "メニュー",
                // English
                "Menu",
                // Chinese (Simplified)
                "菜单",
                // Chinese (Traditional)
                "選單",
                // Korean
                "메뉴"
            ],
            "Toolbar": [
                // Japanese
                "ツールバー",
                // English
                "Toolbar", "Tool Bar",
                // Chinese (Simplified)
                "工具栏",
                // Chinese (Traditional)
                "工具列",
                // Korean
                "툴바", "도구 모음"
            ],
            "MenuBar": [
                // Japanese
                "メニューバー",
                // English
                "Menu Bar", "MenuBar",
                // Chinese (Simplified)
                "菜单栏",
                // Chinese (Traditional)
                "選單列",
                // Korean
                "메뉴 바"
            ],
            "Button": [
                // Japanese
                "ボタン",
                // English
                "Button",
                // Chinese (Simplified)
                "按钮",
                // Chinese (Traditional)
                "按鈕",
                // Korean
                "버튼"
            ],
            "Text": [
                // Japanese
                "テキスト", "静的テキスト",
                // English
                "Text", "Static Text",
                // Chinese (Simplified)
                "文本", "静态文本",
                // Chinese (Traditional)
                "文字", "靜態文字",
                // Korean
                "텍스트", "정적 텍스트"
            ],
            "Image": [
                // Japanese
                "イメージ", "画像",
                // English
                "Image",
                // Chinese (Simplified)
                "图像",
                // Chinese (Traditional)
                "圖像",
                // Korean
                "이미지"
            ],
            "Field": [
                // Japanese
                "テキストフィールド", "フィールド",
                // English
                "Text Field", "TextField", "Field",
                // Chinese (Simplified)
                "文本框", "文本字段",
                // Chinese (Traditional)
                "文字欄位", "文字框",
                // Korean
                "텍스트 필드", "필드"
            ],
            "Check": [
                // Japanese
                "チェックボックス",
                // English
                "Check Box", "Checkbox", "CheckBox",
                // Chinese (Simplified)
                "复选框",
                // Chinese (Traditional)
                "核取方塊",
                // Korean
                "체크박스", "체크 박스"
            ],
            "Radio": [
                // Japanese
                "ラジオボタン",
                // English
                "Radio Button", "RadioButton",
                // Chinese (Simplified)
                "单选按钮",
                // Chinese (Traditional)
                "單選按鈕",
                // Korean
                "라디오 버튼"
            ],
            "Slider": [
                // Japanese
                "スライダー",
                // English
                "Slider",
                // Chinese (Simplified)
                "滑块",
                // Chinese (Traditional)
                "滑桿",
                // Korean
                "슬라이더"
            ],
            "PopUp": [
                // Japanese
                "ポップアップボタン", "ポップアップ",
                // English
                "Pop Up Button", "PopUp Button", "Popup Button",
                // Chinese (Simplified)
                "弹出按钮",
                // Chinese (Traditional)
                "彈出按鈕",
                // Korean
                "팝업 버튼"
            ],
            "Tab": [
                // Japanese
                "タブ",
                // English
                "Tab",
                // Chinese (Simplified)
                "标签",
                // Chinese (Traditional)
                "標籤",
                // Korean
                "탭"
            ],
            "Link": [
                // Japanese
                "リンク",
                // English
                "Link",
                // Chinese (Simplified)
                "链接",
                // Chinese (Traditional)
                "連結",
                // Korean
                "링크"
            ],
            "Scroll": [
                // Japanese
                "スクロールエリア", "スクロール領域",
                // English
                "Scroll Area", "ScrollArea",
                // Chinese (Simplified)
                "滚动区域",
                // Chinese (Traditional)
                "捲動區域",
                // Korean
                "스크롤 영역"
            ]
        ]
        
        // Check if the description is redundant for this role
        if let redundantSet = redundantDescriptions[role],
           redundantSet.contains(roleDescription) {
            return nil
        }
        
        // Note: Functional descriptions like "閉じるボタン", "検索テキストフィールド" etc.
        // are NOT filtered out as they provide important functional context
        // that helps identify the specific purpose of UI elements
        
        // Return the description - functional descriptions are preserved
        return roleDescription
    }
    
    private func convertState(from axState: AXElementState?) -> AIElementState? {
        guard let axState = axState else { return nil }
        
        let state = AIElementState(
            selected: axState.selected,
            enabled: axState.enabled,
            focused: axState.focused
        )
        
        return state.isDefault ? nil : state
    }
    
    private func convertChildren(from axChildren: [AXElement]?, parentPath: [Int]) -> [AIElement.Node]? {
        guard let axChildren = axChildren, !axChildren.isEmpty else { return nil }
        
        return axChildren.enumerated().map { index, child in
            let childPath = parentPath + [index]
            let aiChild = convert(from: child, parentPath: childPath)
            return .normal(aiChild)
        }
    }
    
    private func applyGroupOptimization(
        id: String,
        value: String?,
        name: String?,
        desc: String?,
        bounds: [Int]?,
        state: AIElementState?,
        children: [AIElement.Node]?
    ) -> AIElement {
        // G-Minimal: Use array representation if only default attributes
        let hasNonDefaultAttributes = value != nil ||
                                     name != nil ||
                                     desc != nil ||
                                     bounds != nil ||
                                     (state?.isDefault == false)

        if !hasNonDefaultAttributes && children != nil {
            // G-Minimal: Return element with nil role for array representation
            return AIElement(
                id: id,
                role: nil,
                value: nil,
                name: nil,
                desc: nil,
                bounds: nil,
                state: nil,
                children: children
            )
        } else {
            // G-Object: Standard object with role omitted
            return AIElement(
                id: id,
                role: nil, // Group role is omitted in AI format
                value: value,
                name: name,
                desc: desc,
                bounds: bounds,
                state: state?.isDefault == false ? state : nil,
                children: children
            )
        }
    }
}

// MARK: - Special Group Handling

extension AIElement {
    /// Check if this element should be represented as a group array
    public var shouldUseGroupArrayRepresentation: Bool {
        return role == nil &&
               value == nil &&
               name == nil &&
               desc == nil &&
               bounds == nil &&
               state == nil &&
               children != nil
    }
}

// MARK: - Custom Encoding for Group Optimization

extension AIElement {
    public func encode(to encoder: Encoder) throws {
        // Check if this should be encoded as a group array
        if shouldUseGroupArrayRepresentation, let children = children {
            // Encode as array of nodes directly
            var container = encoder.singleValueContainer()
            try container.encode(children)
        } else {
            // Standard object encoding
            var container = encoder.container(keyedBy: AIElementCodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encodeIfPresent(role, forKey: .role)
            try container.encodeIfPresent(value, forKey: .value)
            try container.encodeIfPresent(name, forKey: .name)
            try container.encodeIfPresent(desc, forKey: .desc)
            try container.encodeIfPresent(bounds, forKey: .bounds)
            try container.encodeIfPresent(state, forKey: .state)
            try container.encodeIfPresent(children, forKey: .children)
        }
    }
}

private enum AIElementCodingKeys: String, CodingKey, Sendable {
    case id, role, value, name, desc, bounds, state, children
}