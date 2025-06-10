# AXUI

AXUI is a Swift library that converts macOS Accessibility API data into a lightweight JSON format optimized for AI consumption. It enables AI systems to efficiently recognize and interact with UI elements by providing minimal, token-efficient representations.

## Features

- 🚀 **Lightweight JSON Format**: Converts verbose AX dumps to compact JSON
- 🤖 **AI-Optimized**: Designed specifically for minimal token usage in LLM contexts
- 🎯 **Smart Compression**: Automatically omits default values and empty arrays
- 📝 **Role Normalization**: Shortens common role names (e.g., `StaticText` → `Text`)
- 🔧 **Intelligent Filtering**: Removes generic descriptions while preserving meaningful ones
- 📦 **Optional Compression**: Supports LZFSE compression for further size reduction

## Installation

### Swift Package Manager

Add AXUI to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/AXUI.git", from: "1.0.0")
]
```

## Usage

### Basic Conversion

```swift
import AXUI

// Convert AX dump to minified JSON
let axDump = "your AX dump content here"
let json = try AXConverter.convert(axDump: axDump)
```

### Pretty JSON (for debugging)

```swift
let prettyJson = try AXConverter.convertToPrettyJSON(axDump: axDump)
```

### Compressed Output

```swift
let compressedData = try AXConverter.convertToCompressed(axDump: axDump)
```

## JSON Format Optimizations

### Role Shortening
- `AXStaticText` → `Text`
- `AXScrollArea` → `Scroll`
- `AXTextField` → `Field`
- `AXCheckBox` → `Check`
- `AXRadioButton` → `Radio`
- `AXPopUpButton` → `PopUp`

### Key Shortening
- `roleDescription` → `desc` (when not omitted)

### Smart Omissions
- Empty `children` arrays are omitted
- Empty `identifier` fields are omitted
- Default state values are omitted (`enabled: true`, `selected: false`, `focused: false`)
- Generic role descriptions are omitted (e.g., "ボタン" for Button role)

### Preserved Information
- Specific role descriptions like "閉じるボタン" (Close button) are preserved
- Non-default state values are included
- All bounds information is preserved as `[x, y, width, height]`

## Example Output

Input AX dump:
```
AXApplication
    AXWindow
        AXButton (roleDescription: "閉じるボタン")
            Position: {395, 1016}
            Size: {16, 16}
        AXStaticText (value: "Hello World")
            Position: {100, 200}
            Size: {200, 50}
```

Output JSON:
```json
{
  "role": "Window",
  "children": [
    {
      "role": "Button",
      "desc": "閉じるボタン",
      "bounds": [395, 1016, 16, 16]
    },
    {
      "role": "Text",
      "value": "Hello World",
      "bounds": [100, 200, 200, 50]
    }
  ]
}
```

## Architecture

- **AXDumper**: Interfaces with macOS Accessibility API
- **AXParser**: Parses text-based AX dumps into structured data
- **AXConverter**: Converts parsed data to optimized JSON format

## Requirements

- iOS 18.0+ / macOS 15.0+
- Swift 6.1+

## License

@1amageek

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
