import Foundation

/// Accessibility element roles based on NSAccessibility constants
/// All roles follow the project convention of removing "AX" prefixes
public enum Role: String, Codable, CaseIterable, Sendable {
    // Application and system
    case application = "Application"
    case systemWide = "SystemWide"
    
    // Windows and containers
    case window = "Window"
    case sheet = "Sheet"
    case drawer = "Drawer"
    case popover = "Popover"
    
    // Layout and grouping
    case group = "Group"
    case layoutArea = "LayoutArea"
    case layoutItem = "LayoutItem"
    case matte = "Matte"
    case growArea = "GrowArea"
    
    // Controls
    case button = "Button"
    case popUpButton = "PopUpButton"
    case menuButton = "MenuButton"
    case checkBox = "CheckBox"
    case radioButton = "RadioButton"
    case radioGroup = "RadioGroup"
    case slider = "Slider"
    case incrementor = "Incrementor"
    case comboBox = "ComboBox"
    case disclosureTriangle = "DisclosureTriangle"
    case colorWell = "ColorWell"
    case link = "Link"
    
    // Text elements
    case textField = "TextField"
    case textArea = "TextArea"
    case staticText = "StaticText"
    
    // Indicators
    case busyIndicator = "BusyIndicator"
    case progressIndicator = "ProgressIndicator"
    case levelIndicator = "LevelIndicator"
    case valueIndicator = "ValueIndicator"
    case relevanceIndicator = "RelevanceIndicator"
    
    // Collections and tables
    case list = "List"
    case table = "Table"
    case outline = "Outline"
    case grid = "Grid"
    case browser = "Browser"
    case cell = "Cell"
    case row = "Row"
    case column = "Column"
    
    // Navigation and menus
    case menu = "Menu"
    case menuBar = "MenuBar"
    case menuBarItem = "MenuBarItem"
    case menuItem = "MenuItem"
    case toolbar = "Toolbar"
    case tabGroup = "TabGroup"
    
    // Scrolling
    case scrollArea = "ScrollArea"
    case scrollBar = "ScrollBar"
    case splitter = "Splitter"
    case splitGroup = "SplitGroup"
    case handle = "Handle"
    
    // Media and graphics
    case image = "Image"
    
    // Measurement and tools
    case ruler = "Ruler"
    case rulerMarker = "RulerMarker"
    
    // Help and information
    case helpTag = "HelpTag"
    
    // Web and document
    case pageRole = "PageRole"
    case webAreaRole = "WebAreaRole"
    case headingRole = "HeadingRole"
    case listMarkerRole = "ListMarkerRole"
    case dateTimeAreaRole = "DateTimeAreaRole"
    
    // Fallback
    case unknown = "Unknown"
    
    // Project-specific normalized roles (from AXDumper)
    case text = "Text"           // Normalized from StaticText
    case scroll = "Scroll"       // Normalized from ScrollArea
    case field = "Field"         // Normalized from TextField
    case check = "Check"         // Normalized from CheckBox
    case radio = "Radio"         // Normalized from RadioButton
    case popUp = "PopUp"         // Normalized from PopUpButton
    case generic = "Generic"     // Normalized from GenericElement
    
    /// Initialize from raw string value, handling both prefixed and non-prefixed formats
    public init?(rawValue: String) {
        // Try direct match first
        if let role = Role.allCases.first(where: { $0.rawValue == rawValue }) {
            self = role
            return
        }
        
        // Try with AX prefix removed
        let cleanValue = rawValue.hasPrefix("AX") ? String(rawValue.dropFirst(2)) : rawValue
        if let role = Role.allCases.first(where: { $0.rawValue == cleanValue }) {
            self = role
            return
        }
        
        // Handle case variations and common mappings
        switch cleanValue.lowercased() {
        case "application":
            self = .application
        case "systemwide":
            self = .systemWide
        case "window":
            self = .window
        case "sheet":
            self = .sheet
        case "drawer":
            self = .drawer
        case "popover":
            self = .popover
        case "group":
            self = .group
        case "layoutarea":
            self = .layoutArea
        case "layoutitem":
            self = .layoutItem
        case "matte":
            self = .matte
        case "growarea":
            self = .growArea
        case "button":
            self = .button
        case "popupbutton":
            self = .popUpButton
        case "menubutton":
            self = .menuButton
        case "checkbox":
            self = .checkBox
        case "radiobutton":
            self = .radioButton
        case "radiogroup":
            self = .radioGroup
        case "slider":
            self = .slider
        case "incrementor":
            self = .incrementor
        case "combobox":
            self = .comboBox
        case "disclosuretriangle":
            self = .disclosureTriangle
        case "colorwell":
            self = .colorWell
        case "link":
            self = .link
        case "textfield":
            self = .textField
        case "textarea":
            self = .textArea
        case "statictext":
            self = .staticText
        case "busyindicator":
            self = .busyIndicator
        case "progressindicator":
            self = .progressIndicator
        case "levelindicator":
            self = .levelIndicator
        case "valueindicator":
            self = .valueIndicator
        case "relevanceindicator":
            self = .relevanceIndicator
        case "list":
            self = .list
        case "table":
            self = .table
        case "outline":
            self = .outline
        case "grid":
            self = .grid
        case "browser":
            self = .browser
        case "cell":
            self = .cell
        case "row":
            self = .row
        case "column":
            self = .column
        case "menu":
            self = .menu
        case "menubar":
            self = .menuBar
        case "menubaritem":
            self = .menuBarItem
        case "menuitem":
            self = .menuItem
        case "toolbar":
            self = .toolbar
        case "tabgroup":
            self = .tabGroup
        case "scrollarea":
            self = .scrollArea
        case "scrollbar":
            self = .scrollBar
        case "splitter":
            self = .splitter
        case "splitgroup":
            self = .splitGroup
        case "handle":
            self = .handle
        case "image":
            self = .image
        case "ruler":
            self = .ruler
        case "rulermarker":
            self = .rulerMarker
        case "helptag":
            self = .helpTag
        case "pagerole":
            self = .pageRole
        case "webarearole":
            self = .webAreaRole
        case "headingrole":
            self = .headingRole
        case "listmarkerrole":
            self = .listMarkerRole
        case "datetimearearole":
            self = .dateTimeAreaRole
        // Project-specific normalized mappings
        case "text":
            self = .text
        case "scroll":
            self = .scroll
        case "field":
            self = .field
        case "check":
            self = .check
        case "radio":
            self = .radio
        case "popup":
            self = .popUp
        case "generic":
            self = .generic
        // Additional common variations
        case "genericelement":
            self = .generic
        default:
            self = .unknown
        }
    }
    
