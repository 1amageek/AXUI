import Foundation

/// Converter for transforming various input formats to AI-optimized elements
public struct AIElementConverter: Sendable {
    private let encoder: AIElementEncoder
    
    public init() {
        self.encoder = AIElementEncoder()
    }
    
    // MARK: - Hierarchical Structure Conversion
    
    /// Convert hierarchical AXElement structure to AI format
    public func convertHierarchical(from axElement: AXElement, pretty: Bool = false) throws -> String {
        let aiElement = encoder.convert(from: axElement)
        return try encoder.encode(aiElement, pretty: pretty)
    }
    
    /// Convert hierarchical AXElement array to AI format
    public func convertHierarchical(from axElements: [AXElement], pretty: Bool = false) throws -> String {
        let aiElements = encoder.convert(from: axElements)
        return try encoder.encode(aiElements, pretty: pretty)
    }
    
    // MARK: - Flat Array Conversion
    
    /// Convert flat AXElement array to AI format (preserves flat structure)
    public func convertFlat(from axElements: [AXElement], pretty: Bool = false) throws -> String {
        // For flat arrays, we convert each element individually without nested children
        let aiElements = axElements.map { axElement in
            convertToFlatAIElement(from: axElement)
        }
        return try encoder.encode(aiElements, pretty: pretty)
    }
    
    // MARK: - AX Dump String Conversion
    
    /// Convert AX dump string to AI format
    public func convertFromAXDump(_ axDump: String, pretty: Bool = false) throws -> String {
        // Parse AX dump to properties
        let properties = try AXParser.parse(content: axDump)
        
        // Convert to UI node
        let uiNode = properties.toUINode()
        
        // Convert UI node to AI element
        let aiElement = convertUINodeToAIElement(uiNode)
        
        return try encoder.encode(aiElement, pretty: pretty)
    }
    
    // MARK: - Private Conversion Methods
    
    /// Convert AXElement to flat AI element (without nested children structure)
    private func convertToFlatAIElement(from axElement: AXElement) -> AIElement {
        let normalizedRole = normalizeRole(axElement.role)
        let value = axElement.description
        let desc = filterRedundantDescription(role: normalizedRole, roleDescription: axElement.roleDescription)
        let bounds = axElement.bounds
        let state = convertState(from: axElement.state)
        
        // For flat representation, we don't include children structure
        return AIElement(
            role: normalizedRole,
            value: value,
            desc: desc,
            bounds: bounds,
            state: state?.isDefault == false ? state : nil,
            children: nil
        )
    }
    
    /// Convert UINode to AIElement
    private func convertUINodeToAIElement(_ uiNode: UINode) -> AIElement {
        switch uiNode {
        case .normal(let uiNodeObject):
            return convertUINodeObjectToAIElement(uiNodeObject)
        case .group(let nodes):
            // Convert group nodes to AI children
            let children = nodes.map { node in
                AIElement.Node.normal(convertUINodeToAIElement(node))
            }
            
            // Return group-optimized element
            return AIElement(
                role: nil, // Group role omitted
                value: nil,
                desc: nil,
                bounds: nil,
                state: nil,
                children: children
            )
        }
    }
    
    /// Convert UINodeObject to AIElement
    private func convertUINodeObjectToAIElement(_ uiObject: UINodeObject) -> AIElement {
        let state = convertUINodeStateToAI(uiObject.state)
        let children = uiObject.children?.map { node in
            AIElement.Node.normal(convertUINodeToAIElement(node))
        }
        
        return AIElement(
            role: uiObject.role,
            value: uiObject.value,
            desc: nil, // UINodeObject doesn't have desc field
            bounds: uiObject.bounds,
            state: state?.isDefault == false ? state : nil,
            children: children
        )
    }
    
    /// Convert UINodeState to AIElementState
    private func convertUINodeStateToAI(_ uiState: UINodeState?) -> AIElementState? {
        guard let uiState = uiState else { return nil }
        
        return AIElementState(
            selected: uiState.selected,
            enabled: uiState.enabled,
            focused: uiState.focused
        )
    }
    
    /// Convert AXElementState to AIElementState
    private func convertState(from axState: AXElementState?) -> AIElementState? {
        guard let axState = axState else { return nil }
        
        return AIElementState(
            selected: axState.selected,
            enabled: axState.enabled,
            focused: axState.focused
        )
    }
    
    /// Normalize role names for AI format
    private func normalizeRole(_ role: String?) -> String? {
        guard let role = role else { return nil }
        
        var normalized = role.hasPrefix("AX") ? String(role.dropFirst(2)) : role
        
        // Further normalize common roles
        switch normalized {
        case "StaticText":
            normalized = "Text"
        case "ScrollArea":
            normalized = "Scroll"
        case "TextField":
            normalized = "Field"
        case "CheckBox":
            normalized = "Check"
        case "RadioButton":
            normalized = "Radio"
        case "PopUpButton":
            normalized = "PopUp"
        case "GenericElement":
            normalized = "Generic"
        default:
            break
        }
        
        return normalized
    }
    
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
}

// MARK: - Batch Conversion Utilities

extension AIElementConverter {
    /// Convert multiple AXElement hierarchies to AI format
    public func convertMultipleHierarchies(
        from axElements: [AXElement], 
        pretty: Bool = false
    ) throws -> [String] {
        return try axElements.map { axElement in
            try convertHierarchical(from: axElement, pretty: pretty)
        }
    }
    
    /// Convert and merge multiple flat arrays
    public func convertAndMergeFlat(
        from arrays: [[AXElement]], 
        pretty: Bool = false
    ) throws -> String {
        let mergedElements = arrays.flatMap { $0 }
        return try convertFlat(from: mergedElements, pretty: pretty)
    }
}

// MARK: - Error Handling

public enum AIConversionError: Error, LocalizedError {
    case invalidAXDump(String)
    case encodingFailed(String)
    case unsupportedFormat(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidAXDump(let details):
            return "Invalid AX dump format: \(details)"
        case .encodingFailed(let details):
            return "Failed to encode AI format: \(details)"
        case .unsupportedFormat(let details):
            return "Unsupported input format: \(details)"
        }
    }
}