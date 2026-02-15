import Foundation

// MARK: - Capture Profile

public enum CaptureProfile: String, Codable, Sendable {
    case agentDefault
    case debugFull
    case minimalInteractive
}

// MARK: - Capture Request

public enum WindowSelection: Codable, Sendable {
    case all
    case index(Int)
    case cgWindowID(UInt32)
}

public struct AXCaptureRequest: Codable, Sendable {
    public let bundleIdentifier: String
    public let window: WindowSelection
    public let query: AXQuery?
    public let profile: CaptureProfile
    public let maxElements: Int

    public init(
        bundleIdentifier: String,
        window: WindowSelection = .all,
        query: AXQuery? = nil,
        profile: CaptureProfile = .agentDefault,
        maxElements: Int = 5000
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.window = window
        self.query = query
        self.profile = profile
        self.maxElements = maxElements
    }
}

// MARK: - Snapshot Models

public struct AppContext: Codable, Sendable {
    public let bundleIdentifier: String
}

public struct WindowContext: Codable, Sendable {
    public let selection: WindowSelection
    public let index: Int?
    public let windowNumber: Int?
    public let title: String?
}

public struct Rect: Codable, Sendable {
    public let x: Int
    public let y: Int
    public let width: Int
    public let height: Int

    public init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct AXNodeState: Codable, Sendable {
    public let selected: Bool
    public let enabled: Bool
    public let focused: Bool
}

public struct AXNodeTraits: Codable, Sendable {
    public let isVisible: Bool
    public let isHittable: Bool
    public let isInteractive: Bool
    public let supportsPress: Bool
    public let supportsSetValue: Bool
    public let supportsIncrement: Bool
    public let supportsDecrement: Bool
}

public struct AXNode: Codable, Sendable {
    public let nodeID: String
    public let legacyID: String
    public let path: [Int]
    public let parentNodeID: String?
    public let role: Role
    public let systemRole: String?
    public let label: String?
    public let identifier: String?
    public let roleDescription: String?
    public let help: String?
    public let value: String?
    public let bounds: Rect?
    public let state: AXNodeState
    public let traits: AXNodeTraits
}

public struct AXSnapshotIndex: Codable, Sendable {
    public let byNodeID: [String: Int]
    public let byLegacyID: [String: [Int]]
}

public struct AXSnapshot: Codable, Sendable {
    public let snapshotID: String
    public let capturedAt: Date
    public let app: AppContext
    public let window: WindowContext
    public let nodes: [AXNode]
    public let index: AXSnapshotIndex
}

// MARK: - Resolve and Inspect

public enum AXResolutionKind: String, Codable, Sendable {
    case exact
    case fuzzy
    case notFound
}

public struct ResolutionResult: Codable, Sendable {
    public let kind: AXResolutionKind
    public let node: AXNode?
    public let matchedBy: String?
}

public enum AXNodeAction: String, Codable, Sendable {
    case press
    case setValue
    case increment
    case decrement
}

public struct AXNodeInspection: Codable, Sendable {
    public let nodeID: String
    public let legacyID: String
    public let bounds: Rect?
    public let centerPoint: Point?
    public let hitPoint: Point?
    public let actions: [AXNodeAction]
    public let traits: AXNodeTraits
}

// MARK: - Snapshot Errors

public enum AXSnapshotError: Error, LocalizedError {
    case windowNotFoundByCGWindowID(UInt32)
    case invalidWindowIndex(Int)

    public var errorDescription: String? {
        switch self {
        case .windowNotFoundByCGWindowID(let id):
            return "No window matched CGWindowID \(id)"
        case .invalidWindowIndex(let index):
            return "Invalid window index: \(index)"
        }
    }
}

// MARK: - Snapshot Service

public enum AXSnapshotService {

    public static func capture(_ request: AXCaptureRequest) throws -> AXSnapshot {
        let options = traversalOptions(for: request.profile)
        let capture = try captureElements(request: request, options: options)
        return buildSnapshot(
            elements: capture.elements,
            appContext: AppContext(bundleIdentifier: request.bundleIdentifier),
            windowContext: capture.windowContext
        )
    }