    /// Get display name for UI
    public var displayName: String {
        switch self {
        case .systemWide:
            return "System Wide"
        case .layoutArea:
            return "Layout Area"
        case .layoutItem:
            return "Layout Item"
        case .growArea:
            return "Grow Area"
        case .popUpButton:
            return "Pop Up Button"
        case .menuButton:
            return "Menu Button"
        case .checkBox:
            return "Check Box"
        case .radioButton:
            return "Radio Button"
        case .radioGroup:
            return "Radio Group"
        case .comboBox:
            return "Combo Box"
        case .disclosureTriangle:
            return "Disclosure Triangle"
        case .colorWell:
            return "Color Well"
        case .textField:
            return "Text Field"
        case .textArea:
            return "Text Area"
        case .staticText:
            return "Static Text"
        case .busyIndicator:
            return "Busy Indicator"
        case .progressIndicator:
            return "Progress Indicator"
        case .levelIndicator:
            return "Level Indicator"
        case .valueIndicator:
            return "Value Indicator"
        case .relevanceIndicator:
            return "Relevance Indicator"
        case .menuBar:
            return "Menu Bar"
        case .menuBarItem:
            return "Menu Bar Item"
        case .menuItem:
            return "Menu Item"
        case .tabGroup:
            return "Tab Group"
        case .scrollArea:
            return "Scroll Area"
        case .scrollBar:
            return "Scroll Bar"
        case .splitGroup:
            return "Split Group"
        case .rulerMarker:
            return "Ruler Marker"
        case .helpTag:
            return "Help Tag"
        case .pageRole:
            return "Page Role"
        case .webAreaRole:
            return "Web Area Role"
        case .headingRole:
            return "Heading Role"
        case .listMarkerRole:
            return "List Marker Role"
        case .dateTimeAreaRole:
            return "Date Time Area Role"
        case .popUp:
            return "Pop Up"
        default:
            return rawValue
        }
    }
    
    /// Check if this role represents an interactive element
    public var isInteractive: Bool {
        switch self {
        case .button, .popUpButton, .menuButton, .checkBox, .radioButton,
             .slider, .incrementor, .comboBox, .disclosureTriangle,
             .colorWell, .link, .textField, .textArea, .menuItem,
             .check, .radio, .popUp, .field:
            return true
        default:
            return false
        }
    }
    
    /// Check if this role represents a container element
    public var isContainer: Bool {
        switch self {
        case .group, .radioGroup, .list, .scrollArea, .splitGroup,
             .table, .outline, .browser, .tabGroup, .row, .column,
             .layoutArea, .layoutItem, .webAreaRole, .grid, .menu,
             .menuBar, .window, .sheet, .drawer, .popover, .toolbar,
             .matte, .scroll:
            return true
        default:
            return false
        }
    }
    
    /// Check if this role represents a text element
    public var isText: Bool {
        switch self {
        case .textField, .textArea, .staticText, .headingRole,
             .text, .field:
            return true
        default:
            return false
        }
    }
    
    /// Convert to the normalized role used in this project
    public var normalized: Role {
        switch self {
        case .staticText:
            return .text
        case .scrollArea:
            return .scroll
        case .textField:
            return .field
        case .checkBox:
            return .check
        case .radioButton:
            return .radio
        case .popUpButton:
            return .popUp
        // Additional normalizations based on common UI patterns
        case .textArea:
            return .field
        case .busyIndicator, .progressIndicator, .levelIndicator, .valueIndicator:
            return .generic
        case .menuButton:
            return .button
        case .incrementor:
            return .button
        case .disclosureTriangle:
            return .button
        case .tabGroup:
            return .group
        case .radioGroup:
            return .group
        case .scrollBar:
            return .scroll
        case .splitGroup:
            return .group
        case .toolbar:
            return .group
        case .menuBar:
            return .group
        case .headingRole:
            return .text
        case .listMarkerRole:
            return .text
        case .helpTag:
            return .text
        case .webAreaRole:
            return .group
        case .pageRole:
            return .group
        case .layoutArea, .layoutItem:
            return .group
        case .growArea:
            return .generic
        case .handle:
            return .generic
        case .splitter:
            return .generic
        case .ruler, .rulerMarker:
            return .generic
        case .matte:
            return .group
        default:
            return self
        }
    }
}