    public static func resolve(nodeID: String, in snapshot: AXSnapshot) -> ResolutionResult {
        if let index = snapshot.index.byNodeID[nodeID] {
            return ResolutionResult(kind: .exact, node: snapshot.nodes[index], matchedBy: "nodeID")
        }

        if let indexes = snapshot.index.byLegacyID[nodeID], indexes.count == 1, let first = indexes.first {
            return ResolutionResult(kind: .fuzzy, node: snapshot.nodes[first], matchedBy: "legacyID")
        }

        if nodeID.count >= 6,
           let fuzzy = snapshot.nodes.first(where: { $0.nodeID.hasPrefix(String(nodeID.prefix(6))) }) {
            return ResolutionResult(kind: .fuzzy, node: fuzzy, matchedBy: "nodeID-prefix")
        }

        return ResolutionResult(kind: .notFound, node: nil, matchedBy: nil)
    }

    public static func inspect(nodeID: String, in snapshot: AXSnapshot) -> AXNodeInspection? {
        let resolved = resolve(nodeID: nodeID, in: snapshot)
        guard let node = resolved.node else {
            return nil
        }

        let center: Point?
        if let bounds = node.bounds {
            center = Point(
                x: Double(bounds.x) + Double(bounds.width) / 2.0,
                y: Double(bounds.y) + Double(bounds.height) / 2.0
            )
        } else {
            center = nil
        }

        var actions: [AXNodeAction] = []
        if node.traits.supportsPress {
            actions.append(.press)
        }
        if node.traits.supportsSetValue {
            actions.append(.setValue)
        }
        if node.traits.supportsIncrement {
            actions.append(.increment)
        }
        if node.traits.supportsDecrement {
            actions.append(.decrement)
        }

        return AXNodeInspection(
            nodeID: node.nodeID,
            legacyID: node.legacyID,
            bounds: node.bounds,
            centerPoint: center,
            hitPoint: center,
            actions: actions,
            traits: node.traits
        )
    }

    public static func exportAI(snapshot: AXSnapshot, pretty: Bool = false) throws -> String {
        let output = snapshot.nodes.map { node in
            AISnapshotNode(
                id: node.nodeID,
                legacyID: node.legacyID,
                role: node.role,
                value: node.value,
                name: node.identifier,
                desc: node.roleDescription,
                bounds: node.bounds.map { [$0.x, $0.y, $0.width, $0.height] },
                state: AISnapshotNodeState(
                    selected: node.state.selected ? true : nil,
                    enabled: node.state.enabled ? nil : false,
                    focused: node.state.focused ? true : nil
                ),
                traits: node.traits
            )
        }

        let encoder = JSONEncoder()
        if pretty {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
        let data = try encoder.encode(output)
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    // MARK: - Internal Builders

    private static func traversalOptions(for profile: CaptureProfile) -> AXDumper.TraversalOptions {
        switch profile {
        case .agentDefault:
            return AXDumper.TraversalOptions(
                includeZeroSize: false,
                includeGroups: false,
                includeContentless: false
            )
        case .debugFull:
            return AXDumper.TraversalOptions(
                includeZeroSize: true,
                includeGroups: true,
                includeContentless: true
            )
        case .minimalInteractive:
            return AXDumper.TraversalOptions(
                includeZeroSize: false,
                includeGroups: false,
                includeContentless: false
            )
        }
    }

    private static func captureElements(
        request: AXCaptureRequest,
        options: AXDumper.TraversalOptions
    ) throws -> (elements: [AXElement], windowContext: WindowContext) {
        switch request.window {
        case .all:
            let elements = try AXDumper.dump(
                bundleIdentifier: request.bundleIdentifier,
                query: request.query,
                includeZeroSize: options.includeZeroSize,
                includeGroups: options.includeGroups,
                includeContentless: options.includeContentless,
                maxElements: request.maxElements
            )
            return (
                elements,
                WindowContext(selection: .all, index: nil, windowNumber: nil, title: nil)
            )

        case .index(let index):
            guard index >= 0 else {
                throw AXSnapshotError.invalidWindowIndex(index)
            }
            let windows = try AXDumper.listWindows(bundleIdentifier: request.bundleIdentifier)
            guard index < windows.count else {
                throw AXSnapshotError.invalidWindowIndex(index)
            }
            let window = windows[index]
            let elements = try AXDumper.dumpWindow(
                bundleIdentifier: request.bundleIdentifier,
                windowIndex: index,
                query: request.query,
                includeZeroSize: options.includeZeroSize,
                includeGroups: options.includeGroups,
                includeContentless: options.includeContentless,
                maxElements: request.maxElements
            )
            return (
                elements,
                WindowContext(
                    selection: .index(index),
                    index: index,
                    windowNumber: window.windowNumber,
                    title: window.title
                )
            )

        case .cgWindowID(let cgWindowID):
            let windows = try AXDumper.listWindows(bundleIdentifier: request.bundleIdentifier)
            guard let matched = windows.first(where: { $0.windowNumber == Int(cgWindowID) }) else {
                throw AXSnapshotError.windowNotFoundByCGWindowID(cgWindowID)
            }
            let elements = try AXDumper.dumpWindow(
                bundleIdentifier: request.bundleIdentifier,
                windowIndex: matched.index,
                query: request.query,
                includeZeroSize: options.includeZeroSize,
                includeGroups: options.includeGroups,
                includeContentless: options.includeContentless,
                maxElements: request.maxElements
            )
            return (
                elements,
                WindowContext(
                    selection: .cgWindowID(cgWindowID),
                    index: matched.index,
                    windowNumber: matched.windowNumber,
                    title: matched.title
                )
            )
        }
    }

    internal static func buildSnapshot(
        elements: [AXElement],
        appContext: AppContext,
        windowContext: WindowContext,
        capturedAt: Date = Date()
    ) -> AXSnapshot {
        var nodes: [AXNode] = []
        // Build nodes from top-level elements, recursively processing children
        for (index, element) in elements.enumerated() {
            buildNodes(
                from: element,
                path: [index],
                parentNodeID: nil,
                nodes: &nodes
            )
        }

        var byNodeID: [String: Int] = [:]
        var byLegacyID: [String: [Int]] = [:]
        for (idx, node) in nodes.enumerated() {
            byNodeID[node.nodeID] = idx
            byLegacyID[node.legacyID, default: []].append(idx)
        }

        return AXSnapshot(
            snapshotID: UUID().uuidString.lowercased(),
            capturedAt: capturedAt,
            app: appContext,
            window: windowContext,
            nodes: nodes,
            index: AXSnapshotIndex(byNodeID: byNodeID, byLegacyID: byLegacyID)
        )
    }

    /// Recursively build AXNode array from element and its children
    private static func buildNodes(
        from element: AXElement,
        path: [Int],
        parentNodeID: String?,
        nodes: inout [AXNode]
    ) {
        let node = makeNode(element: element, path: path, parentNodeID: parentNodeID)
        nodes.append(node)

        // Process children recursively
        if let children = element.children {
            for (childIndex, child) in children.enumerated() {
                buildNodes(
                    from: child,
                    path: path + [childIndex],
                    parentNodeID: node.nodeID,
                    nodes: &nodes
                )
            }
        }
    }

    private static func makeNode(element: AXElement, path: [Int], parentNodeID: String?) -> AXNode {
        let boundsRect: Rect?
        if let bounds = element.bounds, bounds.count == 4 {
            boundsRect = Rect(x: bounds[0], y: bounds[1], width: bounds[2], height: bounds[3])
        } else {
            boundsRect = nil
        }

        let selected = element.state?.selected ?? false
        let enabled = element.state?.enabled ?? true
        let focused = element.state?.focused ?? false

        let isVisible = if let boundsRect {
            boundsRect.width > 0 && boundsRect.height > 0
        } else {
            false
        }
        let isInteractive = element.role.isInteractive
        let supportsSetValue = element.role == .field || element.role == .check || element.role == .slider
        let supportsIncrement = element.role == .slider
        let supportsDecrement = element.role == .slider

        return AXNode(
            nodeID: element.id,
            legacyID: element.id,
            path: path,
            parentNodeID: parentNodeID,
            role: element.role,
            systemRole: element.systemRoleName,
            label: element.description,
            identifier: element.identifier,
            roleDescription: element.roleDescription,
            help: element.help,
            value: element.value,
            bounds: boundsRect,
            state: AXNodeState(selected: selected, enabled: enabled, focused: focused),
            traits: AXNodeTraits(
                isVisible: isVisible,
                isHittable: isVisible && enabled,
                isInteractive: isInteractive,
                supportsPress: isInteractive,
                supportsSetValue: supportsSetValue,
                supportsIncrement: supportsIncrement,
                supportsDecrement: supportsDecrement
            )
        )
    }
}

// MARK: - AI Export Node

private struct AISnapshotNode: Codable, Sendable {
    let id: String
    let legacyID: String
    let role: Role
    let value: String?
    let name: String?
    let desc: String?
    let bounds: [Int]?
    let state: AISnapshotNodeState?
    let traits: AXNodeTraits
}

private struct AISnapshotNodeState: Codable, Sendable {
    let selected: Bool?
    let enabled: Bool?
    let focused: Bool?
}
